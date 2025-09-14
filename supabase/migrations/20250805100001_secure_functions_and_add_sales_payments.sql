/*
# [Function] is_business_member
This function checks if a user is an active member of a specific business.

## Query Description:
This update sets a fixed `search_path` for the function to enhance security and prevent potential search path hijacking vulnerabilities, as recommended by security advisories.

## Metadata:
- Schema-Category: ["Security", "Safe"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: true

## Security Implications:
- RLS Status: Not applicable
- Policy Changes: No
- Auth Requirements: None
*/
CREATE OR REPLACE FUNCTION public.is_business_member(p_business_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM staff_roles
    WHERE business_id = p_business_id
      AND user_id = p_user_id
      AND is_active = true
  );
END;
$$;

/*
# [Function] handle_new_user
This trigger function creates a profile for a new user upon signup.

## Query Description:
This update sets a fixed `search_path` for the function to enhance security and prevent potential search path hijacking vulnerabilities, as recommended by security advisories.

## Metadata:
- Schema-Category: ["Security", "Safe"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: true

## Security Implications:
- RLS Status: Not applicable
- Policy Changes: No
- Auth Requirements: None
*/
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, phone)
  VALUES (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'phone'
  );
  RETURN new;
END;
$$;

/*
# [Function] create_sale_and_items
This function creates a sale and its associated items in a single transaction.

## Query Description:
This function ensures atomicity for sales creation. It inserts a record into the `sales` table and multiple records into the `sale_items` table. It also decrements the stock quantity for each product sold. This prevents partial sales from being recorded and keeps inventory accurate.

## Metadata:
- Schema-Category: ["Structural", "Data"]
- Impact-Level: ["Medium"]
- Requires-Backup: false
- Reversible: false (as it modifies data)

## Structure Details:
- Inserts into `sales` and `sale_items`.
- Updates `products` table (stock_quantity).

## Security Implications:
- RLS Status: Enabled
- Policy Changes: No
- Auth Requirements: User must be a member of the business.

## Performance Impact:
- Estimated Impact: Low. Operations are indexed and scoped to a single business.
*/
CREATE OR REPLACE FUNCTION public.create_sale_and_items(
    p_business_id uuid,
    p_cashier_id uuid,
    p_items jsonb
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    new_sale_id uuid;
    item record;
    product_stock int;
BEGIN
    -- Ensure the user is a member of the business
    IF NOT is_business_member(p_business_id, auth.uid()) THEN
        RAISE EXCEPTION 'User is not a member of this business';
    END IF;

    -- Insert the sale record
    INSERT INTO sales (business_id, cashier_id, total_amount, payment_method)
    VALUES (
        p_business_id,
        p_cashier_id,
        (SELECT SUM((it->>'unit_price')::numeric * (it->>'quantity')::numeric) FROM jsonb_array_elements(p_items) it),
        'cash' -- Default payment method, can be parameterized
    )
    RETURNING id INTO new_sale_id;

    -- Loop through items and insert them
    FOR item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(product_id uuid, quantity int, unit_price numeric)
    LOOP
        -- Check for sufficient stock
        SELECT stock_quantity INTO product_stock FROM products WHERE id = item.product_id;
        IF product_stock < item.quantity THEN
            RAISE EXCEPTION 'Insufficient stock for product ID %', item.product_id;
        END IF;

        INSERT INTO sale_items (sale_id, product_id, quantity, unit_price, total_price)
        VALUES (
            new_sale_id,
            item.product_id,
            item.quantity,
            item.unit_price,
            item.quantity * item.unit_price
        );

        -- Decrement stock
        UPDATE products
        SET stock_quantity = stock_quantity - item.quantity
        WHERE id = item.product_id;
    END LOOP;

    RETURN new_sale_id;
END;
$$;


/*
# [Function] get_dashboard_stats
This function retrieves key performance indicators for a business dashboard.

## Query Description:
This function is being updated to include revenue from both 'sales' and 'rent_payments' tables, providing a more comprehensive view of the business's financial performance. It now returns a single JSON object containing all stats.

## Metadata:
- Schema-Category: ["Safe"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Reads from `sales`, `rent_payments`, `tenants`, `students`, `products`.

## Security Implications:
- RLS Status: Enabled
- Policy Changes: No
- Auth Requirements: User must be a member of the business.

## Performance Impact:
- Indexes: Uses existing indexes on foreign keys.
- Estimated Impact: Low, as it aggregates data for a single business.
*/
-- The error occurs because the return type is changing from TABLE(...) to a single JSONB.
-- We must drop the function before recreating it.
DROP FUNCTION IF EXISTS public.get_dashboard_stats(uuid);

CREATE OR REPLACE FUNCTION public.get_dashboard_stats(p_business_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    sales_revenue numeric;
    rent_revenue numeric;
    customer_count int;
    all_revenue_data jsonb;
    business_type_val text;
BEGIN
    -- Ensure the user is a member of the business
    IF NOT is_business_member(p_business_id, auth.uid()) THEN
        RAISE EXCEPTION 'User is not a member of this business';
    END IF;

    -- Get business type
    SELECT b.business_type INTO business_type_val FROM businesses b WHERE b.id = p_business_id;

    -- Calculate revenue from sales
    SELECT COALESCE(SUM(total_amount), 0)
    INTO sales_revenue
    FROM sales
    WHERE business_id = p_business_id;

    -- Calculate revenue from rent payments
    SELECT COALESCE(SUM(amount), 0)
    INTO rent_revenue
    FROM rent_payments
    WHERE business_id = p_business_id;

    -- Get customer/tenant/student count based on business type
    IF business_type_val = 'school' THEN
        SELECT COUNT(*) INTO customer_count FROM students WHERE business_id = p_business_id AND is_active = true;
    ELSIF business_type_val = 'rentals' THEN
        SELECT COUNT(*) INTO customer_count FROM tenants WHERE business_id = p_business_id AND is_active = true;
    ELSE -- For retail businesses, we might need a customer table or count distinct customers from sales
        SELECT COUNT(DISTINCT customer_phone) INTO customer_count FROM sales WHERE business_id = p_business_id AND customer_phone IS NOT NULL;
    END IF;

    -- Aggregate all revenue-generating transactions for trend analysis
    SELECT jsonb_agg(transactions)
    INTO all_revenue_data
    FROM (
        SELECT created_at, total_amount as amount FROM sales WHERE business_id = p_business_id
        UNION ALL
        SELECT payment_date as created_at, amount FROM rent_payments WHERE business_id = p_business_id
        UNION ALL
        SELECT payment_date as created_at, amount FROM fee_payments WHERE business_id = p_business_id
    ) as transactions;

    RETURN jsonb_build_object(
        'customer_count', customer_count,
        'revenue_data', COALESCE(all_revenue_data, '[]'::jsonb)
    );
END;
$$;

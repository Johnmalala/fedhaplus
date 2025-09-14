/*
# [Function] Fix get_dashboard_stats search_path

## Query Description:
This operation re-creates the `get_dashboard_stats` function to explicitly set the `search_path`. This is a security best practice that prevents potential function hijacking by ensuring the function always looks for tables in the correct schema (`public`). It addresses the "Function Search Path Mutable" warning. There is no risk to existing data.

## Metadata:
- Schema-Category: "Safe"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Function: `public.get_dashboard_stats`
*/
CREATE OR REPLACE FUNCTION public.get_dashboard_stats(p_business_id uuid)
RETURNS TABLE(revenue_data jsonb, customer_count integer)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH all_revenue AS (
        (SELECT amount, created_at FROM public.rent_payments WHERE business_id = p_business_id)
        UNION ALL
        (SELECT amount, created_at FROM public.fee_payments WHERE business_id = p_business_id)
        UNION ALL
        (SELECT total_amount AS amount, created_at FROM public.sales WHERE business_id = p_business_id)
        UNION ALL
        (SELECT total_amount AS amount, created_at FROM public.bookings WHERE business_id = p_business_id)
    ),
    all_customers AS (
        (SELECT id FROM public.tenants WHERE business_id = p_business_id AND is_active = true)
        UNION ALL
        (SELECT id FROM public.students WHERE business_id = p_business_id AND is_active = true)
    )
    SELECT
        (SELECT jsonb_agg(t) FROM all_revenue t) AS revenue_data,
        (SELECT count(*)::integer FROM all_customers) AS customer_count;
END;
$$ SET search_path = 'public';

/*
# [Function] Create sale_and_items function

## Query Description:
This operation creates a new database function `create_sale_and_items`. This function allows the application to create a new sale and all of its associated line items (products sold) in a single, atomic transaction. This is critical for data integrity, ensuring that you never have a sale record without its corresponding items, or vice versa. This is a non-destructive, additive change.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Function: `public.create_sale_and_items`
*/
CREATE TYPE public.sale_item_input AS (
    product_id uuid,
    quantity integer,
    unit_price numeric
);

CREATE OR REPLACE FUNCTION public.create_sale_and_items(
    p_business_id uuid,
    p_cashier_id uuid,
    p_items public.sale_item_input[],
    p_customer_name text DEFAULT NULL,
    p_customer_phone text DEFAULT NULL,
    p_payment_method text DEFAULT 'cash',
    p_mpesa_code text DEFAULT NULL,
    p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    v_sale_id uuid;
    v_total_amount numeric := 0;
    item public.sale_item_input;
BEGIN
    -- Calculate total amount from items
    FOREACH item IN ARRAY p_items
    LOOP
        v_total_amount := v_total_amount + (item.quantity * item.unit_price);
    END LOOP;

    -- Insert the main sale record
    INSERT INTO public.sales (
        business_id,
        cashier_id,
        total_amount,
        customer_name,
        customer_phone,
        payment_method,
        mpesa_code,
        notes
    )
    VALUES (
        p_business_id,
        p_cashier_id,
        v_total_amount,
        p_customer_name,
        p_customer_phone,
        p_payment_method,
        p_mpesa_code,
        p_notes
    )
    RETURNING id INTO v_sale_id;

    -- Insert sale items and update stock
    FOREACH item IN ARRAY p_items
    LOOP
        INSERT INTO public.sale_items (
            sale_id,
            product_id,
            quantity,
            unit_price,
            total_price
        )
        VALUES (
            v_sale_id,
            item.product_id,
            item.quantity,
            item.unit_price,
            item.quantity * item.unit_price
        );

        -- Update product stock
        UPDATE public.products
        SET stock_quantity = stock_quantity - item.quantity
        WHERE id = item.product_id;
    END LOOP;

    RETURN v_sale_id;
END;
$$ SET search_path = 'public';

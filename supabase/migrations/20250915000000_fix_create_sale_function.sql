/*
# [Fix Create Sale Function]
This migration drops the existing `create_sale_and_items` function if it exists and recreates it with the correct logic. This new function ensures that when a sale is created, the stock levels for the sold products are automatically updated.

## Query Description:
This operation will replace the core logic for creating sales. If the old function was being used, this ensures the new, correct version is in place. This is a safe operation as it only affects the function definition and not existing sales data.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Medium"
- Requires-Backup: false
- Reversible: true (by restoring the previous function definition if available)

## Structure Details:
- Function: `public.create_sale_and_items`

## Security Implications:
- RLS Status: Not applicable to function definition itself.
- Policy Changes: No
- Auth Requirements: The function is defined with `SECURITY DEFINER` to allow it to update stock levels, which the calling user might not have direct permission to do. This is a standard and secure pattern for this type of operation.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Low. The function will be slightly slower due to the added stock update step, but this is necessary for data integrity.
*/

-- Drop the old function if it exists, along with any dependent objects.
DROP FUNCTION IF EXISTS public.create_sale_and_items(uuid, uuid, jsonb);

-- Create the new, correct version of the function.
CREATE OR REPLACE FUNCTION public.create_sale_and_items(
    p_business_id uuid,
    p_cashier_id uuid,
    p_items jsonb
)
RETURNS void AS $$
DECLARE
    v_sale_id uuid;
    v_total_amount numeric := 0;
    v_receipt_number text;
    item jsonb;
    v_product_id uuid;
    v_quantity int;
    v_unit_price numeric;
BEGIN
    -- Calculate total amount from the items JSON
    FOR item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_total_amount := v_total_amount + ((item->>'unit_price')::numeric * (item->>'quantity')::int);
    END LOOP;

    -- Generate a unique receipt number
    v_receipt_number := 'RCPT-' || to_char(now(), 'YYYYMMDD') || '-' || substr(md5(random()::text), 1, 6);

    -- Insert the main sale record
    INSERT INTO public.sales (business_id, cashier_id, total_amount, payment_method, receipt_number)
    VALUES (p_business_id, p_cashier_id, v_total_amount, 'cash', v_receipt_number)
    RETURNING id INTO v_sale_id;

    -- Loop through items again to insert into sale_items and update product stock
    FOR item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (item->>'product_id')::uuid;
        v_quantity := (item->>'quantity')::int;
        v_unit_price := (item->>'unit_price')::numeric;

        -- Insert the sale item record
        INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, total_price)
        VALUES (v_sale_id, v_product_id, v_quantity, v_unit_price, v_quantity * v_unit_price);

        -- Update the stock quantity for the product
        UPDATE public.products
        SET stock_quantity = stock_quantity - v_quantity
        WHERE id = v_product_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Set the search path for the function to ensure it can find tables correctly.
ALTER FUNCTION public.create_sale_and_items(uuid, uuid, jsonb) SET search_path = public;

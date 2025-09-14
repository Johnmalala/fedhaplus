/*
          # [Operation Name]
          Secure Final Functions

          ## Query Description: This migration secures the remaining database functions by setting a fixed search_path. This is a security best practice that prevents potential context-switching vulnerabilities by ensuring functions only search for objects within the 'public' schema. This change has no impact on existing data and is safe to apply.

          ## Metadata:
          - Schema-Category: "Safe"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true
          
          ## Structure Details:
          - Modifies: `create_sale_and_items`, `create_booking` functions.
          
          ## Security Implications:
          - RLS Status: Unchanged
          - Policy Changes: No
          - Auth Requirements: None
          
          ## Performance Impact:
          - Indexes: None
          - Triggers: None
          - Estimated Impact: Negligible.
          */

-- Drop and recreate create_sale_and_items function with secure search_path
DROP FUNCTION IF EXISTS public.create_sale_and_items(p_business_id uuid, p_cashier_id uuid, p_items jsonb);
CREATE OR REPLACE FUNCTION public.create_sale_and_items(
    p_business_id uuid,
    p_cashier_id uuid,
    p_items jsonb,
    p_customer_name text DEFAULT NULL,
    p_customer_phone text DEFAULT NULL,
    p_payment_method text DEFAULT 'cash'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_sale_id uuid;
    v_total_amount numeric := 0;
    v_item record;
    v_receipt_number text;
BEGIN
    -- Calculate total amount from items
    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(product_id uuid, quantity int, unit_price numeric)
    LOOP
        v_total_amount := v_total_amount + (v_item.quantity * v_item.unit_price);
    END LOOP;

    -- Generate receipt number
    v_receipt_number := 'RCPT-' || to_char(now(), 'YYYYMMDD') || '-' || substr(md5(random()::text), 1, 6);

    -- Insert into sales table
    INSERT INTO sales (business_id, cashier_id, customer_name, customer_phone, total_amount, payment_method, receipt_number)
    VALUES (p_business_id, p_cashier_id, p_customer_name, p_customer_phone, v_total_amount, p_payment_method, v_receipt_number)
    RETURNING id INTO v_sale_id;

    -- Insert sale items and update stock
    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(product_id uuid, quantity int, unit_price numeric)
    LOOP
        INSERT INTO sale_items (sale_id, product_id, quantity, unit_price, total_price)
        VALUES (v_sale_id, v_item.product_id, v_item.quantity, v_item.unit_price, v_item.quantity * v_item.unit_price);

        UPDATE products
        SET stock_quantity = stock_quantity - v_item.quantity
        WHERE id = v_item.product_id;
    END LOOP;

    RETURN v_sale_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.create_sale_and_items(uuid, uuid, jsonb, text, text, text) TO authenticated;

-- Drop and recreate create_booking function with secure search_path
DROP FUNCTION IF EXISTS public.create_booking(p_business_id uuid, p_guest_name text, p_guest_phone text, p_check_in_date date, p_check_out_date date, p_guests_count int, p_total_amount numeric, p_room_id uuid, p_listing_id uuid);
CREATE OR REPLACE FUNCTION public.create_booking(
    p_business_id uuid,
    p_guest_name text,
    p_guest_phone text,
    p_check_in_date date,
    p_check_out_date date,
    p_guests_count int,
    p_total_amount numeric,
    p_room_id uuid DEFAULT NULL,
    p_listing_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_booking_id uuid;
BEGIN
    -- Insert new booking
    INSERT INTO bookings (
        business_id, room_id, listing_id, guest_name, guest_phone,
        check_in_date, check_out_date, guests_count, total_amount,
        booking_status, payment_status, paid_amount
    )
    VALUES (
        p_business_id, p_room_id, p_listing_id, p_guest_name, p_guest_phone,
        p_check_in_date, p_check_out_date, p_guests_count, p_total_amount,
        'Confirmed', 'pending', 0
    )
    RETURNING id INTO v_booking_id;

    -- Update status of room or listing
    IF p_room_id IS NOT NULL THEN
        UPDATE rooms SET status = 'Occupied' WHERE id = p_room_id;
    ELSIF p_listing_id IS NOT NULL THEN
        UPDATE listings SET status = 'Booked' WHERE id = p_listing_id;
    END IF;

    RETURN v_booking_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.create_booking(uuid, text, text, date, date, int, numeric, uuid, uuid) TO authenticated;

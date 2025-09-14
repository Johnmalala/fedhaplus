/*
          # [Operation Name]
          Harden Remaining Functions

          [Description of what this operation does]
          This migration secures the remaining database functions by setting a fixed `search_path`. This is a security best practice that prevents potential schema-hijacking attacks. This script drops and recreates the functions to apply the security setting.

          ## Query Description: [This operation will safely drop and recreate three functions (`create_booking`, `create_sale_and_items`, `invite_staff`) to add a security setting. There is no risk to existing data as it only affects the function definitions.]
          
          ## Metadata:
          - Schema-Category: ["Safe", "Structural"]
          - Impact-Level: ["Low"]
          - Requires-Backup: [false]
          - Reversible: [true]
          
          ## Structure Details:
          - Functions affected: `create_booking`, `create_sale_and_items`, `invite_staff`
          
          ## Security Implications:
          - RLS Status: [Enabled]
          - Policy Changes: [No]
          - Auth Requirements: [None]
          
          ## Performance Impact:
          - Indexes: [None]
          - Triggers: [None]
          - Estimated Impact: [Negligible. A one-time, minor change to function definitions.]
          */

-- Drop existing functions safely before recreating them
DROP FUNCTION IF EXISTS public.create_booking(uuid,text,text,date,date,integer,numeric,uuid,uuid);
DROP FUNCTION IF EXISTS public.create_sale_and_items(uuid,uuid,jsonb);
DROP FUNCTION IF EXISTS public.invite_staff(uuid,text,public.staff_role_enum);


-- Recreate create_booking function with security settings
CREATE OR REPLACE FUNCTION public.create_booking(
    p_business_id uuid,
    p_guest_name text,
    p_guest_phone text,
    p_check_in_date date,
    p_check_out_date date,
    p_guests_count integer,
    p_total_amount numeric,
    p_room_id uuid DEFAULT NULL,
    p_listing_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    new_booking_id uuid;
BEGIN
    -- Insert the new booking
    INSERT INTO public.bookings (
        business_id, guest_name, guest_phone, check_in_date, check_out_date,
        guests_count, total_amount, room_id, listing_id,
        booking_status, payment_status, paid_amount
    )
    VALUES (
        p_business_id, p_guest_name, p_guest_phone, p_check_in_date, p_check_out_date,
        p_guests_count, p_total_amount, p_room_id, p_listing_id,
        'Confirmed', 'pending', 0
    )
    RETURNING id INTO new_booking_id;

    -- Update the status of the room or listing
    IF p_room_id IS NOT NULL THEN
        UPDATE public.rooms
        SET status = 'Occupied'
        WHERE id = p_room_id;
    ELSIF p_listing_id IS NOT NULL THEN
        UPDATE public.listings
        SET status = 'Booked'
        WHERE id = p_listing_id;
    END IF;
END;
$$;

-- Recreate create_sale_and_items function with security settings
CREATE OR REPLACE FUNCTION public.create_sale_and_items(
    p_business_id uuid,
    p_cashier_id uuid,
    p_items jsonb,
    p_customer_name text DEFAULT NULL,
    p_customer_phone text DEFAULT NULL,
    p_payment_method text DEFAULT 'Cash'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    new_sale_id uuid;
    total_sale_amount numeric := 0;
    item record;
    receipt_prefix text;
    receipt_sequence int;
    new_receipt_number text;
BEGIN
    -- Calculate total amount from items
    FOR item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(product_id uuid, quantity int, unit_price numeric)
    LOOP
        total_sale_amount := total_sale_amount + (item.quantity * item.unit_price);
    END LOOP;

    -- Generate receipt number
    receipt_prefix := 'INV-' || to_char(CURRENT_DATE, 'YYYYMM');
    SELECT COALESCE(MAX(SUBSTRING(receipt_number FROM 9)::int), 0) + 1
    INTO receipt_sequence
    FROM sales
    WHERE receipt_number LIKE receipt_prefix || '%';
    new_receipt_number := receipt_prefix || '-' || LPAD(receipt_sequence::text, 4, '0');

    -- Insert into sales table
    INSERT INTO public.sales (
        business_id, cashier_id, customer_name, customer_phone,
        total_amount, payment_method, receipt_number
    )
    VALUES (
        p_business_id, p_cashier_id, p_customer_name, p_customer_phone,
        total_sale_amount, p_payment_method, new_receipt_number
    )
    RETURNING id INTO new_sale_id;

    -- Insert into sale_items and update stock
    FOR item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(product_id uuid, quantity int, unit_price numeric)
    LOOP
        INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, total_price)
        VALUES (new_sale_id, item.product_id, item.quantity, item.unit_price, item.quantity * item.unit_price);

        UPDATE public.products
        SET stock_quantity = stock_quantity - item.quantity
        WHERE id = item.product_id;
    END LOOP;

    RETURN new_sale_id;
END;
$$;


-- Recreate invite_staff function with security settings
CREATE OR REPLACE FUNCTION public.invite_staff(
    p_business_id uuid,
    p_invitee_email text,
    p_role public.staff_role_enum
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    invitee_user_id uuid;
    inviter_user_id uuid := auth.uid();
BEGIN
    -- Check if inviter is the owner
    IF NOT EXISTS (
        SELECT 1 FROM public.staff_roles
        WHERE business_id = p_business_id
        AND user_id = inviter_user_id
        AND role = 'owner'
    ) THEN
        RAISE EXCEPTION 'Only the business owner can invite staff.';
    END IF;

    -- Find the user by email
    SELECT id INTO invitee_user_id FROM auth.users WHERE email = p_invitee_email;

    IF invitee_user_id IS NULL THEN
        RAISE EXCEPTION 'User with email % not found. Please ask them to sign up for Fedha Plus first.', p_invitee_email;
    END IF;
    
    -- Check if user is already part of the business
    IF EXISTS (
        SELECT 1 FROM public.staff_roles
        WHERE business_id = p_business_id
        AND user_id = invitee_user_id
    ) THEN
        RAISE EXCEPTION 'This user is already a member of this business.';
    END IF;

    -- Insert the new staff role
    INSERT INTO public.staff_roles (business_id, user_id, role, invited_by, is_active)
    VALUES (p_business_id, invitee_user_id, p_role, inviter_user_id, true);
END;
$$;

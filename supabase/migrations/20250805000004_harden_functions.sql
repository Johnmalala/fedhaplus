/*
          # [Operation Name]
          Harden Function Security and Finalize Schema

          ## Query Description:
          This script applies final security best practices to all existing database functions by setting a fixed `search_path`. This prevents potential security vulnerabilities related to path manipulation. It also includes a command to safely drop and recreate the `get_dashboard_stats` function to avoid conflicts with return type changes. This operation is safe and will not affect existing data.

          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true

          ## Structure Details:
          - Modifies functions: `get_dashboard_stats`, `invite_staff`, `create_sale_and_items`, `create_booking`, `get_my_businesses`

          ## Security Implications:
          - RLS Status: Unchanged
          - Policy Changes: No
          - Auth Requirements: None
          - Mitigates: `search_path` manipulation vulnerabilities.

          ## Performance Impact:
          - Indexes: None
          - Triggers: None
          - Estimated Impact: Negligible performance impact.
          */

-- Safely drop the function before recreating it to handle return type changes.
DROP FUNCTION IF EXISTS public.get_dashboard_stats(uuid);

CREATE OR REPLACE FUNCTION public.get_dashboard_stats(p_business_id uuid)
RETURNS json
LANGUAGE plpgsql
AS $$
DECLARE
    revenue_data json;
    customer_count int;
BEGIN
    -- Aggregate revenue from all relevant tables
    SELECT json_agg(revenue) INTO revenue_data
    FROM (
        SELECT amount, created_at FROM public.sales WHERE business_id = p_business_id
        UNION ALL
        SELECT amount, created_at FROM public.rent_payments WHERE business_id = p_business_id
        UNION ALL
        SELECT amount, created_at FROM public.fee_payments WHERE business_id = p_business_id
        UNION ALL
        SELECT total_amount as amount, created_at FROM public.bookings WHERE business_id = p_business_id AND payment_status = 'paid'
    ) as revenue;

    -- Aggregate customer/client count from all relevant tables
    SELECT count(*) INTO customer_count
    FROM (
        SELECT id FROM public.tenants WHERE business_id = p_business_id
        UNION
        SELECT id FROM public.students WHERE business_id = p_business_id
    ) as customers;

    RETURN json_build_object(
        'revenue_data', revenue_data,
        'customer_count', customer_count
    );
END;
$$;
ALTER FUNCTION public.get_dashboard_stats(uuid) SET search_path = public;


CREATE OR REPLACE FUNCTION public.invite_staff(p_business_id uuid, p_invitee_email text, p_role public.staff_role_enum)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    invitee_user_id uuid;
    inviter_user_id uuid;
BEGIN
    -- Get the user ID of the person being invited
    SELECT id INTO invitee_user_id FROM auth.users WHERE email = p_invitee_email;
    IF invitee_user_id IS NULL THEN
        RAISE EXCEPTION 'User with email % not found. Please ask them to create a Fedha Plus account first.', p_invitee_email;
    END IF;

    -- Get the user ID of the person sending the invite
    inviter_user_id := auth.uid();

    -- Check if the inviter is the owner of the business
    IF NOT EXISTS (
        SELECT 1 FROM public.businesses WHERE id = p_business_id AND owner_id = inviter_user_id
    ) THEN
        RAISE EXCEPTION 'Only the business owner can invite new staff.';
    END IF;

    -- Insert the new staff role
    INSERT INTO public.staff_roles (business_id, user_id, role, invited_by, is_active)
    VALUES (p_business_id, invitee_user_id, p_role, inviter_user_id, true)
    ON CONFLICT (business_id, user_id) DO UPDATE SET
        role = EXCLUDED.role,
        is_active = true;
END;
$$;
ALTER FUNCTION public.invite_staff(uuid, text, public.staff_role_enum) SET search_path = public;


CREATE OR REPLACE FUNCTION public.create_sale_and_items(p_business_id uuid, p_cashier_id uuid, p_items jsonb)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    new_sale_id uuid;
    item jsonb;
    total_sale_amount numeric := 0;
    receipt_prefix text;
    receipt_sequence int;
    new_receipt_number text;
BEGIN
    -- Calculate total amount from items
    FOR item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        total_sale_amount := total_sale_amount + ((item->>'unit_price')::numeric * (item->>'quantity')::numeric);
    END LOOP;

    -- Generate a unique receipt number
    receipt_prefix := upper(substr(p_business_id::text, 1, 4));
    SELECT nextval('public.receipt_number_seq') INTO receipt_sequence;
    new_receipt_number := receipt_prefix || '-' || to_char(now(), 'YYMMDD') || '-' || receipt_sequence::text;

    -- Insert the sale record
    INSERT INTO public.sales (business_id, cashier_id, total_amount, payment_method, receipt_number)
    VALUES (p_business_id, p_cashier_id, total_sale_amount, 'Cash', new_receipt_number)
    RETURNING id INTO new_sale_id;

    -- Insert sale items and update stock
    FOR item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, total_price)
        VALUES (
            new_sale_id,
            (item->>'product_id')::uuid,
            (item->>'quantity')::int,
            (item->>'unit_price')::numeric,
            ((item->>'unit_price')::numeric * (item->>'quantity')::numeric)
        );

        UPDATE public.products
        SET stock_quantity = stock_quantity - (item->>'quantity')::int
        WHERE id = (item->>'product_id')::uuid;
    END LOOP;

    RETURN new_sale_id;
END;
$$;
ALTER FUNCTION public.create_sale_and_items(uuid, uuid, jsonb) SET search_path = public;


CREATE OR REPLACE FUNCTION public.create_booking(p_business_id uuid, p_guest_name text, p_guest_phone text, p_check_in_date date, p_check_out_date date, p_guests_count int, p_total_amount numeric, p_room_id uuid DEFAULT NULL, p_listing_id uuid DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    new_booking_id uuid;
BEGIN
    -- Insert the new booking
    INSERT INTO public.bookings (
        business_id, guest_name, guest_phone, check_in_date, check_out_date,
        guests_count, total_amount, paid_amount, booking_status, payment_status,
        room_id, listing_id
    )
    VALUES (
        p_business_id, p_guest_name, p_guest_phone, p_check_in_date, p_check_out_date,
        p_guests_count, p_total_amount, 0, 'Confirmed', 'pending',
        p_room_id, p_listing_id
    )
    RETURNING id INTO new_booking_id;

    -- Update the status of the room or listing
    IF p_room_id IS NOT NULL THEN
        UPDATE public.rooms SET status = 'Occupied' WHERE id = p_room_id;
    END IF;
    IF p_listing_id IS NOT NULL THEN
        UPDATE public.listings SET status = 'Booked' WHERE id = p_listing_id;
    END IF;

    RETURN new_booking_id;
END;
$$;
ALTER FUNCTION public.create_booking(uuid, text, text, date, date, int, numeric, uuid, uuid) SET search_path = public;


CREATE OR REPLACE FUNCTION public.get_my_businesses()
RETURNS TABLE(
    id uuid,
    owner_id uuid,
    business_type public.business_type_enum,
    name text,
    description text,
    phone text,
    location text,
    logo_url text,
    settings jsonb,
    created_at timestamptz,
    updated_at timestamptz
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT b.*
    FROM public.businesses b
    JOIN public.staff_roles sr ON b.id = sr.business_id
    WHERE sr.user_id = auth.uid() AND sr.is_active = true;
END;
$$;
ALTER FUNCTION public.get_my_businesses() SET search_path = public;

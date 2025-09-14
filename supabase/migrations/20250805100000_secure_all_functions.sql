/*
# [Secure All Functions & Fix Missing ENUMs]
This migration secures all existing functions by setting a fixed search_path and ensures all custom ENUM types exist.

## Query Description:
This operation first idempotently creates all required ENUM types for the application. It then drops and recreates several functions to update their definitions and apply a secure search_path, preventing potential security vulnerabilities. This is a critical step for hardening the database.

## Metadata:
- Schema-Category: ["Structural", "Security"]
- Impact-Level: ["Medium"]
- Requires-Backup: false
- Reversible: false

## Structure Details:
- Creates ENUM types if they don't exist: `business_type_enum`, `staff_role_enum`, `payment_status_enum`, `subscription_status_enum`.
- Recreates function: `get_dashboard_stats`
- Recreates function: `invite_staff`
- Recreates function: `create_sale_and_items`
- Recreates function: `create_booking`
- Recreates function: `get_my_businesses`

## Security Implications:
- RLS Status: Not applicable
- Policy Changes: No
- Auth Requirements: None
- Hardens security by setting `search_path` on all major functions.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible
*/

-- Create ENUM types if they do not exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'business_type_enum') THEN
        CREATE TYPE public.business_type_enum AS ENUM (
            'hardware',
            'supermarket',
            'rentals',
            'airbnb',
            'hotel',
            'school'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'staff_role_enum') THEN
        CREATE TYPE public.staff_role_enum AS ENUM (
            'owner',
            'manager',
            'cashier',
            'accountant',
            'teacher',
            'front_desk',
            'housekeeper'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status_enum') THEN
        CREATE TYPE public.payment_status_enum AS ENUM (
            'pending',
            'paid',
            'overdue',
            'cancelled'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_status_enum') THEN
        CREATE TYPE public.subscription_status_enum AS ENUM (
            'trial',
            'active',
            'cancelled',
            'expired'
        );
    END IF;
END $$;


-- Drop and recreate the get_dashboard_stats function
DROP FUNCTION IF EXISTS public.get_dashboard_stats(uuid);
CREATE OR REPLACE FUNCTION public.get_dashboard_stats(p_business_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    revenue_data json;
    customer_count int;
BEGIN
    -- Aggregate revenue data from multiple sources
    SELECT json_agg(t)
    INTO revenue_data
    FROM (
        SELECT amount, created_at FROM public.sales WHERE business_id = p_business_id
        UNION ALL
        SELECT amount, created_at FROM public.fee_payments WHERE business_id = p_business_id
        UNION ALL
        SELECT amount, created_at FROM public.rent_payments WHERE business_id = p_business_id
        UNION ALL
        SELECT total_amount as amount, created_at FROM public.bookings WHERE business_id = p_business_id AND payment_status = 'paid'
    ) t;

    -- Aggregate customer/client count from multiple sources
    SELECT count(*)
    INTO customer_count
    FROM (
        SELECT id FROM public.students WHERE business_id = p_business_id AND is_active = true
        UNION
        SELECT id FROM public.tenants WHERE business_id = p_business_id AND is_active = true
    ) t;

    RETURN json_build_object(
        'revenue_data', revenue_data,
        'customer_count', customer_count
    );
END;
$$;
ALTER FUNCTION public.get_dashboard_stats(uuid) SET search_path = public;


-- Secure the invite_staff function
CREATE OR REPLACE FUNCTION public.invite_staff(p_business_id uuid, p_invitee_email text, p_role public.staff_role_enum)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    invitee_user_id uuid;
    inviter_user_id uuid := auth.uid();
BEGIN
    -- Check if inviter is the owner of the business
    IF NOT EXISTS (
        SELECT 1 FROM public.businesses
        WHERE id = p_business_id AND owner_id = inviter_user_id
    ) THEN
        RAISE EXCEPTION 'Only the business owner can invite staff.';
    END IF;

    -- Find the user ID for the given email
    SELECT id INTO invitee_user_id FROM auth.users WHERE email = p_invitee_email;

    IF invitee_user_id IS NULL THEN
        RAISE EXCEPTION 'User with email % not found. Please ask them to sign up for Fedha Plus first.', p_invitee_email;
    END IF;

    -- Check if the user is already a staff member for this business
    IF EXISTS (
        SELECT 1 FROM public.staff_roles
        WHERE business_id = p_business_id AND user_id = invitee_user_id
    ) THEN
        RAISE EXCEPTION 'This user is already a staff member of this business.';
    END IF;

    -- Insert the new staff role
    INSERT INTO public.staff_roles (business_id, user_id, role, invited_by, is_active)
    VALUES (p_business_id, invitee_user_id, p_role, inviter_user_id, true);
END;
$$;
ALTER FUNCTION public.invite_staff(uuid, text, public.staff_role_enum) SET search_path = public;


-- Secure the create_sale_and_items function
CREATE OR REPLACE FUNCTION public.create_sale_and_items(p_business_id uuid, p_cashier_id uuid, p_items jsonb)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    new_sale_id uuid;
    item record;
BEGIN
    -- Create the sale record
    INSERT INTO public.sales (business_id, cashier_id, total_amount, payment_method, receipt_number)
    VALUES (
        p_business_id,
        p_cashier_id,
        (SELECT sum((i->>'unit_price')::numeric * (i->>'quantity')::numeric) FROM jsonb_array_elements(p_items) i),
        'cash', -- Default payment method
        'RCPT-' || substr(md5(random()::text), 0, 8)
    )
    RETURNING id INTO new_sale_id;

    -- Loop through items and insert them
    FOR item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(product_id uuid, quantity int, unit_price numeric)
    LOOP
        INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, total_price)
        VALUES (new_sale_id, item.product_id, item.quantity, item.unit_price, item.quantity * item.unit_price);

        -- Decrement stock
        UPDATE public.products
        SET stock_quantity = stock_quantity - item.quantity
        WHERE id = item.product_id;
    END LOOP;

    RETURN new_sale_id;
END;
$$;
ALTER FUNCTION public.create_sale_and_items(uuid, uuid, jsonb) SET search_path = public;


-- Secure the create_booking function
CREATE OR REPLACE FUNCTION public.create_booking(p_business_id uuid, p_guest_name text, p_guest_phone text, p_check_in_date date, p_check_out_date date, p_guests_count integer, p_total_amount numeric, p_room_id uuid DEFAULT NULL, p_listing_id uuid DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    new_booking_id uuid;
BEGIN
    -- Create the booking record
    INSERT INTO public.bookings (
        business_id, guest_name, guest_phone, check_in_date, check_out_date,
        guests_count, total_amount, paid_amount, booking_status, payment_status
    )
    VALUES (
        p_business_id, p_guest_name, p_guest_phone, p_check_in_date, p_check_out_date,
        p_guests_count, p_total_amount, 0, 'Confirmed', 'pending'
    )
    RETURNING id INTO new_booking_id;

    -- Update the status of the room or listing
    IF p_room_id IS NOT NULL THEN
        UPDATE public.rooms SET status = 'Occupied' WHERE id = p_room_id;
        UPDATE public.bookings SET room_id = p_room_id WHERE id = new_booking_id;
    ELSIF p_listing_id IS NOT NULL THEN
        UPDATE public.listings SET status = 'Booked' WHERE id = p_listing_id;
        UPDATE public.bookings SET listing_id = p_listing_id WHERE id = new_booking_id;
    END IF;

    RETURN new_booking_id;
END;
$$;
ALTER FUNCTION public.create_booking(uuid, text, text, date, date, integer, numeric, uuid, uuid) SET search_path = public;


-- Secure the get_my_businesses function
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
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT b.*
    FROM public.businesses b
    JOIN public.staff_roles sr ON b.id = sr.business_id
    WHERE sr.user_id = auth.uid() AND sr.is_active = true;
$$;
ALTER FUNCTION public.get_my_businesses() SET search_path = public;

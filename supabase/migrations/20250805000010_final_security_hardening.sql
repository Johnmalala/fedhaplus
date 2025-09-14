/*
# [Final Security Hardening]
This migration addresses the final security warnings by setting a non-mutable search_path for the remaining database functions.

## Query Description:
This operation will safely drop and recreate three functions (`create_sale_and_items`, `create_booking`, and `invite_staff`) to apply security best practices. There is no risk to existing data as this only modifies function definitions.

## Metadata:
- Schema-Category: ["Safe", "Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: true (by reverting to a previous migration)

## Structure Details:
- Functions affected:
  - `create_sale_and_items(uuid, uuid, jsonb)`
  - `create_booking(uuid, text, text, date, date, integer, numeric, uuid, uuid)`
  - `invite_staff(uuid, text, public.staff_role_enum)`

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: `authenticated` role to execute functions.
- Fixes "Function Search Path Mutable" warnings.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible.
*/

-- Secure create_sale_and_items function
DROP FUNCTION IF EXISTS public.create_sale_and_items(uuid, uuid, jsonb);
CREATE OR REPLACE FUNCTION public.create_sale_and_items(
    p_business_id uuid,
    p_cashier_id uuid,
    p_items jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_sale_id uuid;
    total_sale_amount numeric := 0;
    item record;
BEGIN
    -- Calculate total amount from items
    FOR item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(product_id uuid, quantity int, unit_price numeric)
    LOOP
        total_sale_amount := total_sale_amount + (item.quantity * item.unit_price);
    END LOOP;

    -- Insert into sales table
    INSERT INTO public.sales (business_id, cashier_id, total_amount, payment_method)
    VALUES (p_business_id, p_cashier_id, total_sale_amount, 'cash') -- Default to cash
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
END;
$$;
ALTER FUNCTION public.create_sale_and_items(uuid, uuid, jsonb) SET search_path = 'public';


-- Secure create_booking function
DROP FUNCTION IF EXISTS public.create_booking(uuid, text, text, date, date, integer, numeric, uuid, uuid);
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
AS $$
BEGIN
    -- Insert the new booking
    INSERT INTO public.bookings (
        business_id, guest_name, guest_phone, check_in_date, check_out_date,
        guests_count, total_amount, paid_amount, booking_status, payment_status,
        room_id, listing_id
    ) VALUES (
        p_business_id, p_guest_name, p_guest_phone, p_check_in_date, p_check_out_date,
        p_guests_count, p_total_amount, 0, 'Confirmed', 'pending',
        p_room_id, p_listing_id
    );

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
ALTER FUNCTION public.create_booking(uuid, text, text, date, date, integer, numeric, uuid, uuid) SET search_path = 'public';


-- Secure invite_staff function
DROP FUNCTION IF EXISTS public.invite_staff(uuid, text, public.staff_role_enum);
CREATE OR REPLACE FUNCTION public.invite_staff(
    p_business_id uuid,
    p_invitee_email text,
    p_role public.staff_role_enum
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    invitee_user_id uuid;
    inviter_user_id uuid := auth.uid();
BEGIN
    -- Check if the inviter is an owner or manager of the business
    IF NOT public.is_business_member(p_business_id, inviter_user_id, ARRAY['owner', 'manager']) THEN
        RAISE EXCEPTION 'Only owners or managers can invite staff.';
    END IF;

    -- Find the user by email
    SELECT id INTO invitee_user_id FROM auth.users WHERE email = p_invitee_email;
    IF invitee_user_id IS NULL THEN
        RAISE EXCEPTION 'User with email % not found. Please ask them to sign up first.', p_invitee_email;
    END IF;

    -- Check if the user is already a member of this business
    IF EXISTS (SELECT 1 FROM public.staff_roles WHERE business_id = p_business_id AND user_id = invitee_user_id) THEN
        RAISE EXCEPTION 'This user is already a member of this business.';
    END IF;

    -- Insert the new staff role
    INSERT INTO public.staff_roles (business_id, user_id, role, invited_by, is_active)
    VALUES (p_business_id, invitee_user_id, p_role, inviter_user_id, true);
END;
$$;
ALTER FUNCTION public.invite_staff(uuid, text, public.staff_role_enum) SET search_path = 'public';

/*
# [Security] Harden All Database Functions
This migration updates all existing functions to set a fixed `search_path`.

## Query Description:
This is a security best practice that prevents certain classes of vulnerabilities by ensuring functions do not use a mutable search path. This is a safe, non-destructive operation that improves the security posture of the application.

## Metadata:
- Schema-Category: "Safe"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true
*/

/*
# [Function] `handle_new_user`
Sets a fixed search path.
*/
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
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
# [Function] `is_business_member`
Sets a fixed search path.
*/
CREATE OR REPLACE FUNCTION public.is_business_member(p_business_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM staff_roles
    WHERE business_id = p_business_id AND user_id = p_user_id AND is_active = true
  );
END;
$$;

/*
# [Function] `get_dashboard_stats`
Sets a fixed search path.
*/
CREATE OR REPLACE FUNCTION public.get_dashboard_stats(p_business_id uuid)
RETURNS TABLE(revenue_data json, customer_count int)
LANGUAGE plpgsql
STABLE
SET search_path = 'public'
AS $$
BEGIN
    RETURN QUERY
    SELECT
        (
            SELECT json_agg(t)
            FROM (
                SELECT r.amount, r.created_at FROM rent_payments r WHERE r.business_id = p_business_id
                UNION ALL
                SELECT s.total_amount, s.created_at FROM sales s WHERE s.business_id = p_business_id
                UNION ALL
                SELECT f.amount, f.created_at FROM fee_payments f WHERE f.business_id = p_business_id
                UNION ALL
                SELECT b.total_amount, b.created_at FROM bookings b WHERE b.business_id = p_business_id
            ) t
        ) AS revenue_data,
        (
            SELECT COUNT(DISTINCT c.id)::int
            FROM (
                SELECT t.id FROM tenants t WHERE t.business_id = p_business_id
                UNION ALL
                SELECT s.id FROM students s WHERE s.business_id = p_business_id
            ) c
        ) AS customer_count;
END;
$$;

/*
# [Function] `invite_staff`
Sets a fixed search path.
*/
CREATE OR REPLACE FUNCTION public.invite_staff(p_business_id uuid, p_invitee_email text, p_role staff_role_enum)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  invitee_user_id uuid;
  inviter_user_id uuid := auth.uid();
BEGIN
  SELECT id INTO invitee_user_id FROM auth.users WHERE email = p_invitee_email;

  IF invitee_user_id IS NULL THEN
    RAISE EXCEPTION 'User with email % does not exist. Please ask them to sign up first.', p_invitee_email;
  END IF;

  IF NOT is_business_member(p_business_id, inviter_user_id) THEN
    RAISE EXCEPTION 'You are not authorized to invite members to this business.';
  END IF;
  
  INSERT INTO public.staff_roles (business_id, user_id, role, invited_by, is_active)
  VALUES (p_business_id, invitee_user_id, p_role, inviter_user_id, true)
  ON CONFLICT (business_id, user_id) DO UPDATE
  SET role = EXCLUDED.role, is_active = true, invited_at = now();
END;
$$;

/*
# [Function] `create_sale_and_items`
Sets a fixed search path.
*/
CREATE OR REPLACE FUNCTION public.create_sale_and_items(
    p_business_id uuid,
    p_cashier_id uuid,
    p_items jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    new_sale_id uuid;
    total_sale_amount numeric := 0;
    item record;
BEGIN
    FOR item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(product_id uuid, quantity int, unit_price numeric)
    LOOP
        total_sale_amount := total_sale_amount + (item.quantity * item.unit_price);
    END LOOP;

    INSERT INTO public.sales (business_id, cashier_id, total_amount, payment_method)
    VALUES (p_business_id, p_cashier_id, total_sale_amount, 'Cash')
    RETURNING id INTO new_sale_id;

    INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, total_price)
    SELECT
        new_sale_id,
        (value->>'product_id')::uuid,
        (value->>'quantity')::int,
        (value->>'unit_price')::numeric,
        (value->>'quantity')::int * (value->>'unit_price')::numeric
    FROM jsonb_array_elements(p_items);

    FOR item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(product_id uuid, quantity int)
    LOOP
        UPDATE public.products
        SET stock_quantity = stock_quantity - item.quantity
        WHERE id = item.product_id;
    END LOOP;
END;
$$;

/*
# [Function] `create_booking`
Sets a fixed search path.
*/
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
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    INSERT INTO public.bookings (
        business_id, guest_name, guest_phone, check_in_date, check_out_date,
        guests_count, total_amount, room_id, listing_id,
        booking_status, payment_status, paid_amount
    ) VALUES (
        p_business_id, p_guest_name, p_guest_phone, p_check_in_date, p_check_out_date,
        p_guests_count, p_total_amount, p_room_id, p_listing_id,
        'Confirmed', 'pending', 0
    );

    IF p_room_id IS NOT NULL THEN
        UPDATE public.rooms SET status = 'Occupied' WHERE id = p_room_id;
    ELSIF p_listing_id IS NOT NULL THEN
        UPDATE public.listings SET status = 'Booked' WHERE id = p_listing_id;
    END IF;
END;
$$;

/*
# [Function] `get_my_businesses`
Sets a fixed search path.
*/
CREATE OR REPLACE FUNCTION public.get_my_businesses(p_user_id uuid)
RETURNS SETOF public.businesses
LANGUAGE sql
STABLE
SET search_path = 'public'
AS $$
  SELECT b.*
  FROM public.businesses b
  JOIN public.staff_roles sr ON b.id = sr.business_id
  WHERE sr.user_id = p_user_id AND sr.is_active = true;
$$;

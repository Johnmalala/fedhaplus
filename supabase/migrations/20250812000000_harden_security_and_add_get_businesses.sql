/*
# [Schema Hardening & Business Logic]
This migration script addresses several security warnings and introduces a new function to reliably fetch a user's associated businesses.

## Query Description:
This script performs the following actions:
1.  **Creates ENUM Types**: Safely creates `business_type_enum`, `staff_role_enum`, `payment_status_enum`, and `subscription_status_enum` if they do not already exist. This is critical for data consistency.
2.  **Hardens Functions**: Updates all existing database functions (`is_business_member`, `handle_new_user`, `get_dashboard_stats`, `invite_staff`, `create_sale_and_items`, `create_booking`) to set a fixed `search_path`. This is a security best practice to prevent potential schema-hijacking attacks.
3.  **Adds `get_my_businesses` Function**: Introduces a new RPC function that efficiently retrieves all businesses a user is a member of (either as an owner or through a staff role).
4.  **Idempotency**: All function creations are now preceded by a `DROP FUNCTION IF EXISTS` statement. This makes the script safe to re-run, as it will correctly handle existing functions, even if their definitions have changed.

## Metadata:
- Schema-Category: ["Structural", "Safe"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: false

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: `auth.uid()` is used to determine user identity.
*/

-- Create ENUM types if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'business_type_enum') THEN
        CREATE TYPE public.business_type_enum AS ENUM ('hardware', 'supermarket', 'rentals', 'airbnb', 'hotel', 'school');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'staff_role_enum') THEN
        CREATE TYPE public.staff_role_enum AS ENUM ('owner', 'manager', 'cashier', 'accountant', 'teacher', 'front_desk', 'housekeeper');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status_enum') THEN
        CREATE TYPE public.payment_status_enum AS ENUM ('pending', 'paid', 'overdue', 'cancelled');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_status_enum') THEN
        CREATE TYPE public.subscription_status_enum AS ENUM ('trial', 'active', 'cancelled', 'expired');
    END IF;
END$$;

-- Drop and recreate all functions to ensure idempotency and apply security settings.

DROP FUNCTION IF EXISTS public.is_business_member(uuid, uuid);
CREATE OR REPLACE FUNCTION public.is_business_member(p_business_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.staff_roles
    WHERE staff_roles.business_id = p_business_id
      AND staff_roles.user_id = p_user_id
      AND staff_roles.is_active = true
  );
END;
$$;
ALTER FUNCTION public.is_business_member(uuid, uuid) SET search_path = public;

DROP FUNCTION IF EXISTS public.handle_new_user();
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
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
ALTER FUNCTION public.handle_new_user() SET search_path = public;

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
  SELECT json_agg(revenue) INTO revenue_data FROM (
    SELECT total_amount AS amount, created_at FROM sales WHERE business_id = p_business_id
    UNION ALL
    SELECT amount, created_at FROM rent_payments WHERE business_id = p_business_id
    UNION ALL
    SELECT amount, created_at FROM fee_payments WHERE business_id = p_business_id
    UNION ALL
    SELECT total_amount AS amount, created_at FROM bookings WHERE business_id = p_business_id
  ) as revenue;

  -- Aggregate customer/client count from all relevant tables
  SELECT SUM(count) INTO customer_count FROM (
    SELECT COUNT(DISTINCT id) FROM students WHERE business_id = p_business_id AND is_active = true
    UNION ALL
    SELECT COUNT(DISTINCT id) FROM tenants WHERE business_id = p_business_id AND is_active = true
  ) as counts;

  RETURN json_build_object(
    'revenue_data', revenue_data,
    'customer_count', customer_count
  );
END;
$$;
ALTER FUNCTION public.get_dashboard_stats(uuid) SET search_path = public;

DROP FUNCTION IF EXISTS public.invite_staff(uuid, text, public.staff_role_enum);
CREATE OR REPLACE FUNCTION public.invite_staff(p_business_id uuid, p_invitee_email text, p_role public.staff_role_enum)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
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

  -- Find the user to invite
  SELECT id INTO invitee_user_id FROM auth.users WHERE email = p_invitee_email;
  IF invitee_user_id IS NULL THEN
    RAISE EXCEPTION 'User with email % not found. Please ask them to create a Fedha Plus account first.', p_invitee_email;
  END IF;

  -- Insert the staff role, handles conflicts
  INSERT INTO public.staff_roles (business_id, user_id, role, invited_by, is_active)
  VALUES (p_business_id, invitee_user_id, p_role, inviter_user_id, true)
  ON CONFLICT (business_id, user_id)
  DO UPDATE SET
    role = EXCLUDED.role,
    is_active = true,
    invited_by = EXCLUDED.invited_by,
    invited_at = NOW();
END;
$$;
ALTER FUNCTION public.invite_staff(uuid, text, public.staff_role_enum) SET search_path = public;

DROP FUNCTION IF EXISTS public.create_sale_and_items(uuid, uuid, jsonb);
CREATE OR REPLACE FUNCTION public.create_sale_and_items(p_business_id uuid, p_cashier_id uuid, p_items jsonb)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  new_sale_id uuid;
  total_sale_amount numeric := 0;
  item jsonb;
  receipt_no text;
BEGIN
  -- Calculate total amount from items
  FOR item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    total_sale_amount := total_sale_amount + ((item->>'unit_price')::numeric * (item->>'quantity')::numeric);
  END LOOP;

  -- Generate receipt number
  receipt_no := 'RCPT-' || to_char(NOW(), 'YYYYMMDD') || '-' || (
    SELECT lpad((COUNT(*) + 1)::text, 4, '0')
    FROM sales
    WHERE DATE(created_at) = CURRENT_DATE
  );

  -- Insert the sale record
  INSERT INTO public.sales (business_id, cashier_id, total_amount, payment_method, receipt_number)
  VALUES (p_business_id, p_cashier_id, total_sale_amount, 'Cash', receipt_no)
  RETURNING id INTO new_sale_id;

  -- Insert sale items and update product stock
  FOR item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, total_price)
    VALUES (
      new_sale_id,
      (item->>'product_id')::uuid,
      (item->>'quantity')::integer,
      (item->>'unit_price')::numeric,
      (item->>'quantity')::numeric * (item->>'unit_price')::numeric
    );

    UPDATE public.products
    SET stock_quantity = stock_quantity - (item->>'quantity')::integer
    WHERE id = (item->>'product_id')::uuid;
  END LOOP;

  RETURN new_sale_id;
END;
$$;
ALTER FUNCTION public.create_sale_and_items(uuid, uuid, jsonb) SET search_path = public;

DROP FUNCTION IF EXISTS public.create_booking(uuid, text, text, date, date, integer, numeric, uuid, uuid);
CREATE OR REPLACE FUNCTION public.create_booking(p_business_id uuid, p_guest_name text, p_guest_phone text, p_check_in_date date, p_check_out_date date, p_guests_count integer, p_total_amount numeric, p_room_id uuid DEFAULT NULL, p_listing_id uuid DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  new_booking_id uuid;
BEGIN
  -- Insert the booking
  INSERT INTO public.bookings (
    business_id, guest_name, guest_phone, check_in_date, check_out_date,
    guests_count, total_amount, room_id, listing_id,
    booking_status, payment_status
  )
  VALUES (
    p_business_id, p_guest_name, p_guest_phone, p_check_in_date, p_check_out_date,
    p_guests_count, p_total_amount, p_room_id, p_listing_id,
    'Confirmed', 'pending'
  )
  RETURNING id INTO new_booking_id;

  -- Update room/listing status
  IF p_room_id IS NOT NULL THEN
    UPDATE public.rooms SET status = 'Occupied' WHERE id = p_room_id;
  END IF;
  IF p_listing_id IS NOT NULL THEN
    UPDATE public.listings SET status = 'Booked' WHERE id = p_listing_id;
  END IF;

  RETURN new_booking_id;
END;
$$;
ALTER FUNCTION public.create_booking(uuid, text, text, date, date, integer, numeric, uuid, uuid) SET search_path = public;

DROP FUNCTION IF EXISTS public.get_my_businesses();
CREATE OR REPLACE FUNCTION public.get_my_businesses()
RETURNS SETOF public.businesses
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
  SELECT b.*
  FROM public.businesses b
  JOIN public.staff_roles sr ON b.id = sr.business_id
  WHERE sr.user_id = auth.uid() AND sr.is_active = true;
$$;
ALTER FUNCTION public.get_my_businesses() SET search_path = public;

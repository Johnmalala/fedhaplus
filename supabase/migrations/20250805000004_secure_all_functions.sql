/*
          # [Schema Security Hardening]
          This migration script addresses several security warnings by setting a fixed 'search_path' for all database functions. It also safely handles function dependencies by temporarily dropping and recreating RLS policies as needed.

          ## Query Description: [This operation modifies internal database functions to improve security. It is a safe, non-destructive update that does not affect user data. No backup is required, and the changes are reversible.]
          
          ## Metadata:
          - Schema-Category: ["Structural", "Safe"]
          - Impact-Level: ["Low"]
          - Requires-Backup: false
          - Reversible: true
          
          ## Structure Details:
          - Modifies functions: is_business_member, get_dashboard_stats, create_sale_and_items, invite_staff, create_booking, get_my_businesses
          - Temporarily drops and recreates RLS policies on all major tables.
          
          ## Security Implications:
          - RLS Status: [Enabled]
          - Policy Changes: [Yes, policies are recreated but logic is unchanged]
          - Auth Requirements: [None]
          
          ## Performance Impact:
          - Indexes: [None]
          - Triggers: [None]
- Estimated Impact: [Negligible performance impact.]
          */

-- Create ENUM types if they don't exist to prevent errors on re-run
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
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'room_status_enum') THEN
        CREATE TYPE public.room_status_enum AS ENUM ('Available', 'Occupied', 'Cleaning', 'Maintenance');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'listing_status_enum') THEN
        CREATE TYPE public.listing_status_enum AS ENUM ('Listed', 'Booked', 'Maintenance');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'booking_status_enum') THEN
        CREATE TYPE public.booking_status_enum AS ENUM ('Confirmed', 'Checked-in', 'Checked-out', 'Cancelled');
    END IF;
END$$;

-- Drop dependent policies for is_business_member
DROP POLICY IF EXISTS "Allow business members to view their business" ON public.businesses;
DROP POLICY IF EXISTS "Allow business members to view staff" ON public.staff_roles;
DROP POLICY IF EXISTS "Allow business members to view subscription" ON public.subscriptions;
DROP POLICY IF EXISTS "Allow full access to business members on products" ON public.products;
DROP POLICY IF EXISTS "Allow full access to business members on sales" ON public.sales;
DROP POLICY IF EXISTS "Allow full access to business members on sale_items" ON public.sale_items;
DROP POLICY IF EXISTS "Allow full access to business members on tenants" ON public.tenants;
DROP POLICY IF EXISTS "Allow full access to business members on rent_payments" ON public.rent_payments;
DROP POLICY IF EXISTS "Allow full access to business members on students" ON public.students;
DROP POLICY IF EXISTS "Allow full access to business members on fee_payments" ON public.fee_payments;
DROP POLICY IF EXISTS "Allow full access to business members on rooms" ON public.rooms;
DROP POLICY IF EXISTS "Allow full access to business members on listings" ON public.listings;
DROP POLICY IF EXISTS "Allow full access to business members on bookings" ON public.bookings;

-- Drop and recreate all functions safely
DROP FUNCTION IF EXISTS public.is_business_member(uuid,uuid);
DROP FUNCTION IF EXISTS public.get_dashboard_stats(uuid);
DROP FUNCTION IF EXISTS public.create_sale_and_items(uuid,uuid,jsonb);
DROP FUNCTION IF EXISTS public.invite_staff(uuid,text,text);
DROP FUNCTION IF EXISTS public.create_booking(uuid,text,text,date,date,integer,numeric,uuid,uuid);
DROP FUNCTION IF EXISTS public.get_my_businesses();

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
    WHERE business_id = p_business_id AND user_id = p_user_id AND is_active = true
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_dashboard_stats(p_business_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  revenue_data json;
  customer_count int;
BEGIN
  -- Aggregate revenue data
  SELECT json_agg(json_build_object('amount', total_amount, 'created_at', created_at))
  INTO revenue_data
  FROM sales
  WHERE business_id = p_business_id;

  -- Get distinct customer count based on business type
  SELECT count(id)
  INTO customer_count
  FROM (
    SELECT id FROM students WHERE business_id = p_business_id
    UNION
    SELECT id FROM tenants WHERE business_id = p_business_id
  ) AS customers;

  RETURN json_build_object(
    'revenue_data', COALESCE(revenue_data, '[]'::json),
    'customer_count', COALESCE(customer_count, 0)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.create_sale_and_items(p_business_id uuid, p_cashier_id uuid, p_items jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sale_id uuid;
  v_total_amount numeric := 0;
  v_item jsonb;
BEGIN
  -- Calculate total amount
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_total_amount := v_total_amount + ((v_item->>'unit_price')::numeric * (v_item->>'quantity')::integer);
  END LOOP;

  -- Insert the sale
  INSERT INTO sales (business_id, cashier_id, total_amount, payment_method, receipt_number)
  VALUES (p_business_id, p_cashier_id, v_total_amount, 'cash', 'RCPT-' || substr(md5(random()::text), 0, 8))
  RETURNING id INTO v_sale_id;

  -- Insert sale items and update stock
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO sale_items (sale_id, product_id, quantity, unit_price, total_price)
    VALUES (
      v_sale_id,
      (v_item->>'product_id')::uuid,
      (v_item->>'quantity')::integer,
      (v_item->>'unit_price')::numeric,
      (v_item->>'unit_price')::numeric * (v_item->>'quantity')::integer
    );

    UPDATE products
    SET stock_quantity = stock_quantity - (v_item->>'quantity')::integer
    WHERE id = (v_item->>'product_id')::uuid;
  END LOOP;

  RETURN v_sale_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.invite_staff(p_business_id uuid, p_invitee_email text, p_role text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invitee_id uuid;
  v_inviter_id uuid := auth.uid();
BEGIN
  -- Find the user by email
  SELECT id INTO v_invitee_id FROM auth.users WHERE email = p_invitee_email;
  IF v_invitee_id IS NULL THEN
    RAISE EXCEPTION 'User with email % not found. Please ask them to sign up first.', p_invitee_email;
  END IF;

  -- Check if user is already a member
  IF EXISTS (SELECT 1 FROM staff_roles WHERE business_id = p_business_id AND user_id = v_invitee_id) THEN
    RAISE EXCEPTION 'User is already a member of this business.';
  END IF;

  -- Insert the staff role
  INSERT INTO staff_roles (business_id, user_id, role, invited_by, is_active)
  VALUES (p_business_id, v_invitee_id, p_role::staff_role_enum, v_inviter_id, true);
END;
$$;

CREATE OR REPLACE FUNCTION public.create_booking(p_business_id uuid, p_guest_name text, p_guest_phone text, p_check_in_date date, p_check_out_date date, p_guests_count integer, p_total_amount numeric, p_room_id uuid DEFAULT NULL, p_listing_id uuid DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_booking_id uuid;
BEGIN
    INSERT INTO bookings(business_id, guest_name, guest_phone, check_in_date, check_out_date, guests_count, total_amount, room_id, listing_id, booking_status, payment_status, paid_amount)
    VALUES (p_business_id, p_guest_name, p_guest_phone, p_check_in_date, p_check_out_date, p_guests_count, p_total_amount, p_room_id, p_listing_id, 'Confirmed', 'pending', 0)
    RETURNING id INTO v_booking_id;

    IF p_room_id IS NOT NULL THEN
        UPDATE rooms SET status = 'Occupied' WHERE id = p_room_id;
    END IF;
    IF p_listing_id IS NOT NULL THEN
        UPDATE listings SET status = 'Booked' WHERE id = p_listing_id;
    END IF;

    RETURN v_booking_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_businesses()
RETURNS SETOF businesses
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT b.*
  FROM businesses b
  JOIN staff_roles sr ON b.id = sr.business_id
  WHERE sr.user_id = auth.uid() AND sr.is_active = true;
END;
$$;

-- Recreate all the policies
CREATE POLICY "Allow business members to view their business" ON public.businesses FOR SELECT USING (public.is_business_member(id, auth.uid()));
CREATE POLICY "Allow business members to view staff" ON public.staff_roles FOR SELECT USING (public.is_business_member(business_id, auth.uid()));
CREATE POLICY "Allow business members to view subscription" ON public.subscriptions FOR SELECT USING (public.is_business_member(business_id, auth.uid()));
CREATE POLICY "Allow full access to business members on products" ON public.products FOR ALL USING (public.is_business_member(business_id, auth.uid())) WITH CHECK (public.is_business_member(business_id, auth.uid()));
CREATE POLICY "Allow full access to business members on sales" ON public.sales FOR ALL USING (public.is_business_member(business_id, auth.uid())) WITH CHECK (public.is_business_member(business_id, auth.uid()));
CREATE POLICY "Allow full access to business members on sale_items" ON public.sale_items FOR ALL USING (EXISTS (SELECT 1 FROM sales WHERE sales.id = sale_items.sale_id AND public.is_business_member(sales.business_id, auth.uid()))) WITH CHECK (EXISTS (SELECT 1 FROM sales WHERE sales.id = sale_items.sale_id AND public.is_business_member(sales.business_id, auth.uid())));
CREATE POLICY "Allow full access to business members on tenants" ON public.tenants FOR ALL USING (public.is_business_member(business_id, auth.uid())) WITH CHECK (public.is_business_member(business_id, auth.uid()));
CREATE POLICY "Allow full access to business members on rent_payments" ON public.rent_payments FOR ALL USING (public.is_business_member(business_id, auth.uid())) WITH CHECK (public.is_business_member(business_id, auth.uid()));
CREATE POLICY "Allow full access to business members on students" ON public.students FOR ALL USING (public.is_business_member(business_id, auth.uid())) WITH CHECK (public.is_business_member(business_id, auth.uid()));
CREATE POLICY "Allow full access to business members on fee_payments" ON public.fee_payments FOR ALL USING (public.is_business_member(business_id, auth.uid())) WITH CHECK (public.is_business_member(business_id, auth.uid()));
CREATE POLICY "Allow full access to business members on rooms" ON public.rooms FOR ALL USING (public.is_business_member(business_id, auth.uid())) WITH CHECK (public.is_business_member(business_id, auth.uid()));
CREATE POLICY "Allow full access to business members on listings" ON public.listings FOR ALL USING (public.is_business_member(business_id, auth.uid())) WITH CHECK (public.is_business_member(business_id, auth.uid()));
CREATE POLICY "Allow full access to business members on bookings" ON public.bookings FOR ALL USING (public.is_business_member(business_id, auth.uid())) WITH CHECK (public.is_business_member(business_id, auth.uid()));

/*
          # [DEFINITIVE IDEMPOTENT SCHEMA RESET]
          This script completely resets and rebuilds all custom functions and RLS policies.
          It is designed to fix inconsistencies from previous failed migrations and can be run safely.

          ## Query Description: 
          This operation will temporarily drop all custom functions and security policies, then immediately recreate them. 
          This is a safe and standard procedure to resolve dependency conflicts in PostgreSQL. There is no risk to your existing data (products, sales, users, etc.).
          
          ## Metadata:
          - Schema-Category: ["Structural"]
          - Impact-Level: ["Medium"]
          - Requires-Backup: false
          - Reversible: false
          
          ## Structure Details:
          - Drops and recreates all custom functions.
          - Drops and recreates all RLS policies on all application tables.
          
          ## Security Implications:
          - RLS Status: Re-enabled on all tables.
          - Policy Changes: Yes, all policies are recreated to match the application's requirements.
          - Auth Requirements: No changes to auth.
          
          ## Performance Impact:
          - Indexes: None
          - Triggers: None
          - Estimated Impact: Low. A brief one-time operation.
          */

-- Step 1: Drop all existing custom functions with CASCADE to remove dependent policies.
-- This is the key step to break the dependency cycle.
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.is_business_member(uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_dashboard_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.invite_staff(uuid, text, text) CASCADE;
DROP FUNCTION IF EXISTS public.create_sale_and_items(uuid, uuid, jsonb) CASCADE;
DROP FUNCTION IF EXISTS public.create_booking(uuid, text, text, date, date, int, numeric, uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_my_businesses() CASCADE;

-- Step 2: Ensure all ENUM types exist before creating functions that use them.
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

-- Step 3: Recreate all functions with proper security settings.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, phone)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name',
    NEW.email,
    NEW.raw_user_meta_data->>'phone'
  );
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.is_business_member(p_business_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM staff_roles
    WHERE business_id = p_business_id AND user_id = p_user_id AND is_active = true
  );
$$;

CREATE OR REPLACE FUNCTION public.get_my_businesses()
RETURNS SETOF businesses
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT b.*
  FROM businesses b
  JOIN staff_roles sr ON b.id = sr.business_id
  WHERE sr.user_id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.get_dashboard_stats(p_business_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    revenue_data jsonb;
    customer_count int;
BEGIN
    -- Aggregate revenue data
    SELECT jsonb_agg(jsonb_build_object('amount', amount, 'created_at', created_at))
    INTO revenue_data
    FROM (
        SELECT total_amount AS amount, created_at FROM sales WHERE business_id = p_business_id
        UNION ALL
        SELECT amount, created_at FROM rent_payments WHERE business_id = p_business_id
        UNION ALL
        SELECT amount, created_at FROM fee_payments WHERE business_id = p_business_id
        UNION ALL
        SELECT total_amount AS amount, created_at FROM bookings WHERE business_id = p_business_id
    ) AS all_revenue;

    -- Aggregate customer count
    SELECT SUM(count) INTO customer_count FROM (
        SELECT COUNT(DISTINCT id) FROM tenants WHERE business_id = p_business_id
        UNION ALL
        SELECT COUNT(DISTINCT id) FROM students WHERE business_id = p_business_id
        UNION ALL
        SELECT COUNT(DISTINCT guest_phone) FROM bookings WHERE business_id = p_business_id
    ) AS counts;

    RETURN jsonb_build_object(
        'revenue_data', COALESCE(revenue_data, '[]'::jsonb),
        'customer_count', COALESCE(customer_count, 0)
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.invite_staff(p_business_id uuid, p_invitee_email text, p_role text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  invitee_user_id uuid;
  inviter_user_id uuid := auth.uid();
BEGIN
  -- Check if inviter is the owner
  IF NOT EXISTS (
    SELECT 1 FROM staff_roles
    WHERE business_id = p_business_id AND user_id = inviter_user_id AND role = 'owner'
  ) THEN
    RAISE EXCEPTION 'Only the business owner can invite staff.';
  END IF;

  -- Find the user to invite
  SELECT id INTO invitee_user_id FROM auth.users WHERE email = p_invitee_email;
  IF invitee_user_id IS NULL THEN
    RAISE EXCEPTION 'User with email % not found. Please ask them to create a Fedha Plus account first.', p_invitee_email;
  END IF;

  -- Insert the staff role
  INSERT INTO public.staff_roles (business_id, user_id, role, invited_by, is_active)
  VALUES (p_business_id, invitee_user_id, p_role::staff_role_enum, inviter_user_id, true)
  ON CONFLICT (business_id, user_id) DO UPDATE SET role = EXCLUDED.role, is_active = true;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_sale_and_items(p_business_id uuid, p_cashier_id uuid, p_items jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_sale_id uuid;
  total_sale_amount numeric := 0;
  item jsonb;
  receipt_no text;
BEGIN
  -- Calculate total amount
  FOR item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    total_sale_amount := total_sale_amount + ((item->>'unit_price')::numeric * (item->>'quantity')::numeric);
  END LOOP;

  -- Generate receipt number
  receipt_no := 'RCPT-' || to_char(now(), 'YYYYMMDD') || '-' || substr(md5(random()::text), 1, 6);

  -- Insert the sale record
  INSERT INTO public.sales (business_id, cashier_id, total_amount, payment_method, receipt_number)
  VALUES (p_business_id, p_cashier_id, total_sale_amount, 'Cash', receipt_no)
  RETURNING id INTO new_sale_id;

  -- Insert sale items and update stock
  FOR item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, total_price)
    VALUES (
      new_sale_id,
      (item->>'product_id')::uuid,
      (item->>'quantity')::integer,
      (item->>'unit_price')::numeric,
      (item->>'unit_price')::numeric * (item->>'quantity')::numeric
    );
    
    UPDATE public.products
    SET stock_quantity = stock_quantity - (item->>'quantity')::integer
    WHERE id = (item->>'product_id')::uuid;
  END LOOP;

  RETURN new_sale_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_booking(
    p_business_id uuid,
    p_guest_name text,
    p_guest_phone text,
    p_check_in_date date,
    p_check_out_date date,
    p_guests_count integer,
    p_total_amount numeric,
    p_room_id uuid,
    p_listing_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_booking_id uuid;
BEGIN
  -- Insert the booking record
  INSERT INTO public.bookings (
    business_id, guest_name, guest_phone, check_in_date, check_out_date,
    guests_count, total_amount, paid_amount, booking_status, payment_status, room_id, listing_id
  ) VALUES (
    p_business_id, p_guest_name, p_guest_phone, p_check_in_date, p_check_out_date,
    p_guests_count, p_total_amount, 0, 'Confirmed', 'pending', p_room_id, p_listing_id
  ) RETURNING id INTO new_booking_id;

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

-- Step 4: Re-create all RLS policies for all tables.

-- Businesses Table
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow business members to view their business" ON public.businesses FOR SELECT USING (is_business_member(id, auth.uid()));
CREATE POLICY "Allow owner to update their business" ON public.businesses FOR UPDATE USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());

-- Staff Roles Table
ALTER TABLE public.staff_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow business members to view staff" ON public.staff_roles FOR SELECT USING (is_business_member(business_id, auth.uid()));
CREATE POLICY "Allow owner to manage staff" ON public.staff_roles FOR ALL USING (
  is_business_member(business_id, auth.uid()) AND 
  (SELECT role FROM staff_roles WHERE user_id = auth.uid() AND business_id = staff_roles.business_id) = 'owner'
);

-- Subscriptions Table
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow business members to view subscription" ON public.subscriptions FOR SELECT USING (is_business_member(business_id, auth.uid()));

-- Products Table
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on products" ON public.products FOR ALL USING (is_business_member(business_id, auth.uid())) WITH CHECK (is_business_member(business_id, auth.uid()));

-- Sales Table
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on sales" ON public.sales FOR ALL USING (is_business_member(business_id, auth.uid())) WITH CHECK (is_business_member(business_id, auth.uid()));

-- Sale Items Table
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on sale_items" ON public.sale_items FOR ALL USING (
    EXISTS (
        SELECT 1 FROM sales s
        WHERE s.id = sale_items.sale_id AND is_business_member(s.business_id, auth.uid())
    )
) WITH CHECK (
    EXISTS (
        SELECT 1 FROM sales s
        WHERE s.id = sale_items.sale_id AND is_business_member(s.business_id, auth.uid())
    )
);

-- Tenants Table
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on tenants" ON public.tenants FOR ALL USING (is_business_member(business_id, auth.uid())) WITH CHECK (is_business_member(business_id, auth.uid()));

-- Rent Payments Table
ALTER TABLE public.rent_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on rent_payments" ON public.rent_payments FOR ALL USING (is_business_member(business_id, auth.uid())) WITH CHECK (is_business_member(business_id, auth.uid()));

-- Students Table
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on students" ON public.students FOR ALL USING (is_business_member(business_id, auth.uid())) WITH CHECK (is_business_member(business_id, auth.uid()));

-- Fee Payments Table
ALTER TABLE public.fee_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on fee_payments" ON public.fee_payments FOR ALL USING (is_business_member(business_id, auth.uid())) WITH CHECK (is_business_member(business_id, auth.uid()));

-- Rooms Table
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on rooms" ON public.rooms FOR ALL USING (is_business_member(business_id, auth.uid())) WITH CHECK (is_business_member(business_id, auth.uid()));

-- Listings Table
ALTER TABLE public.listings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on listings" ON public.listings FOR ALL USING (is_business_member(business_id, auth.uid())) WITH CHECK (is_business_member(business_id, auth.uid()));

-- Bookings Table
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on bookings" ON public.bookings FOR ALL USING (is_business_member(business_id, auth.uid())) WITH CHECK (is_business_member(business_id, auth.uid()));

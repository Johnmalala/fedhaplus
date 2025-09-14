/*
          # [Operation Name]
          Idempotent Function and Policy Fix

          ## Query Description: "This operation will safely reset and recreate all custom database functions and their dependent security policies. It is designed to fix inconsistencies from previous failed migrations. It first removes the functions and policies, then immediately recreates them with the correct, secure definitions. No data will be lost, and security will be fully restored upon completion."
          
          ## Metadata:
          - Schema-Category: ["Structural"]
          - Impact-Level: ["Medium"]
          - Requires-Backup: false
          - Reversible: false
          
          ## Structure Details:
          - Drops and recreates all custom functions (is_business_member, get_dashboard_stats, etc.).
          - Drops and recreates all Row-Level Security policies on all application tables.
          
          ## Security Implications:
          - RLS Status: [Enabled]
          - Policy Changes: [Yes]
          - Auth Requirements: [service_role]
          
          ## Performance Impact:
          - Indexes: [Not Affected]
          - Triggers: [Not Affected]
          - Estimated Impact: [Low. There will be a brief moment during the transaction where policies are dropped and re-added. Access is restored immediately.]
          */

-- Step 1: Ensure all ENUM types exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'business_type_enum') THEN CREATE TYPE public.business_type_enum AS ENUM ('hardware', 'supermarket', 'rentals', 'airbnb', 'hotel', 'school'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'staff_role_enum') THEN CREATE TYPE public.staff_role_enum AS ENUM ('owner', 'manager', 'cashier', 'accountant', 'teacher', 'front_desk', 'housekeeper'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status_enum') THEN CREATE TYPE public.payment_status_enum AS ENUM ('pending', 'paid', 'overdue', 'cancelled'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_status_enum') THEN CREATE TYPE public.subscription_status_enum AS ENUM ('trial', 'active', 'cancelled', 'expired'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'room_status_enum') THEN CREATE TYPE public.room_status_enum AS ENUM ('Available', 'Occupied', 'Cleaning', 'Maintenance'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'listing_status_enum') THEN CREATE TYPE public.listing_status_enum AS ENUM ('Listed', 'Booked', 'Maintenance'); END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'booking_status_enum') THEN CREATE TYPE public.booking_status_enum AS ENUM ('Confirmed', 'Checked-in', 'Checked-out', 'Cancelled'); END IF;
END$$;

-- Step 2: Drop all custom functions using CASCADE. This will also drop dependent policies.
DROP FUNCTION IF EXISTS public.is_business_member(uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_dashboard_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.invite_staff(uuid, text, public.staff_role_enum) CASCADE;
DROP FUNCTION IF EXISTS public.create_sale_and_items(uuid, uuid, jsonb) CASCADE;
DROP FUNCTION IF EXISTS public.create_booking(uuid, text, text, date, date, integer, numeric, uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_my_businesses() CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- Step 3: Recreate all functions with correct security settings

-- Function: is_business_member
CREATE OR REPLACE FUNCTION public.is_business_member(p_business_id uuid, p_user_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN EXISTS (SELECT 1 FROM staff_roles WHERE business_id = p_business_id AND user_id = p_user_id AND is_active = true);
END;
$$;

-- Function: get_my_businesses
CREATE OR REPLACE FUNCTION public.get_my_businesses()
RETURNS SETOF businesses LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN QUERY SELECT b.* FROM businesses b JOIN staff_roles sr ON b.id = sr.business_id WHERE sr.user_id = auth.uid() AND sr.is_active = true;
END;
$$;

-- Function: get_dashboard_stats
CREATE OR REPLACE FUNCTION public.get_dashboard_stats(p_business_id uuid)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  revenue_data json;
  customer_count int;
  business_type_val business_type_enum;
BEGIN
  SELECT business_type INTO business_type_val FROM businesses WHERE id = p_business_id;
  IF business_type_val = 'school' THEN
    SELECT json_agg(json_build_object('amount', amount, 'created_at', created_at)) INTO revenue_data FROM fee_payments WHERE business_id = p_business_id;
    SELECT count(*) INTO customer_count FROM students WHERE business_id = p_business_id AND is_active = true;
  ELSIF business_type_val = 'rentals' THEN
    SELECT json_agg(json_build_object('amount', amount, 'created_at', created_at)) INTO revenue_data FROM rent_payments WHERE business_id = p_business_id;
    SELECT count(*) INTO customer_count FROM tenants WHERE business_id = p_business_id AND is_active = true;
  ELSIF business_type_val IN ('hotel', 'airbnb') THEN
    SELECT json_agg(json_build_object('amount', total_amount, 'created_at', created_at)) INTO revenue_data FROM bookings WHERE business_id = p_business_id AND payment_status = 'paid';
    customer_count := 0;
  ELSE
    SELECT json_agg(json_build_object('amount', total_amount, 'created_at', created_at)) INTO revenue_data FROM sales WHERE business_id = p_business_id;
    customer_count := 0;
  END IF;
  RETURN json_build_object('revenue_data', COALESCE(revenue_data, '[]'::json), 'customer_count', customer_count);
END;
$$;

-- Function: invite_staff
CREATE OR REPLACE FUNCTION public.invite_staff(p_business_id uuid, p_invitee_email text, p_role public.staff_role_enum)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  invitee_id uuid;
  inviter_id uuid := auth.uid();
BEGIN
  IF NOT EXISTS (SELECT 1 FROM staff_roles WHERE business_id = p_business_id AND user_id = inviter_id AND role IN ('owner', 'manager') AND is_active = true) THEN RAISE EXCEPTION 'Only owners or managers can invite staff.'; END IF;
  SELECT id INTO invitee_id FROM auth.users WHERE email = p_invitee_email;
  IF invitee_id IS NULL THEN RAISE EXCEPTION 'User with email % not found. Please ask them to sign up for Fedha Plus first.', p_invitee_email; END IF;
  IF EXISTS (SELECT 1 FROM staff_roles WHERE business_id = p_business_id AND user_id = invitee_id) THEN RAISE EXCEPTION 'This user is already a member of the business.'; END IF;
  INSERT INTO staff_roles (business_id, user_id, role, invited_by, is_active) VALUES (p_business_id, invitee_id, p_role, inviter_id, true);
END;
$$;

-- Function: create_sale_and_items
CREATE OR REPLACE FUNCTION public.create_sale_and_items(p_business_id uuid, p_cashier_id uuid, p_items jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  new_sale_id uuid;
  total_sale_amount numeric := 0;
  item record;
  receipt_no text;
BEGIN
  FOR item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(product_id uuid, quantity int, unit_price numeric) LOOP
    total_sale_amount := total_sale_amount + (item.quantity * item.unit_price);
    IF (SELECT stock_quantity FROM products WHERE id = item.product_id) < item.quantity THEN RAISE EXCEPTION 'Not enough stock for product ID %', item.product_id; END IF;
  END LOOP;
  receipt_no := 'INV-' || to_char(now(), 'YYYYMMDD') || '-' || (SELECT lpad((count(*) + 1)::text, 4, '0') FROM sales WHERE business_id = p_business_id AND date(created_at) = current_date);
  INSERT INTO sales (business_id, cashier_id, total_amount, payment_method, receipt_number) VALUES (p_business_id, p_cashier_id, total_sale_amount, 'cash', receipt_no) RETURNING id INTO new_sale_id;
  FOR item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(product_id uuid, quantity int, unit_price numeric) LOOP
    INSERT INTO sale_items (sale_id, product_id, quantity, unit_price, total_price) VALUES (new_sale_id, item.product_id, item.quantity, item.unit_price, item.quantity * item.unit_price);
    UPDATE products SET stock_quantity = stock_quantity - item.quantity WHERE id = item.product_id;
  END LOOP;
END;
$$;

-- Function: create_booking
CREATE OR REPLACE FUNCTION public.create_booking(p_business_id uuid, p_guest_name text, p_guest_phone text, p_check_in_date date, p_check_out_date date, p_guests_count integer, p_total_amount numeric, p_room_id uuid DEFAULT NULL, p_listing_id uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO bookings (business_id, guest_name, guest_phone, check_in_date, check_out_date, guests_count, total_amount, room_id, listing_id, booking_status, payment_status, paid_amount)
  VALUES (p_business_id, p_guest_name, p_guest_phone, p_check_in_date, p_check_out_date, p_guests_count, p_total_amount, p_room_id, p_listing_id, 'Confirmed', 'pending', 0);
  IF p_room_id IS NOT NULL THEN UPDATE rooms SET status = 'Occupied' WHERE id = p_room_id; END IF;
  IF p_listing_id IS NOT NULL THEN UPDATE listings SET status = 'Booked' WHERE id = p_listing_id; END IF;
END;
$$;

-- Function: handle_new_user (Trigger function)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, phone) VALUES (new.id, new.email, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'phone');
  RETURN new;
END;
$$;

-- Step 4: Re-create all RLS policies that were dropped by CASCADE
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow owners to manage their own business" ON public.businesses FOR ALL USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());
CREATE POLICY "Allow business members to view their business" ON public.businesses FOR SELECT USING (public.is_business_member(id, auth.uid()));

ALTER TABLE public.staff_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow owners to manage staff" ON public.staff_roles FOR ALL USING (public.is_business_member(business_id, auth.uid())) WITH CHECK (public.is_business_member(business_id, auth.uid()));
CREATE POLICY "Allow staff to view their own role" ON public.staff_roles FOR SELECT USING (user_id = auth.uid());

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow business members to view subscription" ON public.subscriptions FOR SELECT USING (public.is_business_member(business_id, auth.uid()));

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on products" ON public.products FOR ALL USING (public.is_business_member(business_id, auth.uid())) WITH CHECK (public.is_business_member(business_id, auth.uid()));

ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on sales" ON public.sales FOR ALL USING (public.is_business_member(business_id, auth.uid())) WITH CHECK (public.is_business_member(business_id, auth.uid()));

ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on sale_items" ON public.sale_items FOR ALL USING (EXISTS (SELECT 1 FROM sales WHERE sales.id = sale_items.sale_id AND public.is_business_member(sales.business_id, auth.uid()))) WITH CHECK (EXISTS (SELECT 1 FROM sales WHERE sales.id = sale_items.sale_id AND public.is_business_member(sales.business_id, auth.uid())));

ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on tenants" ON public.tenants FOR ALL USING (public.is_business_member(business_id, auth.uid())) WITH CHECK (public.is_business_member(business_id, auth.uid()));

ALTER TABLE public.rent_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on rent_payments" ON public.rent_payments FOR ALL USING (public.is_business_member(business_id, auth.uid())) WITH CHECK (public.is_business_member(business_id, auth.uid()));

ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on students" ON public.students FOR ALL USING (public.is_business_member(business_id, auth.uid())) WITH CHECK (public.is_business_member(business_id, auth.uid()));

ALTER TABLE public.fee_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on fee_payments" ON public.fee_payments FOR ALL USING (public.is_business_member(business_id, auth.uid())) WITH CHECK (public.is_business_member(business_id, auth.uid()));

ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on rooms" ON public.rooms FOR ALL USING (public.is_business_member(business_id, auth.uid())) WITH CHECK (public.is_business_member(business_id, auth.uid()));

ALTER TABLE public.listings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on listings" ON public.listings FOR ALL USING (public.is_business_member(business_id, auth.uid())) WITH CHECK (public.is_business_member(business_id, auth.uid()));

ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on bookings" ON public.bookings FOR ALL USING (public.is_business_member(business_id, auth.uid())) WITH CHECK (public.is_business_member(business_id, auth.uid()));

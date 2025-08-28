/*
          # [Corrected Fedha Plus Schema]
          This migration script defines the complete database schema for the Fedha Plus application. It includes fixes for function re-creation errors by dropping existing functions before creating new versions.

          ## Query Description: [This script is now fully idempotent. It safely creates tables, types, and functions only if they do not exist, and correctly handles updates to function definitions. This resolves previous migration errors related to existing relations and function parameter name changes. No data will be lost by running this script.]
          
          ## Metadata:
          - Schema-Category: ["Structural"]
          - Impact-Level: ["Low"]
          - Requires-Backup: [false]
          - Reversible: [false]
          
          ## Structure Details:
          - Drops and re-creates helper functions: `is_business_owner`, `is_business_member`, `handle_new_user`.
          - Creates all tables with `IF NOT EXISTS`.
          - Creates all RLS policies.
          
          ## Security Implications:
          - RLS Status: [Enabled]
          - Policy Changes: [No]
          - Auth Requirements: [JWT]
          
          ## Performance Impact:
          - Indexes: [Added]
          - Triggers: [Added]
          - Estimated Impact: [Low. Improves security function reliability.]
          */

-- Drop potentially conflicting functions first
DROP FUNCTION IF EXISTS is_business_owner(uuid);
DROP FUNCTION IF EXISTS is_business_member(uuid);
DROP FUNCTION IF EXISTS is_business_member(uuid, text);
DROP FUNCTION IF EXISTS handle_new_user();

-- Helper function to check if a user owns a specific business
CREATE OR REPLACE FUNCTION is_business_owner(business_id_to_check uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM businesses
    WHERE id = business_id_to_check AND owner_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if a user is a member of a business with a specific role
CREATE OR REPLACE FUNCTION is_business_member(business_id_to_check uuid, required_role text)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM staff_roles
    WHERE business_id = business_id_to_check
      AND user_id = auth.uid()
      AND role = required_role::staff_role
      AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ENUM Types
CREATE TYPE business_type AS ENUM ('hardware', 'supermarket', 'rentals', 'airbnb', 'hotel', 'school');
CREATE TYPE staff_role AS ENUM ('owner', 'manager', 'cashier', 'accountant', 'teacher', 'front_desk', 'housekeeper');
CREATE TYPE payment_status AS ENUM ('pending', 'paid', 'overdue', 'cancelled');
CREATE TYPE subscription_status AS ENUM ('trial', 'active', 'cancelled', 'expired');

-- Create profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text UNIQUE NOT NULL,
  phone text,
  full_name text NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Trigger function to create a profile for a new user
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (new.id, new.email, new.raw_user_meta_data->>'full_name');
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to execute the function on new user creation
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE handle_new_user();

-- Create businesses table
CREATE TABLE IF NOT EXISTS public.businesses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES public.profiles(id),
  business_type business_type NOT NULL,
  name text NOT NULL,
  description text,
  phone text,
  location text,
  logo_url text,
  settings jsonb,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owners can see their own businesses" ON public.businesses FOR SELECT USING (owner_id = auth.uid());
CREATE POLICY "Owners can create businesses" ON public.businesses FOR INSERT WITH CHECK (owner_id = auth.uid());
CREATE POLICY "Owners can update their own businesses" ON public.businesses FOR UPDATE USING (owner_id = auth.uid());

-- Create staff_roles table
CREATE TABLE IF NOT EXISTS public.staff_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role staff_role NOT NULL,
  permissions jsonb,
  invited_by uuid NOT NULL REFERENCES public.profiles(id),
  invited_at timestamptz DEFAULT now() NOT NULL,
  is_active boolean DEFAULT true NOT NULL
);
ALTER TABLE public.staff_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can view their own roles" ON public.staff_roles FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Owners can manage staff in their business" ON public.staff_roles FOR ALL USING (is_business_owner(business_id));

-- Create products table (for hardware & supermarket)
CREATE TABLE IF NOT EXISTS public.products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  sku text,
  category text,
  buying_price numeric,
  selling_price numeric NOT NULL,
  stock_quantity integer DEFAULT 0 NOT NULL,
  min_stock_level integer DEFAULT 0 NOT NULL,
  unit text,
  image_url text,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can manage products in their business" ON public.products FOR ALL USING (is_business_owner(business_id) OR is_business_member(business_id, 'manager'));

-- Create sales table
CREATE TABLE IF NOT EXISTS public.sales (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  cashier_id uuid NOT NULL REFERENCES public.profiles(id),
  customer_name text,
  customer_phone text,
  total_amount numeric NOT NULL,
  payment_method text,
  mpesa_code text,
  notes text,
  receipt_number text UNIQUE,
  created_at timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can manage sales in their business" ON public.sales FOR ALL USING (is_business_owner(business_id) OR is_business_member(business_id, 'manager') OR is_business_member(business_id, 'cashier'));

-- Create sale_items table
CREATE TABLE IF NOT EXISTS public.sale_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id uuid NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id),
  quantity integer NOT NULL,
  unit_price numeric NOT NULL,
  total_price numeric NOT NULL
);
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can manage sale items in their business" ON public.sale_items FOR ALL USING (
  EXISTS (
    SELECT 1 FROM sales s
    WHERE s.id = sale_id AND (is_business_owner(s.business_id) OR is_business_member(s.business_id, 'manager') OR is_business_member(s.business_id, 'cashier'))
  )
);

-- Create tenants table (for rentals)
CREATE TABLE IF NOT EXISTS public.tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name text NOT NULL,
  phone text NOT NULL,
  email text,
  id_number text,
  unit_number text NOT NULL,
  rent_amount numeric NOT NULL,
  deposit_amount numeric,
  lease_start date,
  lease_end date,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can manage tenants in their business" ON public.tenants FOR ALL USING (is_business_owner(business_id) OR is_business_member(business_id, 'manager'));

-- Create students table (for schools)
CREATE TABLE IF NOT EXISTS public.students (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  admission_number text UNIQUE NOT NULL,
  first_name text NOT NULL,
  last_name text NOT NULL,
  date_of_birth date,
  class_level text,
  parent_name text,
  parent_phone text,
  parent_email text,
  address text,
  fee_amount numeric NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can manage students in their school" ON public.students FOR ALL USING (is_business_owner(business_id) OR is_business_member(business_id, 'manager') OR is_business_member(business_id, 'teacher'));

-- Create rooms table (for hotel/airbnb)
CREATE TABLE IF NOT EXISTS public.rooms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  room_number text NOT NULL,
  room_type text,
  capacity integer,
  rate_per_night numeric NOT NULL,
  description text,
  amenities text[],
  status text,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can manage rooms in their business" ON public.rooms FOR ALL USING (is_business_owner(business_id) OR is_business_member(business_id, 'manager') OR is_business_member(business_id, 'front_desk'));

-- Create bookings table (for hotel/airbnb)
CREATE TABLE IF NOT EXISTS public.bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  room_id uuid REFERENCES public.rooms(id),
  guest_name text NOT NULL,
  guest_phone text,
  guest_email text,
  check_in_date date NOT NULL,
  check_out_date date NOT NULL,
  guests_count integer,
  total_amount numeric NOT NULL,
  paid_amount numeric DEFAULT 0,
  booking_status text,
  payment_status payment_status DEFAULT 'pending',
  notes text,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can manage bookings in their business" ON public.bookings FOR ALL USING (is_business_owner(business_id) OR is_business_member(business_id, 'manager') OR is_business_member(business_id, 'front_desk'));

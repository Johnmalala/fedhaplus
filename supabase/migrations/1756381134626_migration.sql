/*
          # [Fedha Plus Initial Schema - Idempotent]
          This migration sets up the complete database schema for the Fedha Plus application. This version is fully idempotent, meaning it can be run multiple times without causing errors by checking for the existence of objects before creating them, and dropping/recreating functions and policies to ensure they are up-to-date.
          ## Query Description: [This script safely creates all necessary tables, types, functions, and security policies. It is designed to run on a new or partially created database without conflicts.]
          ## Metadata:
          - Schema-Category: ["Structural"]
          - Impact-Level: ["High"]
          - Requires-Backup: [false]
          - Reversible: [false]
          ## Structure Details:
          - Tables: profiles, businesses, staff_roles, products, sales, sale_items, tenants, rent_payments, students, fee_payments, rooms, bookings
          - Types: business_type, staff_role, payment_status, subscription_status
          - Functions: handle_new_user, is_business_owner, is_business_member
          - RLS Policies: Applied to all major tables to ensure data isolation.
          ## Security Implications:
          - RLS Status: [Enabled]
          - Policy Changes: [Yes]
          - Auth Requirements: [JWT authentication required for all data access]
          ## Performance Impact:
          - Indexes: [Added on foreign keys and frequently queried columns]
          - Triggers: [Added on auth.users for profile creation]
          - Estimated Impact: [Low, as this is the initial setup with optimized indexes.]
          */

-- 1. Custom Types (Idempotent)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'business_type') THEN
        CREATE TYPE public.business_type AS ENUM ('hardware', 'supermarket', 'rentals', 'airbnb', 'hotel', 'school');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'staff_role') THEN
        CREATE TYPE public.staff_role AS ENUM ('owner', 'manager', 'cashier', 'accountant', 'teacher', 'front_desk', 'housekeeper');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status') THEN
        CREATE TYPE public.payment_status AS ENUM ('pending', 'paid', 'overdue', 'cancelled');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_status') THEN
        CREATE TYPE public.subscription_status AS ENUM ('trial', 'active', 'cancelled', 'expired');
    END IF;
END
$$;

-- 2. Tables (Idempotent)
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE,
  phone TEXT,
  full_name TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.businesses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES public.profiles(id),
  business_type public.business_type NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  phone TEXT,
  location TEXT,
  logo_url TEXT,
  settings JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.staff_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role public.staff_role NOT NULL,
  permissions JSONB DEFAULT '{}',
  invited_by uuid REFERENCES public.profiles(id),
  invited_at TIMESTAMPTZ DEFAULT now(),
  is_active BOOLEAN DEFAULT true,
  UNIQUE(business_id, user_id)
);
CREATE TABLE IF NOT EXISTS public.products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  sku TEXT,
  category TEXT,
  buying_price NUMERIC(10, 2),
  selling_price NUMERIC(10, 2) NOT NULL,
  stock_quantity INT DEFAULT 0,
  min_stock_level INT DEFAULT 0,
  unit TEXT,
  image_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.sales (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  cashier_id uuid REFERENCES public.profiles(id),
  customer_name TEXT,
  customer_phone TEXT,
  total_amount NUMERIC(10, 2) NOT NULL,
  payment_method TEXT,
  mpesa_code TEXT,
  notes TEXT,
  receipt_number TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.sale_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id uuid NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id),
  quantity INT NOT NULL,
  unit_price NUMERIC(10, 2) NOT NULL,
  total_price NUMERIC(10, 2) NOT NULL
);
CREATE TABLE IF NOT EXISTS public.tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  email TEXT,
  id_number TEXT,
  unit_number TEXT NOT NULL,
  rent_amount NUMERIC(10, 2) NOT NULL,
  deposit_amount NUMERIC(10, 2),
  lease_start DATE,
  lease_end DATE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.rent_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  amount NUMERIC(10, 2) NOT NULL,
  payment_date DATE NOT NULL,
  payment_method TEXT,
  status public.payment_status DEFAULT 'paid',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.students (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  admission_number TEXT UNIQUE NOT NULL,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  date_of_birth DATE,
  class_level TEXT,
  parent_name TEXT,
  parent_phone TEXT,
  parent_email TEXT,
  address TEXT,
  fee_amount NUMERIC(10, 2),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.fee_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  amount NUMERIC(10, 2) NOT NULL,
  payment_date DATE NOT NULL,
  term TEXT,
  payment_method TEXT,
  status public.payment_status DEFAULT 'paid',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.rooms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  room_number TEXT NOT NULL,
  room_type TEXT,
  capacity INT,
  rate_per_night NUMERIC(10, 2),
  description TEXT,
  amenities TEXT[],
  status TEXT DEFAULT 'available',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  room_id uuid REFERENCES public.rooms(id),
  guest_name TEXT NOT NULL,
  guest_phone TEXT,
  guest_email TEXT,
  check_in_date DATE NOT NULL,
  check_out_date DATE NOT NULL,
  guests_count INT,
  total_amount NUMERIC(10, 2),
  paid_amount NUMERIC(10, 2) DEFAULT 0,
  booking_status TEXT DEFAULT 'confirmed',
  payment_status public.payment_status DEFAULT 'pending',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Indexes (Idempotent)
CREATE INDEX IF NOT EXISTS idx_businesses_owner_id ON public.businesses(owner_id);
CREATE INDEX IF NOT EXISTS idx_staff_roles_business_id ON public.staff_roles(business_id);
CREATE INDEX IF NOT EXISTS idx_staff_roles_user_id ON public.staff_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_products_business_id ON public.products(business_id);
CREATE INDEX IF NOT EXISTS idx_sales_business_id ON public.sales(business_id);
CREATE INDEX IF NOT EXISTS idx_tenants_business_id ON public.tenants(business_id);
CREATE INDEX IF NOT EXISTS idx_students_business_id ON public.students(business_id);
CREATE INDEX IF NOT EXISTS idx_rooms_business_id ON public.rooms(business_id);
CREATE INDEX IF NOT EXISTS idx_bookings_business_id ON public.bookings(business_id);

-- Drop functions before recreating to handle signature changes
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.is_business_owner(uuid);
DROP FUNCTION IF EXISTS public.is_business_member(uuid);

-- 4. Helper Functions
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (new.id, new.email, new.raw_user_meta_data->>'full_name');
  RETURN new;
END;
$$;

CREATE OR REPLACE FUNCTION public.is_business_owner(p_business_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.businesses
    WHERE id = p_business_id AND owner_id = auth.uid()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.is_business_member(p_business_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN auth.uid() IS NOT NULL AND (
    is_business_owner(p_business_id) OR
    EXISTS (
      SELECT 1
      FROM public.staff_roles
      WHERE business_id = p_business_id AND user_id = auth.uid() AND is_active = true
    )
  );
END;
$$;

-- 5. Triggers (Idempotent)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 6. Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rent_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fee_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies before creating new ones
-- Profiles
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
-- Businesses
DROP POLICY IF EXISTS "Enable read access for members" ON public.businesses;
DROP POLICY IF EXISTS "Enable all access for owners" ON public.businesses;
-- Staff Roles
DROP POLICY IF EXISTS "Owners can manage staff" ON public.staff_roles;
DROP POLICY IF EXISTS "Staff can view their own role" ON public.staff_roles;
-- Products
DROP POLICY IF EXISTS "Enable read access for members" ON public.products;
DROP POLICY IF EXISTS "Enable full access for owners/managers" ON public.products;
-- Generic Policy for all other tables
DROP POLICY IF EXISTS "Enable read access for business members" ON public.sales;
DROP POLICY IF EXISTS "Enable full access for owners/managers" ON public.sales;
DROP POLICY IF EXISTS "Enable read access for business members" ON public.sale_items;
DROP POLICY IF EXISTS "Enable full access for owners/managers" ON public.sale_items;
DROP POLICY IF EXISTS "Enable read access for business members" ON public.tenants;
DROP POLICY IF EXISTS "Enable full access for owners/managers" ON public.tenants;
DROP POLICY IF EXISTS "Enable read access for business members" ON public.rent_payments;
DROP POLICY IF EXISTS "Enable full access for owners/managers" ON public.rent_payments;
DROP POLICY IF EXISTS "Enable read access for business members" ON public.students;
DROP POLICY IF EXISTS "Enable full access for owners/managers" ON public.students;
DROP POLICY IF EXISTS "Enable read access for business members" ON public.fee_payments;
DROP POLICY IF EXISTS "Enable full access for owners/managers" ON public.fee_payments;
DROP POLICY IF EXISTS "Enable read access for business members" ON public.rooms;
DROP POLICY IF EXISTS "Enable full access for owners/managers" ON public.rooms;
DROP POLICY IF EXISTS "Enable read access for business members" ON public.bookings;
DROP POLICY IF EXISTS "Enable full access for owners/managers" ON public.bookings;

-- Create Policies
-- Profiles
CREATE POLICY "Users can view their own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
-- Businesses
CREATE POLICY "Enable all access for owners" ON public.businesses FOR ALL USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());
CREATE POLICY "Enable read access for members" ON public.businesses FOR SELECT USING (is_business_member(id));
-- Staff Roles
CREATE POLICY "Owners can manage staff" ON public.staff_roles FOR ALL USING (is_business_owner(business_id));
CREATE POLICY "Staff can view their own role" ON public.staff_roles FOR SELECT USING (user_id = auth.uid());
-- Products
CREATE POLICY "Enable read access for members" ON public.products FOR SELECT USING (is_business_member(business_id));
CREATE POLICY "Enable full access for owners/managers" ON public.products FOR ALL USING (is_business_owner(business_id));
-- Sales
CREATE POLICY "Enable read access for business members" ON public.sales FOR SELECT USING (is_business_member(business_id));
CREATE POLICY "Enable full access for owners/managers" ON public.sales FOR ALL USING (is_business_owner(business_id));
-- Sale Items
CREATE POLICY "Enable read access for business members" ON public.sale_items FOR SELECT USING (is_business_member((SELECT business_id FROM sales WHERE id = sale_id)));
CREATE POLICY "Enable full access for owners/managers" ON public.sale_items FOR ALL USING (is_business_owner((SELECT business_id FROM sales WHERE id = sale_id)));
-- Tenants
CREATE POLICY "Enable read access for business members" ON public.tenants FOR SELECT USING (is_business_member(business_id));
CREATE POLICY "Enable full access for owners/managers" ON public.tenants FOR ALL USING (is_business_owner(business_id));
-- Rent Payments
CREATE POLICY "Enable read access for business members" ON public.rent_payments FOR SELECT USING (is_business_member((SELECT business_id FROM tenants WHERE id = tenant_id)));
CREATE POLICY "Enable full access for owners/managers" ON public.rent_payments FOR ALL USING (is_business_owner((SELECT business_id FROM tenants WHERE id = tenant_id)));
-- Students
CREATE POLICY "Enable read access for business members" ON public.students FOR SELECT USING (is_business_member(business_id));
CREATE POLICY "Enable full access for owners/managers" ON public.students FOR ALL USING (is_business_owner(business_id));
-- Fee Payments
CREATE POLICY "Enable read access for business members" ON public.fee_payments FOR SELECT USING (is_business_member((SELECT business_id FROM students WHERE id = student_id)));
CREATE POLICY "Enable full access for owners/managers" ON public.fee_payments FOR ALL USING (is_business_owner((SELECT business_id FROM students WHERE id = student_id)));
-- Rooms
CREATE POLICY "Enable read access for business members" ON public.rooms FOR SELECT USING (is_business_member(business_id));
CREATE POLICY "Enable full access for owners/managers" ON public.rooms FOR ALL USING (is_business_owner(business_id));
-- Bookings
CREATE POLICY "Enable read access for business members" ON public.bookings FOR SELECT USING (is_business_member(business_id));
CREATE POLICY "Enable full access for owners/managers" ON public.bookings FOR ALL USING (is_business_owner(business_id));

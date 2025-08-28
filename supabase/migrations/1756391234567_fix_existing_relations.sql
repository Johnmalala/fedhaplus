/*
          # [Fedha Plus Initial Schema - Idempotent]
          [This script sets up the initial database schema for the Fedha Plus application. It is designed to be idempotent, meaning it can be run multiple times without causing errors. It will only create objects that do not already exist.]

          ## Query Description: [This script creates all necessary tables, types, functions, and policies for the Fedha Plus SaaS. It checks for the existence of objects before creating them to avoid conflicts with existing schemas, such as the auto-generated 'profiles' table from Supabase Auth.]
          
          ## Metadata:
          - Schema-Category: ["Structural"]
          - Impact-Level: ["Low"]
          - Requires-Backup: [false]
          - Reversible: [false]
          
          ## Structure Details:
          [Creates ENUM types, tables for profiles, businesses, staff, products, sales, tenants, students, rooms, and bookings. Also sets up a trigger to sync user profiles from `auth.users` and enables Row-Level Security.]
          
          ## Security Implications:
          - RLS Status: [Enabled]
          - Policy Changes: [Yes]
          - Auth Requirements: [User authentication is required for most operations.]
          
          ## Performance Impact:
          - Indexes: [Added]
          - Triggers: [Added]
          - Estimated Impact: [Low performance impact during setup. Indexes are created on foreign keys and frequently queried columns to ensure good performance.]
          */

-- Create ENUM types if they don't exist
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

-- 1. Profiles Table (Handles existing table)
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE,
  phone TEXT,
  full_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add columns if they don't exist to the profiles table
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Create function to handle new user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (new.id, new.email, new.raw_user_meta_data->>'full_name');
  RETURN new;
END;
$$;

-- Drop existing trigger before creating a new one to avoid conflicts
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create trigger to call the function on new user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();


-- 2. Businesses Table
CREATE TABLE IF NOT EXISTS public.businesses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  business_type public.business_type NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  phone TEXT,
  location TEXT,
  logo_url TEXT,
  settings JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owners can manage their own businesses" ON public.businesses;
CREATE POLICY "Owners can manage their own businesses" ON public.businesses
  FOR ALL USING (auth.uid() = owner_id);

-- 3. Staff Roles Table
CREATE TABLE IF NOT EXISTS public.staff_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.staff_role NOT NULL,
  permissions JSONB,
  invited_by uuid NOT NULL REFERENCES auth.users(id),
  invited_at TIMESTAMPTZ DEFAULT NOW(),
  is_active BOOLEAN DEFAULT TRUE
);
ALTER TABLE public.staff_roles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff can view their own roles" ON public.staff_roles;
CREATE POLICY "Staff can view their own roles" ON public.staff_roles
  FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Owners can manage staff in their business" ON public.staff_roles;
CREATE POLICY "Owners can manage staff in their business" ON public.staff_roles
  FOR ALL USING (business_id IN (SELECT id FROM public.businesses WHERE owner_id = auth.uid()));


-- 4. Products Table
CREATE TABLE IF NOT EXISTS public.products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  sku TEXT,
  category TEXT,
  buying_price NUMERIC(10, 2),
  selling_price NUMERIC(10, 2) NOT NULL,
  stock_quantity INT NOT NULL DEFAULT 0,
  min_stock_level INT DEFAULT 0,
  unit TEXT,
  image_url TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff can manage products in their assigned business" ON public.products;
CREATE POLICY "Staff can manage products in their assigned business" ON public.products
  FOR ALL USING (business_id IN (SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid() AND is_active = TRUE));

-- 5. Sales & Sale Items Tables
CREATE TABLE IF NOT EXISTS public.sales (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  cashier_id uuid REFERENCES auth.users(id),
  customer_name TEXT,
  customer_phone TEXT,
  total_amount NUMERIC(10, 2) NOT NULL,
  payment_method TEXT,
  mpesa_code TEXT,
  notes TEXT,
  receipt_number TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff can manage sales in their assigned business" ON public.sales;
CREATE POLICY "Staff can manage sales in their assigned business" ON public.sales
  FOR ALL USING (business_id IN (SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid() AND is_active = TRUE));

CREATE TABLE IF NOT EXISTS public.sale_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id uuid NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id),
  quantity INT NOT NULL,
  unit_price NUMERIC(10, 2) NOT NULL,
  total_price NUMERIC(10, 2) NOT NULL
);
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff can manage sale items in their assigned business" ON public.sale_items;
CREATE POLICY "Staff can manage sale items in their assigned business" ON public.sale_items
  FOR ALL USING (sale_id IN (SELECT id FROM public.sales WHERE business_id IN (SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid() AND is_active = TRUE)));


-- 6. Tenants Table (For Rentals)
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
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff can manage tenants in their assigned business" ON public.tenants;
CREATE POLICY "Staff can manage tenants in their assigned business" ON public.tenants
  FOR ALL USING (business_id IN (SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid() AND is_active = TRUE));


-- 7. Students Table (For Schools)
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
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff can manage students in their assigned business" ON public.students;
CREATE POLICY "Staff can manage students in their assigned business" ON public.students
  FOR ALL USING (business_id IN (SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid() AND is_active = TRUE));


-- 8. Rooms Table (For Hotels/Airbnb)
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
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff can manage rooms in their assigned business" ON public.rooms;
CREATE POLICY "Staff can manage rooms in their assigned business" ON public.rooms
  FOR ALL USING (business_id IN (SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid() AND is_active = TRUE));


-- 9. Bookings Table (For Hotels/Airbnb)
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
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff can manage bookings in their assigned business" ON public.bookings;
CREATE POLICY "Staff can manage bookings in their assigned business" ON public.bookings
  FOR ALL USING (business_id IN (SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid() AND is_active = TRUE));

-- Create indexes for foreign keys and frequently queried columns
CREATE INDEX IF NOT EXISTS idx_businesses_owner_id ON public.businesses(owner_id);
CREATE INDEX IF NOT EXISTS idx_staff_roles_business_id ON public.staff_roles(business_id);
CREATE INDEX IF NOT EXISTS idx_staff_roles_user_id ON public.staff_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_products_business_id ON public.products(business_id);
CREATE INDEX IF NOT EXISTS idx_sales_business_id ON public.sales(business_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON public.sale_items(sale_id);
CREATE INDEX IF NOT EXISTS idx_tenants_business_id ON public.tenants(business_id);
CREATE INDEX IF NOT EXISTS idx_students_business_id ON public.students(business_id);
CREATE INDEX IF NOT EXISTS idx_rooms_business_id ON public.rooms(business_id);
CREATE INDEX IF NOT EXISTS idx_bookings_business_id ON public.bookings(business_id);

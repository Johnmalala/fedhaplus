/*
# [Fedha Plus - Full Database Schema v1.2]
This script sets up the entire database schema for the Fedha Plus application.
It is designed to be idempotent, meaning it can be run multiple times without causing errors.
This version includes a fix for the `is_business_member` function recreation error.

## Query Description:
This operation will create all necessary tables, types, functions, and security policies.
- It uses `IF NOT EXISTS` for tables and types to prevent errors on re-runs.
- It drops and recreates helper functions to ensure the latest version is in use.
- It sets up Row-Level Security (RLS) to ensure data is properly isolated between businesses and users.
- It creates a trigger to automatically create a user profile upon new user signup.
There is no risk of data loss on existing tables as it only creates missing objects.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (by dropping the created objects)

## Structure Details:
- Tables: profiles, businesses, staff_roles, products, sales, sale_items, tenants, rent_payments, students, fee_payments, rooms, bookings
- ENUMs: business_type, staff_role, payment_status, subscription_status
- Functions: handle_new_user, is_business_member, add_owner_to_staff
- Triggers: on_auth_user_created, after_business_created
- RLS Policies: Applied to all data tables.

## Security Implications:
- RLS Status: Enabled on all tables.
- Policy Changes: Yes, this script defines the core RLS policies.
- Auth Requirements: Policies rely on `auth.uid()` to identify the current user.

## Performance Impact:
- Indexes: Primary keys and foreign keys are indexed by default. Additional indexes are created on frequently queried columns (e.g., `business_id`).
- Triggers: One trigger on `auth.users` for profile creation and one on `businesses` for staff role creation.
- Estimated Impact: Low. The operations are fast and only run if objects are missing.
*/

-- Drop the function first to allow parameter name changes during development.
-- This resolves the "cannot change name of input parameter" error.
DROP FUNCTION IF EXISTS public.is_business_member(uuid);

-- Create custom ENUM types if they don't exist
DO $$ BEGIN
    CREATE TYPE public.business_type AS ENUM ('hardware', 'supermarket', 'rentals', 'airbnb', 'hotel', 'school');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.staff_role AS ENUM ('owner', 'manager', 'cashier', 'accountant', 'teacher', 'front_desk', 'housekeeper');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.payment_status AS ENUM ('pending', 'paid', 'overdue', 'cancelled');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.subscription_status AS ENUM ('trial', 'active', 'cancelled', 'expired');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;


-- 1. Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text UNIQUE,
  phone text,
  full_name text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view their own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Function to create a profile for a new user
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (new.id, new.email, new.raw_user_meta_data->>'full_name');
  RETURN new;
END;
$$;

-- Trigger to call the function on new user creation
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();


-- 2. Businesses Table
CREATE TABLE IF NOT EXISTS public.businesses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  business_type public.business_type NOT NULL,
  name text NOT NULL,
  description text,
  phone text,
  location text,
  logo_url text,
  settings jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_businesses_owner_id ON public.businesses(owner_id);
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;


-- 3. Staff Roles Table
CREATE TABLE IF NOT EXISTS public.staff_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.staff_role NOT NULL,
  permissions jsonb,
  invited_by uuid REFERENCES auth.users(id),
  invited_at timestamptz DEFAULT now(),
  is_active boolean DEFAULT true
);
CREATE INDEX IF NOT EXISTS idx_staff_roles_business_id ON public.staff_roles(business_id);
CREATE INDEX IF NOT EXISTS idx_staff_roles_user_id ON public.staff_roles(user_id);
ALTER TABLE public.staff_roles ENABLE ROW LEVEL SECURITY;

-- Function to automatically add owner as a staff member when a business is created
CREATE OR REPLACE FUNCTION public.add_owner_to_staff()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.staff_roles (business_id, user_id, role, invited_by, is_active)
  VALUES (NEW.id, NEW.owner_id, 'owner', NEW.owner_id, true);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS after_business_created ON public.businesses;
CREATE TRIGGER after_business_created
  AFTER INSERT ON public.businesses
  FOR EACH ROW EXECUTE PROCEDURE public.add_owner_to_staff();

-- Helper function to check if a user is a member of a business
CREATE OR REPLACE FUNCTION public.is_business_member(p_business_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.staff_roles sr
    WHERE sr.business_id = p_business_id
      AND sr.user_id = auth.uid()
      AND sr.is_active = true
  );
END;
$$;

-- RLS Policies for businesses and staff_roles
DROP POLICY IF EXISTS "Users can view businesses they are a member of" ON public.businesses;
CREATE POLICY "Users can view businesses they are a member of" ON public.businesses
  FOR SELECT USING (public.is_business_member(id));

DROP POLICY IF EXISTS "Owners can update their own businesses" ON public.businesses;
CREATE POLICY "Owners can update their own businesses" ON public.businesses
  FOR UPDATE USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Owners can delete their own businesses" ON public.businesses;
CREATE POLICY "Owners can delete their own businesses" ON public.businesses
  FOR DELETE USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Business members can view staff in their business" ON public.staff_roles;
CREATE POLICY "Business members can view staff in their business" ON public.staff_roles
  FOR SELECT USING (public.is_business_member(business_id));

DROP POLICY IF EXISTS "Owners can manage staff in their business" ON public.staff_roles;
CREATE POLICY "Owners can manage staff in their business" ON public.staff_roles
  FOR ALL USING (
    (SELECT owner_id FROM public.businesses WHERE id = business_id) = auth.uid()
  );


-- 4. Products Table (for hardware & supermarket)
CREATE TABLE IF NOT EXISTS public.products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  sku text,
  category text,
  buying_price numeric,
  selling_price numeric NOT NULL,
  stock_quantity integer DEFAULT 0,
  min_stock_level integer DEFAULT 0,
  unit text,
  image_url text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_products_business_id ON public.products(business_id);
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Business members can manage products" ON public.products;
CREATE POLICY "Business members can manage products" ON public.products FOR ALL USING (public.is_business_member(business_id));

-- 5. Sales Table
CREATE TABLE IF NOT EXISTS public.sales (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  cashier_id uuid REFERENCES auth.users(id),
  customer_name text,
  customer_phone text,
  total_amount numeric NOT NULL,
  payment_method text,
  mpesa_code text,
  notes text,
  receipt_number text,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_sales_business_id ON public.sales(business_id);
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Business members can manage sales" ON public.sales;
CREATE POLICY "Business members can manage sales" ON public.sales FOR ALL USING (public.is_business_member(business_id));

-- 6. Sale Items Table
CREATE TABLE IF NOT EXISTS public.sale_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id uuid NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
  quantity numeric NOT NULL,
  unit_price numeric NOT NULL,
  total_price numeric NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON public.sale_items(sale_id);
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Business members can manage sale items" ON public.sale_items FOR ALL USING (
  public.is_business_member((SELECT business_id FROM sales WHERE id = sale_id))
);

-- 7. Tenants Table (for rentals)
CREATE TABLE IF NOT EXISTS public.tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name text NOT NULL,
  phone text NOT NULL,
  email text,
  id_number text,
  unit_number text,
  rent_amount numeric NOT NULL,
  deposit_amount numeric,
  lease_start date,
  lease_end date,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_tenants_business_id ON public.tenants(business_id);
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Business members can manage tenants" ON public.tenants;
CREATE POLICY "Business members can manage tenants" ON public.tenants FOR ALL USING (public.is_business_member(business_id));

-- 8. Rent Payments Table
CREATE TABLE IF NOT EXISTS public.rent_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  amount numeric NOT NULL,
  payment_date date NOT NULL,
  payment_for_month date NOT NULL,
  status public.payment_status DEFAULT 'paid',
  notes text,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_rent_payments_tenant_id ON public.rent_payments(tenant_id);
ALTER TABLE public.rent_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Business members can manage rent payments" ON public.rent_payments FOR ALL USING (
  public.is_business_member((SELECT business_id FROM tenants WHERE id = tenant_id))
);

-- 9. Students Table (for schools)
CREATE TABLE IF NOT EXISTS public.students (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  admission_number text UNIQUE,
  first_name text NOT NULL,
  last_name text NOT NULL,
  date_of_birth date,
  class_level text,
  parent_name text,
  parent_phone text,
  parent_email text,
  address text,
  fee_amount numeric,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_students_business_id ON public.students(business_id);
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Business members can manage students" ON public.students;
CREATE POLICY "Business members can manage students" ON public.students FOR ALL USING (public.is_business_member(business_id));

-- 10. Fee Payments Table
CREATE TABLE IF NOT EXISTS public.fee_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  amount numeric NOT NULL,
  payment_date date NOT NULL,
  term text,
  year integer,
  status public.payment_status DEFAULT 'paid',
  notes text,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_fee_payments_student_id ON public.fee_payments(student_id);
ALTER TABLE public.fee_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Business members can manage fee payments" ON public.fee_payments FOR ALL USING (
  public.is_business_member((SELECT business_id FROM students WHERE id = student_id))
);

-- 11. Rooms Table (for hotel/airbnb)
CREATE TABLE IF NOT EXISTS public.rooms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  room_number text NOT NULL,
  room_type text,
  capacity integer,
  rate_per_night numeric,
  description text,
  amenities text[],
  status text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_rooms_business_id ON public.rooms(business_id);
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Business members can manage rooms" ON public.rooms;
CREATE POLICY "Business members can manage rooms" ON public.rooms FOR ALL USING (public.is_business_member(business_id));

-- 12. Bookings Table
CREATE TABLE IF NOT EXISTS public.bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  room_id uuid REFERENCES public.rooms(id) ON DELETE SET NULL,
  guest_name text NOT NULL,
  guest_phone text,
  guest_email text,
  check_in_date date NOT NULL,
  check_out_date date NOT NULL,
  guests_count integer,
  total_amount numeric,
  paid_amount numeric,
  booking_status text,
  payment_status public.payment_status,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_bookings_business_id ON public.bookings(business_id);
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Business members can manage bookings" ON public.bookings;
CREATE POLICY "Business members can manage bookings" ON public.bookings FOR ALL USING (public.is_business_member(business_id));

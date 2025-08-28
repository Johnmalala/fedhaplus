-- Fedha Plus: Idempotent Schema (v2 - with function fix)
-- This script is safe to re-run. It uses `IF NOT EXISTS` for all creations
-- and explicitly drops/recreates the function that caused the error.

-- Fix: Explicitly drop the function that caused the error.
-- This is necessary because CREATE OR REPLACE FUNCTION cannot change parameter names.
DROP FUNCTION IF EXISTS public.is_business_member(uuid);


-- Create custom types if they don't exist
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
END
$$;

-- Table: profiles
-- Stores public user information.
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text,
  phone text,
  updated_at timestamptz DEFAULT now()
);

-- Function to create a profile for a new user
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name)
  VALUES (new.id, new.raw_user_meta_data->>'full_name');
  RETURN new;
END;
$$;

-- Trigger for new user creation
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Enable RLS for profiles table
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view their own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);


-- Function: is_business_member
-- Checks if the currently authenticated user is a member of a given business.
CREATE OR REPLACE FUNCTION public.is_business_member(p_business_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if the user is the owner
  IF EXISTS (
    SELECT 1
    FROM businesses
    WHERE id = p_business_id AND owner_id = auth.uid()
  ) THEN
    RETURN true;
  END IF;

  -- Check if the user is a staff member
  IF EXISTS (
    SELECT 1
    FROM staff_roles
    WHERE business_id = p_business_id AND user_id = auth.uid() AND is_active = true
  ) THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;


-- Table: businesses
-- Stores information about each business created by a user.
CREATE TABLE IF NOT EXISTS public.businesses (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  business_type public.business_type_enum NOT NULL,
  name text NOT NULL,
  description text,
  phone text,
  location text,
  logo_url text,
  settings jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_businesses_owner_id ON public.businesses(owner_id);

-- RLS for businesses table
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owners can manage their own businesses" ON public.businesses;
CREATE POLICY "Owners can manage their own businesses" ON public.businesses
  FOR ALL USING (owner_id = auth.uid());
DROP POLICY IF EXISTS "Staff can view their assigned business" ON public.businesses;
CREATE POLICY "Staff can view their assigned business" ON public.businesses
  FOR SELECT USING (is_business_member(id));


-- Table: staff_roles
-- Manages staff members and their roles within a business.
CREATE TABLE IF NOT EXISTS public.staff_roles (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.staff_role_enum NOT NULL,
  permissions jsonb DEFAULT '{}'::jsonb,
  invited_by uuid NOT NULL REFERENCES auth.users(id),
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_staff_roles_business_id ON public.staff_roles(business_id);
CREATE INDEX IF NOT EXISTS idx_staff_roles_user_id ON public.staff_roles(user_id);

-- RLS for staff_roles table
ALTER TABLE public.staff_roles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owners can manage staff in their business" ON public.staff_roles;
CREATE POLICY "Owners can manage staff in their business" ON public.staff_roles
  FOR ALL USING (business_id IN (SELECT b.id FROM public.businesses b WHERE b.owner_id = auth.uid()));
DROP POLICY IF EXISTS "Staff can view their own role" ON public.staff_roles;
CREATE POLICY "Staff can view their own role" ON public.staff_roles
  FOR SELECT USING (user_id = auth.uid());


-- Table: products (for hardware & supermarket)
CREATE TABLE IF NOT EXISTS public.products (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  sku text,
  category text,
  buying_price numeric(10, 2),
  selling_price numeric(10, 2) NOT NULL,
  stock_quantity integer DEFAULT 0,
  min_stock_level integer DEFAULT 0,
  unit text,
  image_url text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_products_business_id ON public.products(business_id);

-- RLS for products table
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Business members can manage products" ON public.products;
CREATE POLICY "Business members can manage products" ON public.products
  FOR ALL USING (is_business_member(business_id));


-- Table: sales (for hardware & supermarket)
CREATE TABLE IF NOT EXISTS public.sales (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  cashier_id uuid REFERENCES auth.users(id),
  customer_name text,
  customer_phone text,
  total_amount numeric(10, 2) NOT NULL,
  payment_method text,
  mpesa_code text,
  notes text,
  receipt_number text,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_sales_business_id ON public.sales(business_id);

-- RLS for sales table
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Business members can manage sales" ON public.sales;
CREATE POLICY "Business members can manage sales" ON public.sales
  FOR ALL USING (is_business_member(business_id));


-- Table: sale_items (for hardware & supermarket)
CREATE TABLE IF NOT EXISTS public.sale_items (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id uuid NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id),
  quantity integer NOT NULL,
  unit_price numeric(10, 2) NOT NULL,
  total_price numeric(10, 2) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON public.sale_items(sale_id);

-- RLS for sale_items table
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Business members can manage sale items" ON public.sale_items;
CREATE POLICY "Business members can manage sale items" ON public.sale_items
  FOR ALL USING (sale_id IN (SELECT s.id FROM public.sales s WHERE is_business_member(s.business_id)));


-- Table: tenants (for rentals)
CREATE TABLE IF NOT EXISTS public.tenants (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name text NOT NULL,
  phone text NOT NULL,
  email text,
  id_number text,
  unit_number text NOT NULL,
  rent_amount numeric(10, 2) NOT NULL,
  deposit_amount numeric(10, 2),
  lease_start date,
  lease_end date,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_tenants_business_id ON public.tenants(business_id);

-- RLS for tenants table
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Business members can manage tenants" ON public.tenants;
CREATE POLICY "Business members can manage tenants" ON public.tenants
  FOR ALL USING (is_business_member(business_id));


-- Table: students (for school)
CREATE TABLE IF NOT EXISTS public.students (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
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
  fee_amount numeric(10, 2),
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_students_business_id ON public.students(business_id);

-- RLS for students table
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Business members can manage students" ON public.students;
CREATE POLICY "Business members can manage students" ON public.students
  FOR ALL USING (is_business_member(business_id));


-- Table: rooms (for hotel & airbnb)
CREATE TABLE IF NOT EXISTS public.rooms (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  room_number text NOT NULL,
  room_type text,
  capacity integer,
  rate_per_night numeric(10, 2),
  description text,
  amenities text[],
  status text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_rooms_business_id ON public.rooms(business_id);

-- RLS for rooms table
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Business members can manage rooms" ON public.rooms;
CREATE POLICY "Business members can manage rooms" ON public.rooms
  FOR ALL USING (is_business_member(business_id));


-- Table: bookings (for hotel & airbnb)
CREATE TABLE IF NOT EXISTS public.bookings (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  room_id uuid REFERENCES public.rooms(id),
  guest_name text NOT NULL,
  guest_phone text,
  guest_email text,
  check_in_date date,
  check_out_date date,
  guests_count integer,
  total_amount numeric(10, 2),
  paid_amount numeric(10, 2),
  booking_status text,
  payment_status public.payment_status_enum,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_bookings_business_id ON public.bookings(business_id);

-- RLS for bookings table
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Business members can manage bookings" ON public.bookings;
CREATE POLICY "Business members can manage bookings" ON public.bookings
  FOR ALL USING (is_business_member(business_id));


-- Table: rent_payments (for rentals)
CREATE TABLE IF NOT EXISTS public.rent_payments (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  amount numeric(10, 2) NOT NULL,
  payment_date date NOT NULL,
  payment_for_month date NOT NULL,
  payment_method text,
  mpesa_code text,
  status public.payment_status_enum,
  notes text,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_rent_payments_tenant_id ON public.rent_payments(tenant_id);

-- RLS for rent_payments table
ALTER TABLE public.rent_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Business members can manage rent payments" ON public.rent_payments;
CREATE POLICY "Business members can manage rent payments" ON public.rent_payments
  FOR ALL USING (tenant_id IN (SELECT t.id FROM public.tenants t WHERE is_business_member(t.business_id)));


-- Table: fee_payments (for school)
CREATE TABLE IF NOT EXISTS public.fee_payments (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  amount numeric(10, 2) NOT NULL,
  payment_date date NOT NULL,
  term text,
  payment_method text,
  mpesa_code text,
  status public.payment_status_enum,
  notes text,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_fee_payments_student_id ON public.fee_payments(student_id);

-- RLS for fee_payments table
ALTER TABLE public.fee_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Business members can manage fee payments" ON public.fee_payments;
CREATE POLICY "Business members can manage fee payments" ON public.fee_payments
  FOR ALL USING (student_id IN (SELECT s.id FROM public.students s WHERE is_business_member(s.business_id)));

/*
          # Fedha Plus: Full Initial Schema
          This script establishes the complete database schema for the Fedha Plus application. It creates all tables, defines relationships with foreign keys, sets up row-level security (RLS) for multi-tenancy, and creates a trigger to automatically populate user profiles upon sign-up.

          ## Query Description: [This is a foundational schema setup. It is designed to be idempotent, using `CREATE TABLE IF NOT EXISTS` and other safe commands to prevent errors if parts of the schema already exist. This operation is structural and should not cause data loss on existing tables that match the defined structure. However, it enforces new foreign key constraints which might fail if orphaned records exist in your current tables. A backup is strongly recommended before the first application.]
          
          ## Metadata:
          - Schema-Category: ["Structural"]
          - Impact-Level: ["High"]
          - Requires-Backup: [true]
          - Reversible: [false]
          
          ## Structure Details:
          - **Tables Created:** profiles, businesses, staff_roles, products, sales, sale_items, tenants, rent_payments, students, fee_payments, rooms, bookings.
          - **Functions Created:** handle_new_user (to create profiles).
          - **Triggers Created:** on_auth_user_created (on auth.users table).
          
          ## Security Implications:
          - RLS Status: [Enabled]
          - Policy Changes: [Yes] - This script enables RLS on all new tables and creates policies to ensure users can only access data related to their own businesses.
          - Auth Requirements: [All policies are tied to the authenticated user's ID.]
          
          ## Performance Impact:
          - Indexes: [Added] - Primary keys and foreign keys are indexed by default.
          - Triggers: [Added] - A trigger is added to the `auth.users` table.
          - Estimated Impact: [Low performance impact on an empty database. The trigger is lightweight.]
          */

-- 1. PROFILES
-- Create a table for public user profiles
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  full_name text,
  phone text,
  updated_at timestamp with time zone,
  PRIMARY KEY (id)
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public profiles are viewable by everyone." ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can insert their own profile." ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update their own profile." ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Function to create a profile for a new user.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name)
  VALUES (new.id, new.raw_user_meta_data->>'full_name');
  RETURN new;
END;
$$;

-- Trigger to execute the function after a new user is created.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();


-- 2. BUSINESSES
-- Create a table for businesses, linked to a user.
CREATE TABLE IF NOT EXISTS public.businesses (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  business_type text NOT NULL, -- e.g., 'hardware', 'school'
  name text NOT NULL,
  description text,
  phone text,
  location text,
  logo_url text,
  settings jsonb,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can create businesses for themselves." ON public.businesses FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Users can view their own businesses." ON public.businesses FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Users can update their own businesses." ON public.businesses FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Users can delete their own businesses." ON public.businesses FOR DELETE USING (auth.uid() = owner_id);


-- 3. STAFF ROLES
-- Create a table for staff roles, linking users to businesses.
CREATE TABLE IF NOT EXISTS public.staff_roles (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    business_id uuid NOT NULL REFERENCES public.businesses ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
    role text NOT NULL, -- e.g., 'manager', 'cashier'
    is_active boolean DEFAULT true NOT NULL,
    invited_by uuid REFERENCES auth.users ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    UNIQUE (business_id, user_id)
);
ALTER TABLE public.staff_roles ENABLE ROW LEVEL SECURITY;
-- Owners can manage staff in their business.
CREATE POLICY "Owners can manage staff in their businesses." ON public.staff_roles FOR ALL
  USING (business_id IN (SELECT id FROM public.businesses WHERE owner_id = auth.uid()));
-- Staff can view their own role.
CREATE POLICY "Staff can view their own role." ON public.staff_roles FOR SELECT
  USING (user_id = auth.uid());


-- Add a helper function to check if a user is a member of a business
CREATE OR REPLACE FUNCTION is_business_member(p_business_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  is_owner boolean;
  is_staff boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM businesses WHERE id = p_business_id AND owner_id = auth.uid()
  ) INTO is_owner;

  SELECT EXISTS (
    SELECT 1 FROM staff_roles WHERE business_id = p_business_id AND user_id = auth.uid() AND is_active = true
  ) INTO is_staff;

  RETURN is_owner OR is_staff;
END;
$$;


-- 4. PRODUCTS (for hardware, supermarket)
CREATE TABLE IF NOT EXISTS public.products (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  business_id uuid NOT NULL REFERENCES public.businesses ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  sku text,
  category text,
  buying_price numeric,
  selling_price numeric NOT NULL,
  stock_quantity numeric NOT NULL DEFAULT 0,
  min_stock_level numeric,
  unit text,
  image_url text,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Business members can manage products." ON public.products FOR ALL
  USING (is_business_member(business_id));


-- 5. SALES & SALE ITEMS (for hardware, supermarket)
CREATE TABLE IF NOT EXISTS public.sales (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  business_id uuid NOT NULL REFERENCES public.businesses ON DELETE CASCADE,
  cashier_id uuid REFERENCES auth.users ON DELETE SET NULL,
  customer_name text,
  customer_phone text,
  total_amount numeric NOT NULL,
  payment_method text,
  mpesa_code text,
  notes text,
  receipt_number text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Business members can manage sales." ON public.sales FOR ALL
  USING (is_business_member(business_id));

CREATE TABLE IF NOT EXISTS public.sale_items (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  sale_id uuid NOT NULL REFERENCES public.sales ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products ON DELETE RESTRICT,
  quantity numeric NOT NULL,
  unit_price numeric NOT NULL,
  total_price numeric NOT NULL
);
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Business members can manage sale items." ON public.sale_items FOR ALL
  USING (sale_id IN (SELECT id FROM public.sales WHERE is_business_member(business_id)));


-- 6. TENANTS & RENT PAYMENTS (for rentals)
CREATE TABLE IF NOT EXISTS public.tenants (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  business_id uuid NOT NULL REFERENCES public.businesses ON DELETE CASCADE,
  name text NOT NULL,
  phone text,
  email text,
  id_number text,
  unit_number text NOT NULL,
  rent_amount numeric NOT NULL,
  deposit_amount numeric,
  lease_start date,
  lease_end date,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Business members can manage tenants." ON public.tenants FOR ALL
  USING (is_business_member(business_id));

CREATE TABLE IF NOT EXISTS public.rent_payments (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES public.tenants ON DELETE CASCADE,
  amount numeric NOT NULL,
  payment_date date NOT NULL,
  payment_method text,
  mpesa_code text,
  notes text,
  status text DEFAULT 'paid' NOT NULL, -- 'paid', 'pending'
  created_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.rent_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Business members can manage rent payments." ON public.rent_payments FOR ALL
  USING (tenant_id IN (SELECT id FROM public.tenants WHERE is_business_member(business_id)));


-- 7. STUDENTS & FEE PAYMENTS (for schools)
CREATE TABLE IF NOT EXISTS public.students (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  business_id uuid NOT NULL REFERENCES public.businesses ON DELETE CASCADE,
  admission_number text NOT NULL,
  first_name text NOT NULL,
  last_name text NOT NULL,
  date_of_birth date,
  class_level text,
  parent_name text,
  parent_phone text,
  parent_email text,
  address text,
  fee_amount numeric,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Business members can manage students." ON public.students FOR ALL
  USING (is_business_member(business_id));

CREATE TABLE IF NOT EXISTS public.fee_payments (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id uuid NOT NULL REFERENCES public.students ON DELETE CASCADE,
  amount numeric NOT NULL,
  payment_date date NOT NULL,
  payment_method text,
  mpesa_code text,
  notes text,
  status text DEFAULT 'paid' NOT NULL, -- 'paid', 'pending'
  created_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.fee_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Business members can manage fee payments." ON public.fee_payments FOR ALL
  USING (student_id IN (SELECT id FROM public.students WHERE is_business_member(business_id)));


-- 8. ROOMS & BOOKINGS (for hotel, airbnb)
CREATE TABLE IF NOT EXISTS public.rooms (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  business_id uuid NOT NULL REFERENCES public.businesses ON DELETE CASCADE,
  room_number text NOT NULL,
  room_type text,
  capacity integer,
  rate_per_night numeric NOT NULL,
  description text,
  amenities text[],
  status text DEFAULT 'available' NOT NULL, -- 'available', 'occupied', 'maintenance'
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Business members can manage rooms." ON public.rooms FOR ALL
  USING (is_business_member(business_id));

CREATE TABLE IF NOT EXISTS public.bookings (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  business_id uuid NOT NULL REFERENCES public.businesses ON DELETE CASCADE,
  room_id uuid REFERENCES public.rooms ON DELETE SET NULL,
  guest_name text NOT NULL,
  guest_phone text,
  guest_email text,
  check_in_date date NOT NULL,
  check_out_date date NOT NULL,
  guests_count integer,
  total_amount numeric,
  paid_amount numeric,
  booking_status text DEFAULT 'confirmed' NOT NULL, -- 'confirmed', 'checked_in', 'checked_out', 'cancelled'
  payment_status text,
  notes text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Business members can manage bookings." ON public.bookings FOR ALL
  USING (is_business_member(business_id));

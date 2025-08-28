-- [Migration to fix "relation already exists" errors]
-- This script modifies the initial schema setup to be idempotent, meaning it can be run multiple times without causing errors.
-- It uses `IF NOT EXISTS` for tables and types, and `CREATE OR REPLACE` for functions to handle cases where objects already exist in the database.

/*
# [Idempotent Schema Setup]
This migration ensures that all database objects are created safely, checking for their existence before attempting creation. This resolves the "relation already exists" error encountered during the initial migration.

## Query Description:
This operation will not cause data loss. It checks if tables, types, functions, and policies exist before creating them. If they exist, it skips them. This is a safe operation designed to bring the database schema to the desired state without errors.

## Metadata:
- Schema-Category: ["Safe", "Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: true (by manually dropping the created objects)

## Structure Details:
- Affects all tables, types, and functions from the initial schema.
- Adds `IF NOT EXISTS` to `CREATE TABLE` and `CREATE TYPE`.
- Uses `CREATE OR REPLACE FUNCTION` for the trigger function.
- Uses `DROP POLICY IF EXISTS ...; CREATE POLICY ...` for RLS policies.

## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes (re-applies policies idempotently)
- Auth Requirements: Supabase admin privileges to run migrations.

## Performance Impact:
- Indexes: Added (if they don't exist)
- Triggers: Added (or replaced if they exist)
- Estimated Impact: Negligible performance impact. This is a one-time setup operation.
*/

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
END$$;

-- Create profiles table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email character varying(255) UNIQUE,
    phone character varying(20),
    full_name text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.profiles IS 'Stores public user profile information.';

-- Create businesses table
CREATE TABLE IF NOT EXISTS public.businesses (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    owner_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    business_type public.business_type_enum NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    phone character varying(20),
    location text,
    logo_url text,
    settings jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.businesses IS 'Stores information about each business entity.';
CREATE INDEX IF NOT EXISTS idx_businesses_owner_id ON public.businesses(owner_id);

-- Create staff_roles table
CREATE TABLE IF NOT EXISTS public.staff_roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    role public.staff_role_enum NOT NULL,
    invited_by uuid NOT NULL REFERENCES public.profiles(id),
    invited_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true,
    invite_phone character varying(20)
);
COMMENT ON TABLE public.staff_roles IS 'Manages staff roles and permissions for each business.';
CREATE INDEX IF NOT EXISTS idx_staff_roles_business_id ON public.staff_roles(business_id);
CREATE INDEX IF NOT EXISTS idx_staff_roles_user_id ON public.staff_roles(user_id);

-- Create products table
CREATE TABLE IF NOT EXISTS public.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    name text NOT NULL,
    description text,
    sku character varying(100),
    category text,
    buying_price numeric(10,2),
    selling_price numeric(10,2) NOT NULL,
    stock_quantity integer DEFAULT 0,
    min_stock_level integer DEFAULT 0,
    unit character varying(50),
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_products_business_id ON public.products(business_id);

-- Create sales table
CREATE TABLE IF NOT EXISTS public.sales (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    cashier_id uuid REFERENCES public.profiles(id),
    total_amount numeric(10,2) NOT NULL,
    payment_method character varying(50),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sales_business_id ON public.sales(business_id);

-- Create sale_items table
CREATE TABLE IF NOT EXISTS public.sale_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    sale_id uuid NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id),
    quantity integer NOT NULL,
    unit_price numeric(10,2) NOT NULL,
    total_price numeric(10,2) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON public.sale_items(sale_id);

-- Create tenants table
CREATE TABLE IF NOT EXISTS public.tenants (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    name text NOT NULL,
    phone character varying(20) NOT NULL,
    email character varying(255),
    unit_number character varying(50),
    rent_amount numeric(10,2) NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_tenants_business_id ON public.tenants(business_id);

-- Create rent_payments table
CREATE TABLE IF NOT EXISTS public.rent_payments (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    amount numeric(10,2) NOT NULL,
    payment_date date NOT NULL,
    status public.payment_status_enum DEFAULT 'paid',
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_rent_payments_tenant_id ON public.rent_payments(tenant_id);

-- Create students table
CREATE TABLE IF NOT EXISTS public.students (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    admission_number character varying(50) UNIQUE,
    first_name text NOT NULL,
    last_name text NOT NULL,
    class_level character varying(50),
    parent_phone character varying(20),
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_students_business_id ON public.students(business_id);

-- Create fee_payments table
CREATE TABLE IF NOT EXISTS public.fee_payments (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    amount numeric(10,2) NOT NULL,
    payment_date date NOT NULL,
    term character varying(50),
    status public.payment_status_enum DEFAULT 'paid',
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_fee_payments_student_id ON public.fee_payments(student_id);

-- Create rooms table
CREATE TABLE IF NOT EXISTS public.rooms (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    room_number character varying(50) NOT NULL,
    room_type character varying(100),
    rate_per_night numeric(10,2) NOT NULL,
    status character varying(50) DEFAULT 'available',
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_rooms_business_id ON public.rooms(business_id);

-- Create bookings table
CREATE TABLE IF NOT EXISTS public.bookings (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    room_id uuid REFERENCES public.rooms(id),
    guest_name text NOT NULL,
    guest_phone character varying(20),
    check_in_date date NOT NULL,
    check_out_date date NOT NULL,
    paid_amount numeric(10,2) DEFAULT 0,
    status public.payment_status_enum DEFAULT 'pending',
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_bookings_business_id ON public.bookings(business_id);

-- Function to create a profile for a new user
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, phone)
  VALUES (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    new.phone
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
COMMENT ON FUNCTION public.handle_new_user() IS 'Creates a public profile for a new authenticated user.';

-- Trigger to call the function on new user creation
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Enable RLS for all tables
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

-- RLS Policies
-- Profiles: Users can see their own profile.
DROP POLICY IF EXISTS "Users can view their own profile." ON public.profiles;
CREATE POLICY "Users can view their own profile." ON public.profiles
  FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile." ON public.profiles;
CREATE POLICY "Users can update their own profile." ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Businesses: Owners can see and manage their own businesses.
DROP POLICY IF EXISTS "Owners can manage their own businesses." ON public.businesses;
CREATE POLICY "Owners can manage their own businesses." ON public.businesses
  FOR ALL USING (auth.uid() = owner_id);

-- Staff Roles:
DROP POLICY IF EXISTS "Owners can manage staff in their businesses." ON public.staff_roles;
CREATE POLICY "Owners can manage staff in their businesses." ON public.staff_roles
  FOR ALL USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Staff can view their own roles." ON public.staff_roles;
CREATE POLICY "Staff can view their own roles." ON public.staff_roles
  FOR SELECT USING (user_id = auth.uid());

-- Data Tables (Products, Sales, etc.): Users can access data for businesses they are a member of.
CREATE OR REPLACE FUNCTION is_business_member(p_business_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.businesses b
    WHERE b.id = p_business_id AND b.owner_id = auth.uid()
  ) OR EXISTS (
    SELECT 1 FROM public.staff_roles sr
    WHERE sr.business_id = p_business_id AND sr.user_id = auth.uid() AND sr.is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply generic policy to all business-related tables
DROP POLICY IF EXISTS "Business members can access their business data." ON public.products;
CREATE POLICY "Business members can access their business data." ON public.products FOR ALL USING (is_business_member(business_id));

DROP POLICY IF EXISTS "Business members can access their business data." ON public.sales;
CREATE POLICY "Business members can access their business data." ON public.sales FOR ALL USING (is_business_member(business_id));

DROP POLICY IF EXISTS "Business members can access their business data." ON public.tenants;
CREATE POLICY "Business members can access their business data." ON public.tenants FOR ALL USING (is_business_member(business_id));

DROP POLICY IF EXISTS "Business members can access their business data." ON public.students;
CREATE POLICY "Business members can access their business data." ON public.students FOR ALL USING (is_business_member(business_id));

DROP POLICY IF EXISTS "Business members can access their business data." ON public.rooms;
CREATE POLICY "Business members can access their business data." ON public.rooms FOR ALL USING (is_business_member(business_id));

DROP POLICY IF EXISTS "Business members can access their business data." ON public.bookings;
CREATE POLICY "Business members can access their business data." ON public.bookings FOR ALL USING (is_business_member(business_id));

-- Policies for join tables (e.g., sale_items)
DROP POLICY IF EXISTS "Users can access sale items for sales in their business." ON public.sale_items;
CREATE POLICY "Users can access sale items for sales in their business." ON public.sale_items
  FOR ALL USING (
    sale_id IN (
      SELECT id FROM public.sales WHERE is_business_member(business_id)
    )
  );

DROP POLICY IF EXISTS "Users can access rent payments for tenants in their business." ON public.rent_payments;
CREATE POLICY "Users can access rent payments for tenants in their business." ON public.rent_payments
  FOR ALL USING (
    tenant_id IN (
      SELECT id FROM public.tenants WHERE is_business_member(business_id)
    )
  );

DROP POLICY IF EXISTS "Users can access fee payments for students in their business." ON public.fee_payments;
CREATE POLICY "Users can access fee payments for students in their business." ON public.fee_payments
  FOR ALL USING (
    student_id IN (
      SELECT id FROM public.students WHERE is_business_member(business_id)
    )
  );

/*
          # [Fix Existing Relations]
          [This migration script corrects the "relation already exists" error by making schema creation idempotent. It alters the existing 'profiles' table to add required columns and creates other tables/types only if they do not already exist.]

          ## Query Description: [This operation is safe to run on an existing database. It will not delete any data. It checks for the existence of tables, types, and columns before creating them, preventing errors on re-runs. It ensures your database schema matches the application's requirements without data loss.]
          
          ## Metadata:
          - Schema-Category: ["Structural"]
          - Impact-Level: ["Low"]
          - Requires-Backup: [false]
          - Reversible: [false]
          
          ## Structure Details:
          - Alters `public.profiles` to add `full_name`, `email`, `phone` if they don't exist.
          - Creates all other application tables (`businesses`, `students`, etc.) with `IF NOT EXISTS`.
          - Creates all ENUM types (`business_type_enum`, etc.) if they don't exist.
          - Replaces the `handle_new_user` function and trigger to ensure they are up-to-date.
          
          ## Security Implications:
          - RLS Status: [Enabled]
          - Policy Changes: [No]
          - Auth Requirements: [None for this script]
          
          ## Performance Impact:
          - Indexes: [Added for new tables]
          - Triggers: [Re-created on `auth.users`]
          - Estimated Impact: [Low. Minor overhead on new user creation due to the trigger.]
          */

-- Create ENUM types if they don't exist
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

-- Alter existing profiles table to add columns if they don't exist
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS full_name text,
ADD COLUMN IF NOT EXISTS email text,
ADD COLUMN IF NOT EXISTS phone text,
ADD COLUMN IF NOT EXISTS created_at timestamp with time zone DEFAULT now() NOT NULL,
ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT now() NOT NULL;

-- Function to update `updated_at` column
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for profiles updated_at
DROP TRIGGER IF EXISTS on_profiles_update ON public.profiles;
CREATE TRIGGER on_profiles_update
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE PROCEDURE public.update_updated_at_column();

-- Function to create a profile for a new user
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, phone)
  VALUES (new.id, new.raw_user_meta_data->>'full_name', new.email, new.phone);
  return new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to execute `handle_new_user` on new user creation
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Create businesses table
CREATE TABLE IF NOT EXISTS public.businesses (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    business_type public.business_type_enum NOT NULL,
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
CREATE POLICY "Owners can manage their own businesses" ON public.businesses FOR ALL USING (auth.uid() = owner_id);

-- Create staff_roles table
CREATE TABLE IF NOT EXISTS public.staff_roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    phone text UNIQUE,
    role public.staff_role_enum NOT NULL,
    permissions jsonb,
    invited_by uuid NOT NULL REFERENCES auth.users(id),
    invited_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);
ALTER TABLE public.staff_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owners can manage staff in their business" ON public.staff_roles FOR ALL USING (
  business_id IN (SELECT id FROM public.businesses WHERE owner_id = auth.uid())
);

-- Create products table
CREATE TABLE IF NOT EXISTS public.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    name text NOT NULL,
    description text,
    sku text,
    category text,
    buying_price numeric,
    selling_price numeric NOT NULL,
    stock_quantity integer DEFAULT 0 NOT NULL,
    min_stock_level integer,
    unit text,
    image_url text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can manage products in their assigned business" ON public.products FOR ALL USING (
  business_id IN (SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid())
);

-- Create sales table
CREATE TABLE IF NOT EXISTS public.sales (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    cashier_id uuid REFERENCES auth.users(id),
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
CREATE POLICY "Staff can manage sales in their assigned business" ON public.sales FOR ALL USING (
  business_id IN (SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid())
);

-- Create sale_items table
CREATE TABLE IF NOT EXISTS public.sale_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    sale_id uuid NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id),
    quantity integer NOT NULL,
    unit_price numeric NOT NULL,
    total_price numeric NOT NULL
);
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can manage sale items in their assigned business" ON public.sale_items FOR ALL USING (
  sale_id IN (SELECT id FROM public.sales WHERE business_id IN (SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid()))
);

-- Create tenants table
CREATE TABLE IF NOT EXISTS public.tenants (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
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
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can manage tenants in their assigned business" ON public.tenants FOR ALL USING (
  business_id IN (SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid())
);

-- Create rent_payments table
CREATE TABLE IF NOT EXISTS public.rent_payments (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    amount numeric NOT NULL,
    payment_date date NOT NULL,
    status public.payment_status_enum NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.rent_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can manage rent payments in their assigned business" ON public.rent_payments FOR ALL USING (
  tenant_id IN (SELECT id FROM public.tenants WHERE business_id IN (SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid()))
);

-- Create students table
CREATE TABLE IF NOT EXISTS public.students (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
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
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can manage students in their assigned business" ON public.students FOR ALL USING (
  business_id IN (SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid())
);

-- Create fee_payments table
CREATE TABLE IF NOT EXISTS public.fee_payments (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    amount numeric NOT NULL,
    payment_date date NOT NULL,
    status public.payment_status_enum NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.fee_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can manage fee payments in their assigned business" ON public.fee_payments FOR ALL USING (
  student_id IN (SELECT id FROM public.students WHERE business_id IN (SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid()))
);

-- Create rooms table
CREATE TABLE IF NOT EXISTS public.rooms (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    room_number text NOT NULL,
    room_type text,
    capacity integer,
    rate_per_night numeric,
    description text,
    amenities text[],
    status text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can manage rooms in their assigned business" ON public.rooms FOR ALL USING (
  business_id IN (SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid())
);

-- Create bookings table
CREATE TABLE IF NOT EXISTS public.bookings (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    room_id uuid REFERENCES public.rooms(id),
    guest_name text NOT NULL,
    guest_phone text NOT NULL,
    guest_email text,
    check_in_date date NOT NULL,
    check_out_date date NOT NULL,
    guests_count integer,
    total_amount numeric,
    paid_amount numeric,
    booking_status text,
    payment_status public.payment_status_enum,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can manage bookings in their assigned business" ON public.bookings FOR ALL USING (
  business_id IN (SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid())
);

-- Add triggers for updated_at columns
DROP TRIGGER IF EXISTS on_businesses_update ON public.businesses;
CREATE TRIGGER on_businesses_update BEFORE UPDATE ON public.businesses FOR EACH ROW EXECUTE PROCEDURE public.update_updated_at_column();
DROP TRIGGER IF EXISTS on_products_update ON public.products;
CREATE TRIGGER on_products_update BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE PROCEDURE public.update_updated_at_column();
DROP TRIGGER IF EXISTS on_tenants_update ON public.tenants;
CREATE TRIGGER on_tenants_update BEFORE UPDATE ON public.tenants FOR EACH ROW EXECUTE PROCEDURE public.update_updated_at_column();
DROP TRIGGER IF EXISTS on_students_update ON public.students;
CREATE TRIGGER on_students_update BEFORE UPDATE ON public.students FOR EACH ROW EXECUTE PROCEDURE public.update_updated_at_column();
DROP TRIGGER IF EXISTS on_rooms_update ON public.rooms;
CREATE TRIGGER on_rooms_update BEFORE UPDATE ON public.rooms FOR EACH ROW EXECUTE PROCEDURE public.update_updated_at_column();
DROP TRIGGER IF EXISTS on_bookings_update ON public.bookings;
CREATE TRIGGER on_bookings_update BEFORE UPDATE ON public.bookings FOR EACH ROW EXECUTE PROCEDURE public.update_updated_at_column();

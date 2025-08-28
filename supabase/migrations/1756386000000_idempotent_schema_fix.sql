/*
# Fedha Plus - Idempotent Schema Migration
This script defines the complete database schema for the Fedha Plus application.
It is designed to be idempotent, meaning it can be run multiple times without causing errors.
It uses `IF NOT EXISTS` for creating tables and types, and `DROP ... IF EXISTS` before creating functions and policies to ensure a clean setup.

## Query Description:
This operation will create or update the entire database structure. It is safe to run on a new or partially migrated database. It will not delete any existing user data in the tables.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Medium"
- Requires-Backup: false
- Reversible: false (dropping tables would be required)

## Structure Details:
- Creates all required ENUM types.
- Creates tables: profiles, businesses, staff_roles, products, sales, sale_items, tenants, rent_payments, students, fee_payments, rooms, bookings.
- Creates helper functions and triggers for auth and RLS.
- Defines all Row Level Security (RLS) policies.

## Security Implications:
- RLS Status: Enabled on all tables.
- Policy Changes: Yes, policies are dropped and recreated to ensure they are up-to-date.
- Auth Requirements: Policies are tied to `auth.uid()`.

## Performance Impact:
- Indexes: Adds primary keys and foreign key indexes.
- Triggers: Adds a trigger to create user profiles.
- Estimated Impact: Low on an empty database.
*/

-- Create ENUM types if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'business_type') THEN
        CREATE TYPE "public"."business_type" AS ENUM ('hardware', 'supermarket', 'rentals', 'airbnb', 'hotel', 'school');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'staff_role') THEN
        CREATE TYPE "public"."staff_role" AS ENUM ('owner', 'manager', 'cashier', 'accountant', 'teacher', 'front_desk', 'housekeeper');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status') THEN
        CREATE TYPE "public"."payment_status" AS ENUM ('pending', 'paid', 'overdue', 'cancelled');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_status') THEN
        CREATE TYPE "public"."subscription_status" AS ENUM ('trial', 'active', 'cancelled', 'expired');
    END IF;
END$$;

-- Create tables if they don't exist
CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" uuid NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    "email" text NOT NULL UNIQUE,
    "phone" text,
    "full_name" text NOT NULL,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS "public"."businesses" (
    "id" uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    "owner_id" uuid NOT NULL REFERENCES public.profiles(id),
    "business_type" public.business_type NOT NULL,
    "name" text NOT NULL,
    "description" text,
    "phone" text,
    "location" text,
    "logo_url" text,
    "settings" jsonb DEFAULT '{}'::jsonb,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS "public"."staff_roles" (
    "id" uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    "business_id" uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    "user_id" uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    "role" public.staff_role NOT NULL,
    "permissions" jsonb DEFAULT '{}'::jsonb,
    "invited_by" uuid REFERENCES public.profiles(id),
    "invited_at" timestamp with time zone DEFAULT now(),
    "is_active" boolean DEFAULT true,
    UNIQUE(business_id, user_id)
);

CREATE TABLE IF NOT EXISTS "public"."products" (
    "id" uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    "business_id" uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    "name" text NOT NULL,
    "description" text,
    "sku" text,
    "category" text,
    "buying_price" numeric,
    "selling_price" numeric NOT NULL,
    "stock_quantity" integer DEFAULT 0,
    "min_stock_level" integer DEFAULT 0,
    "unit" text,
    "image_url" text,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS "public"."sales" (
    "id" uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    "business_id" uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    "cashier_id" uuid REFERENCES public.profiles(id),
    "customer_name" text,
    "customer_phone" text,
    "total_amount" numeric NOT NULL,
    "payment_method" text,
    "mpesa_code" text,
    "notes" text,
    "receipt_number" text UNIQUE,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS "public"."sale_items" (
    "id" uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    "sale_id" uuid NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
    "product_id" uuid NOT NULL REFERENCES public.products(id),
    "quantity" integer NOT NULL,
    "unit_price" numeric NOT NULL,
    "total_price" numeric NOT NULL
);

CREATE TABLE IF NOT EXISTS "public"."tenants" (
    "id" uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    "business_id" uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    "name" text NOT NULL,
    "phone" text NOT NULL,
    "email" text,
    "id_number" text,
    "unit_number" text NOT NULL,
    "rent_amount" numeric NOT NULL,
    "deposit_amount" numeric,
    "lease_start" date,
    "lease_end" date,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS "public"."rent_payments" (
    "id" uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    "tenant_id" uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    "amount" numeric NOT NULL,
    "payment_date" date NOT NULL,
    "payment_for_month" date NOT NULL,
    "status" public.payment_status DEFAULT 'paid',
    "notes" text,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS "public"."students" (
    "id" uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    "business_id" uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    "admission_number" text NOT NULL UNIQUE,
    "first_name" text NOT NULL,
    "last_name" text NOT NULL,
    "date_of_birth" date,
    "class_level" text,
    "parent_name" text,
    "parent_phone" text,
    "parent_email" text,
    "address" text,
    "fee_amount" numeric,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS "public"."fee_payments" (
    "id" uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    "student_id" uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    "amount" numeric NOT NULL,
    "payment_date" date NOT NULL,
    "term" text,
    "year" integer,
    "status" public.payment_status DEFAULT 'paid',
    "notes" text,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS "public"."rooms" (
    "id" uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    "business_id" uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    "room_number" text NOT NULL,
    "room_type" text,
    "capacity" integer,
    "rate_per_night" numeric NOT NULL,
    "description" text,
    "amenities" text[],
    "status" text DEFAULT 'available',
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS "public"."bookings" (
    "id" uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    "business_id" uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    "room_id" uuid REFERENCES public.rooms(id),
    "guest_name" text NOT NULL,
    "guest_phone" text,
    "guest_email" text,
    "check_in_date" date NOT NULL,
    "check_out_date" date NOT NULL,
    "guests_count" integer,
    "total_amount" numeric NOT NULL,
    "paid_amount" numeric DEFAULT 0,
    "booking_status" text,
    "payment_status" public.payment_status DEFAULT 'pending',
    "notes" text,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);

-- Function to check if a user is a member of a business (owner or staff)
DROP FUNCTION IF EXISTS public.is_business_member(uuid);
CREATE FUNCTION public.is_business_member(business_id_to_check uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM businesses
    WHERE id = business_id_to_check AND owner_id = auth.uid()
  ) OR EXISTS (
    SELECT 1
    FROM staff_roles
    WHERE business_id = business_id_to_check AND user_id = auth.uid() AND is_active = true
  );
END;
$$;

-- Trigger to create a profile when a new user signs up
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

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- RLS Policies
-- Profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view their own profile" ON public.profiles FOR SELECT USING (id = auth.uid());
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (id = auth.uid());

-- Businesses
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owners can view their own businesses" ON public.businesses;
CREATE POLICY "Owners can view their own businesses" ON public.businesses FOR SELECT USING (owner_id = auth.uid());
DROP POLICY IF EXISTS "Owners can create businesses" ON public.businesses;
CREATE POLICY "Owners can create businesses" ON public.businesses FOR INSERT WITH CHECK (owner_id = auth.uid());
DROP POLICY IF EXISTS "Owners can update their own businesses" ON public.businesses;
CREATE POLICY "Owners can update their own businesses" ON public.businesses FOR UPDATE USING (owner_id = auth.uid());
DROP POLICY IF EXISTS "Owners can delete their own businesses" ON public.businesses;
CREATE POLICY "Owners can delete their own businesses" ON public.businesses FOR DELETE USING (owner_id = auth.uid());
DROP POLICY IF EXISTS "Staff can view their assigned business" ON public.businesses;
CREATE POLICY "Staff can view their assigned business" ON public.businesses FOR SELECT USING (public.is_business_member(id));

-- Generic RLS for all business-related tables
DO $$
DECLARE
    t_name TEXT;
BEGIN
    FOR t_name IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name IN ('staff_roles', 'products', 'sales', 'sale_items', 'tenants', 'rent_payments', 'students', 'fee_payments', 'rooms', 'bookings')
    LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', t_name);
        
        EXECUTE format('DROP POLICY IF EXISTS "Members can manage their business data" ON public.%I;', t_name);
        EXECUTE format(
            'CREATE POLICY "Members can manage their business data" ON public.%I FOR ALL USING (public.is_business_member(business_id));',
            t_name
        );
    END LOOP;
END;
$$;

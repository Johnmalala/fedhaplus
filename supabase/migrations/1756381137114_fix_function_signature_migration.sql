-- Fedha Plus SaaS :: Full Database Schema
-- This script is idempotent and can be run multiple times safely.

/*
  # [Enum Type] Business Type
  Defines the types of businesses supported by the platform.

  ## Metadata:
  - Schema-Category: "Structural"
  - Impact-Level: "Low"
  - Reversible: false
*/
CREATE TYPE "public"."business_type" AS ENUM (
  'hardware',
  'supermarket',
  'rentals',
  'airbnb',
  'hotel',
  'school'
);

/*
  # [Enum Type] Staff Role
  Defines the roles a staff member can have within a business.

  ## Metadata:
  - Schema-Category: "Structural"
  - Impact-Level: "Low"
  - Reversible: false
*/
CREATE TYPE "public"."staff_role" AS ENUM (
  'owner',
  'manager',
  'cashier',
  'accountant',
  'teacher',
  'front_desk',
  'housekeeper'
);

/*
  # [Enum Type] Payment Status
  Defines the status of a payment.

  ## Metadata:
  - Schema-Category: "Structural"
  - Impact-Level: "Low"
  - Reversible: false
*/
CREATE TYPE "public"."payment_status" AS ENUM (
  'pending',
  'paid',
  'overdue',
  'cancelled'
);

/*
  # [Enum Type] Subscription Status
  Defines the status of a business subscription.

  ## Metadata:
  - Schema-Category: "Structural"
  - Impact-Level: "Low"
  - Reversible: false
*/
CREATE TYPE "public"."subscription_status" AS ENUM (
  'trial',
  'active',
  'cancelled',
  'expired'
);

/*
  # [Table] Profiles
  Stores public user information, linked to Supabase Auth.

  ## Query Description: This operation creates the user profiles table if it doesn't exist. It's safe to run as it won't affect existing data.
  ## Metadata:
  - Schema-Category: "Structural"
  - Impact-Level: "Low"
  - Requires-Backup: false
  - Reversible: true
*/
CREATE TABLE IF NOT EXISTS "public"."profiles" (
  "id" uuid NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  "email" text UNIQUE,
  "phone" text UNIQUE,
  "full_name" text NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public profiles are viewable by everyone." ON profiles FOR SELECT USING (true);
CREATE POLICY "Users can insert their own profile." ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update their own profile." ON profiles FOR UPDATE USING (auth.uid() = id);

/*
  # [Function] Handle New User
  Creates a profile entry for a new user in Supabase Auth.

  ## Query Description: This function automatically creates a user profile upon successful signup. It's a core part of the authentication flow.
  ## Metadata:
  - Schema-Category: "Structural"
  - Impact-Level: "Low"
  - Requires-Backup: false
  - Reversible: true
*/
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email)
  VALUES (new.id, new.raw_user_meta_data->>'full_name', new.email);
  RETURN new;
END;
$$;

/*
  # [Trigger] On Auth User Created
  Executes the handle_new_user function after a new user is created.

  ## Query Description: This trigger connects the authentication system to the profiles table.
  ## Metadata:
  - Schema-Category: "Structural"
  - Impact-Level: "Low"
  - Requires-Backup: false
  - Reversible: true
*/
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

/*
  # [Table] Businesses
  Stores information about each business created on the platform.

  ## Query Description: Creates the main businesses table. RLS is enabled to ensure owners can only access their own businesses.
  ## Metadata:
  - Schema-Category: "Structural"
  - Impact-Level: "Medium"
  - Requires-Backup: false
  - Reversible: true
*/
CREATE TABLE IF NOT EXISTS "public"."businesses" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  "owner_id" uuid NOT NULL REFERENCES public.profiles(id),
  "business_type" public.business_type NOT NULL,
  "name" text NOT NULL,
  "description" text,
  "phone" text,
  "location" text,
  "logo_url" text,
  "settings" jsonb DEFAULT '{}'::jsonb,
  "subscription_status" public.subscription_status DEFAULT 'trial',
  "trial_ends_at" timestamp with time zone DEFAULT now() + interval '30 days',
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE "public"."businesses" ENABLE ROW LEVEL SECURITY;

/*
  # [Table] Staff Roles
  Manages staff members and their roles for each business.

  ## Query Description: Creates the staff roles table for RBAC. RLS ensures data is segregated.
  ## Metadata:
  - Schema-Category: "Structural"
  - Impact-Level: "Medium"
  - Requires-Backup: false
  - Reversible: true
*/
CREATE TABLE IF NOT EXISTS "public"."staff_roles" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  "business_id" uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  "user_id" uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  "role" public.staff_role NOT NULL,
  "permissions" jsonb DEFAULT '{}'::jsonb,
  "invited_by" uuid REFERENCES public.profiles(id),
  "invited_at" timestamp with time zone DEFAULT now(),
  "is_active" boolean DEFAULT true,
  UNIQUE(business_id, user_id)
);
ALTER TABLE "public"."staff_roles" ENABLE ROW LEVEL SECURITY;

-- FIX: Drop the function if it exists to prevent signature conflicts.
DROP FUNCTION IF EXISTS public.is_business_member(uuid);

/*
  # [Function] Is Business Member
  Checks if the current user is an owner or active staff of a business.

  ## Query Description: This security function is critical for RLS policies to determine data access rights.
  ## Metadata:
  - Schema-Category: "Security"
  - Impact-Level: "High"
  - Requires-Backup: false
  - Reversible: true
*/
CREATE OR REPLACE FUNCTION public.is_business_member(business_id_to_check uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- For owners, check if they own the business
  IF EXISTS (
    SELECT 1
    FROM businesses
    WHERE id = business_id_to_check AND owner_id = auth.uid()
  ) THEN
    RETURN true;
  END IF;

  -- For staff, check if they are a member of the business
  IF EXISTS (
    SELECT 1
    FROM staff_roles
    WHERE business_id = business_id_to_check AND user_id = auth.uid() AND is_active = true
  ) THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;

-- RLS Policies for Businesses and Staff
CREATE POLICY "Owners can manage their own businesses." ON businesses
  FOR ALL USING (owner_id = auth.uid());
  
CREATE POLICY "Staff can view the business they belong to." ON businesses
  FOR SELECT USING (is_business_member(id));

CREATE POLICY "Owners can manage staff in their businesses." ON staff_roles
  FOR ALL USING (is_business_member(business_id));

CREATE POLICY "Staff can view their own role." ON staff_roles
  FOR SELECT USING (user_id = auth.uid());


-- Module-specific tables with RLS

/*
  # [Table] Products
  For Hardware & Supermarket modules.
*/
CREATE TABLE IF NOT EXISTS "public"."products" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
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
ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Business members can manage products." ON products FOR ALL USING (is_business_member(business_id));

/*
  # [Table] Sales
  For Hardware & Supermarket modules.
*/
CREATE TABLE IF NOT EXISTS "public"."sales" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  "business_id" uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  "cashier_id" uuid REFERENCES public.profiles(id),
  "customer_name" text,
  "customer_phone" text,
  "total_amount" numeric NOT NULL,
  "payment_method" text,
  "mpesa_code" text,
  "notes" text,
  "receipt_number" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE "public"."sales" ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Business members can manage sales." ON sales FOR ALL USING (is_business_member(business_id));

/*
  # [Table] Sale Items
  Line items for each sale.
*/
CREATE TABLE IF NOT EXISTS "public"."sale_items" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  "sale_id" uuid NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
  "product_id" uuid NOT NULL REFERENCES public.products(id),
  "quantity" integer NOT NULL,
  "unit_price" numeric NOT NULL,
  "total_price" numeric NOT NULL
);
-- RLS is inherited from the sales table via foreign key.

/*
  # [Table] Tenants
  For Apartment Rentals module.
*/
CREATE TABLE IF NOT EXISTS "public"."tenants" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  "business_id" uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  "name" text NOT NULL,
  "phone" text,
  "email" text,
  "id_number" text,
  "unit_number" text,
  "rent_amount" numeric,
  "deposit_amount" numeric,
  "lease_start" date,
  "lease_end" date,
  "is_active" boolean DEFAULT true,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE "public"."tenants" ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Business members can manage tenants." ON tenants FOR ALL USING (is_business_member(business_id));

/*
  # [Table] Rent Payments
  For Apartment Rentals module.
*/
CREATE TABLE IF NOT EXISTS "public"."rent_payments" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  "tenant_id" uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  "amount" numeric NOT NULL,
  "payment_date" date NOT NULL,
  "payment_for_month" date NOT NULL,
  "status" public.payment_status DEFAULT 'paid',
  "notes" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL
);
-- RLS is inherited from the tenants table.

/*
  # [Table] Students
  For School Management module.
*/
CREATE TABLE IF NOT EXISTS "public"."students" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  "business_id" uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  "admission_number" text UNIQUE,
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
ALTER TABLE "public"."students" ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Business members can manage students." ON students FOR ALL USING (is_business_member(business_id));

/*
  # [Table] Fee Payments
  For School Management module.
*/
CREATE TABLE IF NOT EXISTS "public"."fee_payments" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  "student_id" uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  "amount" numeric NOT NULL,
  "payment_date" date NOT NULL,
  "term" text,
  "status" public.payment_status DEFAULT 'paid',
  "notes" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL
);
-- RLS is inherited from the students table.

/*
  # [Table] Rooms
  For Hotel & Airbnb modules.
*/
CREATE TABLE IF NOT EXISTS "public"."rooms" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  "business_id" uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  "room_number" text,
  "room_type" text,
  "capacity" integer,
  "rate_per_night" numeric,
  "description" text,
  "amenities" text[],
  "status" text,
  "is_active" boolean DEFAULT true,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE "public"."rooms" ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Business members can manage rooms." ON rooms FOR ALL USING (is_business_member(business_id));

/*
  # [Table] Bookings
  For Hotel & Airbnb modules.
*/
CREATE TABLE IF NOT EXISTS "public"."bookings" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  "business_id" uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  "room_id" uuid REFERENCES public.rooms(id),
  "guest_name" text,
  "guest_phone" text,
  "guest_email" text,
  "check_in_date" date,
  "check_out_date" date,
  "guests_count" integer,
  "total_amount" numeric,
  "paid_amount" numeric,
  "booking_status" text,
  "payment_status" public.payment_status,
  "notes" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE "public"."bookings" ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Business members can manage bookings." ON bookings FOR ALL USING (is_business_member(business_id));

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_businesses_owner_id ON public.businesses(owner_id);
CREATE INDEX IF NOT EXISTS idx_staff_roles_business_id ON public.staff_roles(business_id);
CREATE INDEX IF NOT EXISTS idx_staff_roles_user_id ON public.staff_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_products_business_id ON public.products(business_id);
CREATE INDEX IF NOT EXISTS idx_sales_business_id ON public.sales(business_id);
CREATE INDEX IF NOT EXISTS idx_tenants_business_id ON public.tenants(business_id);
CREATE INDEX IF NOT EXISTS idx_students_business_id ON public.students(business_id);
CREATE INDEX IF NOT EXISTS idx_rooms_business_id ON public.rooms(business_id);
CREATE INDEX IF NOT EXISTS idx_bookings_business_id ON public.bookings(business_id);

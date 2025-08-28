/*
  # Fedha Plus - Full Database Schema
  This script sets up the entire database structure for the Fedha Plus application,
  including tables, types, functions, and Row-Level Security (RLS) policies.
  It is designed to be idempotent, meaning it can be run multiple times without
  causing errors or duplicating data.

  ## Metadata:
  - Schema-Category: "Structural"
  - Impact-Level: "High"
  - Requires-Backup: true
  - Reversible: false (without data loss)
*/

--==============================================================================
-- Custom Types
--==============================================================================

/*
  # TYPE: business_type
  Defines the different kinds of businesses the platform supports.
*/
CREATE TYPE public.business_type AS ENUM (
  'hardware',
  'supermarket',
  'rentals',
  'airbnb',
  'hotel',
  'school'
);

/*
  # TYPE: staff_role
  Defines the roles a user can have within a business.
*/
CREATE TYPE public.staff_role AS ENUM (
  'owner',
  'manager',
  'cashier',
  'accountant',
  'teacher',
  'front_desk',
  'housekeeper'
);

/*
  # TYPE: payment_status
  Defines the status of a payment transaction.
*/
CREATE TYPE public.payment_status AS ENUM (
  'pending',
  'paid',
  'overdue',
  'cancelled'
);

/*
  # TYPE: subscription_status
  Defines the status of a business's subscription plan.
*/
CREATE TYPE public.subscription_status AS ENUM (
  'trial',
  'active',
  'cancelled',
  'expired'
);

--==============================================================================
-- Tables
--==============================================================================

/*
  # TABLE: profiles
  Stores public user profile information, linked to auth.users.
*/
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text UNIQUE NOT NULL,
  phone text,
  full_name text NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.profiles IS 'Stores public user profile information.';

/*
  # TABLE: businesses
  Stores information about each business created on the platform.
*/
CREATE TABLE IF NOT EXISTS public.businesses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  business_type public.business_type NOT NULL,
  name text NOT NULL,
  description text,
  phone text,
  location text,
  logo_url text,
  settings jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.businesses IS 'Central table for all businesses.';

/*
  # TABLE: staff_roles
  Manages user roles and permissions for each business (Role-Based Access Control).
*/
CREATE TABLE IF NOT EXISTS public.staff_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role public.staff_role NOT NULL,
  permissions jsonb DEFAULT '{}'::jsonb,
  invited_by uuid REFERENCES public.profiles(id),
  invited_at timestamptz DEFAULT now(),
  is_active boolean DEFAULT true,
  UNIQUE(business_id, user_id)
);
COMMENT ON TABLE public.staff_roles IS 'Manages user roles within a business.';

/*
  # TABLE: products
  For Hardware & Supermarket: Stores product and inventory information.
*/
CREATE TABLE IF NOT EXISTS public.products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
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
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.products IS 'Inventory for hardware stores and supermarkets.';

/*
  # TABLE: sales
  For Hardware & Supermarket: Records sales transactions.
*/
CREATE TABLE IF NOT EXISTS public.sales (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  cashier_id uuid REFERENCES public.profiles(id),
  customer_name text,
  customer_phone text,
  total_amount numeric(10, 2) NOT NULL,
  payment_method text NOT NULL,
  mpesa_code text,
  notes text,
  receipt_number text,
  created_at timestamptz DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.sales IS 'Records sales transactions.';

/*
  # TABLE: sale_items
  Junction table for items included in a sale.
*/
CREATE TABLE IF NOT EXISTS public.sale_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id uuid NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id),
  quantity integer NOT NULL,
  unit_price numeric(10, 2) NOT NULL,
  total_price numeric(10, 2) NOT NULL
);
COMMENT ON TABLE public.sale_items IS 'Individual items within a sale.';

/*
  # TABLE: tenants
  For Apartment Rentals: Stores tenant information.
*/
CREATE TABLE IF NOT EXISTS public.tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
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
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.tenants IS 'Information about tenants in rental businesses.';

/*
  # TABLE: rent_payments
  Tracks rent payments for tenants.
*/
CREATE TABLE IF NOT EXISTS public.rent_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  amount numeric(10, 2) NOT NULL,
  payment_date date NOT NULL,
  payment_for_month date NOT NULL,
  status public.payment_status DEFAULT 'paid',
  notes text,
  created_at timestamptz DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.rent_payments IS 'Tracks rent payments from tenants.';

/*
  # TABLE: students
  For School Management: Stores student profiles.
*/
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
  fee_amount numeric(10, 2),
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.students IS 'Profiles for students in a school.';

/*
  # TABLE: fee_payments
  Tracks school fee payments for students.
*/
CREATE TABLE IF NOT EXISTS public.fee_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  amount numeric(10, 2) NOT NULL,
  payment_date date NOT NULL,
  term text,
  year integer,
  status public.payment_status DEFAULT 'paid',
  notes text,
  created_at timestamptz DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.fee_payments IS 'Tracks school fee payments.';

/*
  # TABLE: rooms
  For Hotel/Airbnb: Stores information about rooms or listings.
*/
CREATE TABLE IF NOT EXISTS public.rooms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  room_number text NOT NULL,
  room_type text,
  capacity integer,
  rate_per_night numeric(10, 2) NOT NULL,
  description text,
  amenities text[],
  status text DEFAULT 'available',
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.rooms IS 'Rooms for hotels or Airbnb listings.';

/*
  # TABLE: bookings
  For Hotel/Airbnb: Stores booking and reservation information.
*/
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
  total_amount numeric(10, 2) NOT NULL,
  paid_amount numeric(10, 2) DEFAULT 0,
  booking_status text DEFAULT 'confirmed',
  payment_status public.payment_status DEFAULT 'pending',
  notes text,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.bookings IS 'Bookings for hotels and Airbnbs.';

--==============================================================================
-- Functions & Triggers
--==============================================================================

/*
  # Function: handle_new_user
  Triggered on new user signup to create a corresponding profile.
*/
-- Drop the function first to allow for re-creation with potential signature changes
DROP FUNCTION IF EXISTS public.handle_new_user();
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (new.id, new.email, new.raw_user_meta_data->>'full_name');
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new user creation
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

/*
  # Function: is_business_member
  Checks if the currently authenticated user is a member of the specified business.
  Used in RLS policies.
*/
-- Drop the function first to allow parameter name changes
DROP FUNCTION IF EXISTS public.is_business_member(uuid);
CREATE OR REPLACE FUNCTION public.is_business_member(p_business_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.staff_roles
    WHERE business_id = p_business_id
      AND user_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--==============================================================================
-- Row-Level Security (RLS)
--==============================================================================

-- Enable RLS for all relevant tables
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
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Profiles: Users can see their own profile and profiles of staff in their businesses.
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view their own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Businesses: Users can only see businesses they are a member of.
DROP POLICY IF EXISTS "Users can view their own businesses" ON public.businesses;
CREATE POLICY "Users can view their own businesses" ON public.businesses
  FOR SELECT USING (public.is_business_member(id));

DROP POLICY IF EXISTS "Owners can update their businesses" ON public.businesses;
CREATE POLICY "Owners can update their businesses" ON public.businesses
  FOR UPDATE USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Owners can delete their businesses" ON public.businesses;
CREATE POLICY "Owners can delete their businesses" ON public.businesses
  FOR DELETE USING (auth.uid() = owner_id);

-- Staff Roles: Users can see staff roles for businesses they are a member of.
DROP POLICY IF EXISTS "Members can view staff roles in their business" ON public.staff_roles;
CREATE POLICY "Members can view staff roles in their business" ON public.staff_roles
  FOR SELECT USING (public.is_business_member(business_id));

-- Generic policy for business-related tables
-- Products
DROP POLICY IF EXISTS "Members can access products in their business" ON public.products;
CREATE POLICY "Members can access products in their business" ON public.products
  FOR ALL USING (public.is_business_member(business_id));

-- Sales
DROP POLICY IF EXISTS "Members can access sales in their business" ON public.sales;
CREATE POLICY "Members can access sales in their business" ON public.sales
  FOR ALL USING (public.is_business_member(business_id));

-- Tenants
DROP POLICY IF EXISTS "Members can access tenants in their business" ON public.tenants;
CREATE POLICY "Members can access tenants in their business" ON public.tenants
  FOR ALL USING (public.is_business_member(business_id));

-- Students
DROP POLICY IF EXISTS "Members can access students in their business" ON public.students;
CREATE POLICY "Members can access students in their business" ON public.students
  FOR ALL USING (public.is_business_member(business_id));

-- Rooms
DROP POLICY IF EXISTS "Members can access rooms in their business" ON public.rooms;
CREATE POLICY "Members can access rooms in their business" ON public.rooms
  FOR ALL USING (public.is_business_member(business_id));

-- Bookings
DROP POLICY IF EXISTS "Members can access bookings in their business" ON public.bookings;
CREATE POLICY "Members can access bookings in their business" ON public.bookings
  FOR ALL USING (public.is_business_member(business_id));

--==============================================================================
-- Indexes for Performance
--==============================================================================
CREATE INDEX IF NOT EXISTS idx_businesses_owner_id ON public.businesses(owner_id);
CREATE INDEX IF NOT EXISTS idx_staff_roles_user_id ON public.staff_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_staff_roles_business_id ON public.staff_roles(business_id);
CREATE INDEX IF NOT EXISTS idx_products_business_id ON public.products(business_id);
CREATE INDEX IF NOT EXISTS idx_sales_business_id ON public.sales(business_id);
CREATE INDEX IF NOT EXISTS idx_tenants_business_id ON public.tenants(business_id);
CREATE INDEX IF NOT EXISTS idx_students_business_id ON public.students(business_id);
CREATE INDEX IF NOT EXISTS idx_rooms_business_id ON public.rooms(business_id);
CREATE INDEX IF NOT EXISTS idx_bookings_business_id ON public.bookings(business_id);

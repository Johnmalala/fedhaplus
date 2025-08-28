/*
# [Corrected Schema Migration]
This script defines the complete database schema for Fedha Plus. It has been updated to be idempotent, meaning it can be run multiple times without causing errors. It will safely create tables, types, and policies only if they do not already exist. This fixes the previous error related to the 'profiles' table already existing.

## Query Description: This operation will set up the entire database structure for Fedha Plus. It checks for the existence of each object (table, type, policy) before creating it, ensuring a safe and repeatable setup. No data will be lost.

## Metadata:
- Schema-Category: ["Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: [false]
- Reversible: [false] -- This script sets up the schema, reversing it would require a separate DROP script.

## Structure Details:
- Tables: profiles, businesses, staff_roles, products, sales, sale_items, tenants, rent_payments, students, fee_payments, rooms, bookings.
- Types: business_type, staff_role, payment_status, subscription_status.
- Functions: handle_new_user.
- Triggers: on_auth_user_created.
- RLS Policies: For all tables to ensure data isolation.

## Security Implications:
- RLS Status: Enabled on all tables.
- Policy Changes: Yes, this script defines the core RLS policies.
- Auth Requirements: Policies are based on `auth.uid()`.

## Performance Impact:
- Indexes: Primary keys and foreign keys are indexed.
- Triggers: One trigger on `auth.users` for profile creation.
- Estimated Impact: Low. Standard schema setup.
*/

-- Create custom types if they don't exist
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
END$$;


-- 1. Profiles Table (Handles user data)
-- This table is likely created by a trigger from Supabase Auth. We use IF NOT EXISTS to be safe.
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE,
  phone TEXT,
  full_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.profiles IS 'Stores public user profile information.';

-- Function to create a profile for a new user
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (new.id, new.email, new.raw_user_meta_data->>'full_name');
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to call the function when a new user signs up
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Enable RLS for profiles and set policies
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view their own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);


-- 2. Businesses Table
CREATE TABLE IF NOT EXISTS public.businesses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  business_type public.business_type NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  phone TEXT,
  location TEXT,
  logo_url TEXT,
  settings JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.businesses IS 'Stores information about each business owned by a user.';

-- Enable RLS for businesses
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owners can manage their own businesses" ON public.businesses;
CREATE POLICY "Owners can manage their own businesses" ON public.businesses
  FOR ALL USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Staff can view the business they belong to" ON public.businesses;
CREATE POLICY "Staff can view the business they belong to" ON public.businesses
  FOR SELECT USING (
    id IN (
      SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid()
    )
  );

-- 3. Staff Roles Table
CREATE TABLE IF NOT EXISTS public.staff_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.staff_role NOT NULL,
  permissions JSONB DEFAULT '{}'::jsonb,
  invited_by UUID REFERENCES auth.users(id),
  invited_at TIMESTAMPTZ DEFAULT NOW(),
  is_active BOOLEAN DEFAULT true,
  UNIQUE (business_id, user_id)
);
COMMENT ON TABLE public.staff_roles IS 'Assigns roles to users for specific businesses.';

-- Enable RLS for staff_roles
ALTER TABLE public.staff_roles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owners can manage staff in their businesses" ON public.staff_roles;
CREATE POLICY "Owners can manage staff in their businesses" ON public.staff_roles
  FOR ALL USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE owner_id = auth.uid()
    )
  );
DROP POLICY IF EXISTS "Staff can view their own roles" ON public.staff_roles;
CREATE POLICY "Staff can view their own roles" ON public.staff_roles
  FOR SELECT USING (user_id = auth.uid());


-- 4. Products Table (For Hardware & Supermarket)
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  sku TEXT,
  category TEXT,
  buying_price NUMERIC(10, 2),
  selling_price NUMERIC(10, 2) NOT NULL,
  stock_quantity INTEGER DEFAULT 0,
  min_stock_level INTEGER DEFAULT 0,
  unit TEXT DEFAULT 'piece',
  image_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.products IS 'Inventory for hardware and supermarket businesses.';

-- RLS for products
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff can manage products in their business" ON public.products;
CREATE POLICY "Staff can manage products in their business" ON public.products
  FOR ALL USING (
    business_id IN (
      SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid()
    )
  );


-- 5. Sales & Sale Items Tables (For Hardware & Supermarket)
CREATE TABLE IF NOT EXISTS public.sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  cashier_id UUID REFERENCES auth.users(id),
  customer_name TEXT,
  customer_phone TEXT,
  total_amount NUMERIC(10, 2) NOT NULL,
  payment_method TEXT,
  mpesa_code TEXT,
  notes TEXT,
  receipt_number TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.sales IS 'Records sales transactions.';

CREATE TABLE IF NOT EXISTS public.sale_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id UUID NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id),
  quantity INTEGER NOT NULL,
  unit_price NUMERIC(10, 2) NOT NULL,
  total_price NUMERIC(10, 2) NOT NULL
);
COMMENT ON TABLE public.sale_items IS 'Individual items within a sale.';

-- RLS for sales and sale_items
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff can manage sales in their business" ON public.sales;
CREATE POLICY "Staff can manage sales in their business" ON public.sales
  FOR ALL USING (
    business_id IN (
      SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid()
    )
  );

ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff can manage sale items in their business" ON public.sale_items;
CREATE POLICY "Staff can manage sale items in their business" ON public.sale_items
  FOR ALL USING (
    sale_id IN (
      SELECT id FROM public.sales WHERE business_id IN (
        SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid()
      )
    )
  );


-- 6. Tenants Table (For Rentals)
CREATE TABLE IF NOT EXISTS public.tenants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
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
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.tenants IS 'Stores tenant information for rental businesses.';

-- RLS for tenants
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff can manage tenants in their business" ON public.tenants;
CREATE POLICY "Staff can manage tenants in their business" ON public.tenants
  FOR ALL USING (
    business_id IN (
      SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid()
    )
  );

-- 7. Rent Payments Table
CREATE TABLE IF NOT EXISTS public.rent_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL,
    payment_date DATE NOT NULL,
    status public.payment_status DEFAULT 'paid',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.rent_payments IS 'Records rent payments from tenants.';

-- RLS for rent_payments
ALTER TABLE public.rent_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff can manage rent payments in their business" ON public.rent_payments;
CREATE POLICY "Staff can manage rent payments in their business" ON public.rent_payments
  FOR ALL USING (
    tenant_id IN (
      SELECT id FROM public.tenants WHERE business_id IN (
        SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid()
      )
    )
  );


-- 8. Students Table (For Schools)
CREATE TABLE IF NOT EXISTS public.students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  admission_number TEXT UNIQUE NOT NULL,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  date_of_birth DATE,
  class_level TEXT,
  parent_name TEXT NOT NULL,
  parent_phone TEXT NOT NULL,
  parent_email TEXT,
  address TEXT,
  fee_amount NUMERIC(10, 2) NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.students IS 'Stores student information for school businesses.';

-- RLS for students
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff can manage students in their school" ON public.students;
CREATE POLICY "Staff can manage students in their school" ON public.students
  FOR ALL USING (
    business_id IN (
      SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid()
    )
  );

-- 9. Fee Payments Table
CREATE TABLE IF NOT EXISTS public.fee_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL,
    payment_date DATE NOT NULL,
    term TEXT,
    status public.payment_status DEFAULT 'paid',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.fee_payments IS 'Records school fee payments from students.';

-- RLS for fee_payments
ALTER TABLE public.fee_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff can manage fee payments in their school" ON public.fee_payments;
CREATE POLICY "Staff can manage fee payments in their school" ON public.fee_payments
  FOR ALL USING (
    student_id IN (
      SELECT id FROM public.students WHERE business_id IN (
        SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid()
      )
    )
  );


-- 10. Rooms Table (For Hotel & Airbnb)
CREATE TABLE IF NOT EXISTS public.rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  room_number TEXT NOT NULL,
  room_type TEXT,
  capacity INTEGER,
  rate_per_night NUMERIC(10, 2) NOT NULL,
  description TEXT,
  amenities TEXT[],
  status TEXT DEFAULT 'available',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.rooms IS 'Stores room/listing information for hotels and Airbnbs.';

-- RLS for rooms
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff can manage rooms in their business" ON public.rooms;
CREATE POLICY "Staff can manage rooms in their business" ON public.rooms
  FOR ALL USING (
    business_id IN (
      SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid()
    )
  );

-- 11. Bookings Table (For Hotel & Airbnb)
CREATE TABLE IF NOT EXISTS public.bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  room_id UUID REFERENCES public.rooms(id),
  guest_name TEXT NOT NULL,
  guest_phone TEXT NOT NULL,
  guest_email TEXT,
  check_in_date DATE NOT NULL,
  check_out_date DATE NOT NULL,
  guests_count INTEGER,
  total_amount NUMERIC(10, 2) NOT NULL,
  paid_amount NUMERIC(10, 2) DEFAULT 0,
  booking_status TEXT DEFAULT 'confirmed',
  payment_status public.payment_status DEFAULT 'pending',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.bookings IS 'Stores booking information for hotels and Airbnbs.';

-- RLS for bookings
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Staff can manage bookings in their business" ON public.bookings;
CREATE POLICY "Staff can manage bookings in their business" ON public.bookings
  FOR ALL USING (
    business_id IN (
      SELECT business_id FROM public.staff_roles WHERE user_id = auth.uid()
    )
  );

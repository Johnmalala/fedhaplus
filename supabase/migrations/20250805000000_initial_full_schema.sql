-- Supabase migration to create the full schema for Fedha Plus

/*
# [Function] is_business_member
Checks if a user is a member of a specific business.

## Query Description:
This function is crucial for enforcing Row-Level Security (RLS) across the application. It verifies that a given user (by their UID) has an active role in a specified business. This prevents data leakage between different businesses on the platform. It is a foundational security utility.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Tables: public.staff_roles
- Columns: user_id, business_id, is_active

## Security Implications:
- RLS Status: This is a helper function for RLS policies.
- Policy Changes: No
- Auth Requirements: Requires a user's UID.

## Performance Impact:
- Indexes: An index on (business_id, user_id) on the staff_roles table is recommended.
- Estimated Impact: Low, as it's a simple lookup.
*/
CREATE OR REPLACE FUNCTION public.is_business_member(p_business_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.staff_roles sr
    WHERE sr.business_id = p_business_id
      AND sr.user_id = p_user_id
      AND sr.is_active = true
  );
END;
$$;


/*
# [Function] get_user_role
Retrieves the role of a user within a specific business.

## Query Description:
This function fetches the role (e.g., 'owner', 'manager') of a user for a given business. It's used to tailor the user experience and permissions within the application logic.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true

## Security Implications:
- RLS Status: Helper function.
- Auth Requirements: Requires a user's UID.

## Performance Impact:
- Estimated Impact: Low.
*/
CREATE OR REPLACE FUNCTION public.get_user_role(p_business_id uuid, p_user_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_role text;
BEGIN
  SELECT role INTO v_role
  FROM public.staff_roles
  WHERE business_id = p_business_id AND user_id = p_user_id AND is_active = true;
  RETURN v_role;
END;
$$;

/*
# [Trigger] handle_new_user
Automatically creates a profile for a new user upon signup.

## Query Description:
This trigger fires after a new user is created in the `auth.users` table. It inserts a corresponding record into the `public.profiles` table, populating it with the user's ID, email, and any metadata (like full name and phone) provided during signup. This is a critical step for linking authentication with user data.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Medium"
- Requires-Backup: false
- Reversible: true

## Security Implications:
- This function runs with the privileges of the user that created it. It should be owned by a security-conscious role.

## Performance Impact:
- Triggers: Adds a small overhead to user creation.
- Estimated Impact: Low.
*/
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, phone)
  VALUES (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'phone'
  );
  RETURN new;
END;
$$;

-- Drop existing trigger to ensure idempotency
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
-- Create the trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


/*
# [Function] get_dashboard_stats
Aggregates key performance indicators for a business dashboard.

## Query Description:
This function calculates total revenue, customer count, and provides detailed revenue data for a specific business. It is designed to be called from the application backend to populate the main dashboard view. It involves multiple aggregations and is more complex.

## Metadata:
- Schema-Category: "Data"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true

## Security Implications:
- This function should only be callable by authenticated users who are members of the business. RLS on the underlying tables provides protection.

## Performance Impact:
- This function can be resource-intensive on large datasets. Ensure indexes are present on `business_id` and date columns of the payment tables.
- Estimated Impact: Medium to High, depending on data volume.
*/
CREATE OR REPLACE FUNCTION public.get_dashboard_stats(p_business_id uuid)
RETURNS json
LANGUAGE plpgsql
AS $$
DECLARE
    revenue_data json;
    customer_count int;
BEGIN
    -- Aggregate revenue from all relevant tables
    WITH all_revenue AS (
        SELECT amount, created_at FROM public.sales WHERE business_id = p_business_id
        UNION ALL
        SELECT amount, created_at FROM public.rent_payments WHERE business_id = p_business_id
        UNION ALL
        SELECT amount, created_at FROM public.fee_payments WHERE business_id = p_business_id
        UNION ALL
        SELECT paid_amount as amount, created_at FROM public.bookings WHERE business_id = p_business_id
    )
    SELECT json_agg(ar) INTO revenue_data FROM all_revenue ar;

    -- Aggregate customer count from all relevant tables
    WITH all_customers AS (
        SELECT id FROM public.tenants WHERE business_id = p_business_id AND is_active = true
        UNION
        SELECT id FROM public.students WHERE business_id = p_business_id AND is_active = true
    )
    SELECT count(*) INTO customer_count FROM all_customers;

    RETURN json_build_object(
        'revenue_data', revenue_data,
        'customer_count', customer_count
    );
END;
$$;


-- =================================================================
-- CORE TABLES
-- =================================================================

/*
# [Table] profiles
Stores public user data.
*/
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text UNIQUE NOT NULL,
  phone text,
  full_name text NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow users to view their own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Allow users to update their own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

/*
# [Table] businesses
Stores information about each business entity.
*/
CREATE TABLE IF NOT EXISTS public.businesses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES auth.users(id),
  business_type text NOT NULL, -- 'hardware', 'supermarket', 'rentals', etc.
  name text NOT NULL,
  description text,
  phone text,
  location text,
  logo_url text,
  settings jsonb,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow business members to view their business" ON public.businesses FOR SELECT USING (public.is_business_member(id, auth.uid()));
CREATE POLICY "Allow business owners to update their business" ON public.businesses FOR UPDATE USING (public.get_user_role(id, auth.uid()) = 'owner');

/*
# [Table] staff_roles
Manages user roles and permissions within each business.
*/
CREATE TABLE IF NOT EXISTS public.staff_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL, -- 'owner', 'manager', 'cashier', etc.
  permissions jsonb,
  invited_by uuid REFERENCES auth.users(id),
  invited_at timestamptz DEFAULT now(),
  is_active boolean DEFAULT true,
  UNIQUE (business_id, user_id)
);
ALTER TABLE public.staff_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow business members to view staff" ON public.staff_roles FOR SELECT USING (public.is_business_member(business_id, auth.uid()));
CREATE POLICY "Allow owners/managers to manage staff" ON public.staff_roles FOR ALL USING (public.get_user_role(business_id, auth.uid()) IN ('owner', 'manager'));

/*
# [Table] subscriptions
Tracks the subscription status for each business.
*/
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'trial', -- 'trial', 'active', 'cancelled', 'expired'
  trial_ends_at timestamptz,
  current_period_ends_at timestamptz
);
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow business members to view subscription" ON public.subscriptions FOR SELECT USING (public.is_business_member(business_id, auth.uid()));


-- =================================================================
-- COMMERCE / RETAIL TABLES (Hardware, Supermarket)
-- =================================================================

/*
# [Table] products
Stores product and inventory information.
*/
CREATE TABLE IF NOT EXISTS public.products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  sku text,
  category text,
  buying_price numeric,
  selling_price numeric NOT NULL,
  stock_quantity integer NOT NULL DEFAULT 0,
  min_stock_level integer DEFAULT 0,
  unit text,
  image_url text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on products" ON public.products FOR ALL USING (public.is_business_member(business_id, auth.uid()));

/*
# [Table] sales
Records sales transactions.
*/
CREATE TABLE IF NOT EXISTS public.sales (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  cashier_id uuid REFERENCES auth.users(id),
  customer_name text,
  customer_phone text,
  total_amount numeric NOT NULL,
  payment_method text NOT NULL,
  mpesa_code text,
  notes text,
  receipt_number text UNIQUE,
  created_at timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on sales" ON public.sales FOR ALL USING (public.is_business_member(business_id, auth.uid()));

/*
# [Table] sale_items
Details of items included in a sale.
*/
CREATE TABLE IF NOT EXISTS public.sale_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id uuid NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id),
  quantity integer NOT NULL,
  unit_price numeric NOT NULL,
  total_price numeric NOT NULL
);
-- RLS Policy for sale_items (CORRECTED)
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow full access to business members on sale_items" ON public.sale_items;
CREATE POLICY "Allow full access to business members on sale_items"
ON public.sale_items
FOR ALL
USING (
    EXISTS (
        SELECT 1
        FROM public.sales s
        WHERE s.id = sale_items.sale_id AND public.is_business_member(s.business_id, auth.uid())
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.sales s
        WHERE s.id = sale_items.sale_id AND public.is_business_member(s.business_id, auth.uid())
    )
);


-- =================================================================
-- RENTALS TABLES
-- =================================================================

/*
# [Table] tenants
Stores information about tenants in rental properties.
*/
CREATE TABLE IF NOT EXISTS public.tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name text NOT NULL,
  phone text NOT NULL,
  email text,
  id_number text,
  unit_number text NOT NULL,
  rent_amount numeric NOT NULL,
  deposit_amount numeric,
  lease_start date,
  lease_end date,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on tenants" ON public.tenants FOR ALL USING (public.is_business_member(business_id, auth.uid()));

/*
# [Table] rent_payments
Tracks rent payments from tenants.
*/
CREATE TABLE IF NOT EXISTS public.rent_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  amount numeric NOT NULL,
  payment_date date NOT NULL,
  status text NOT NULL, -- 'paid', 'pending', 'overdue'
  mpesa_code text,
  notes text,
  created_at timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.rent_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on rent_payments" ON public.rent_payments FOR ALL USING (public.is_business_member(business_id, auth.uid()));


-- =================================================================
-- SCHOOL TABLES
-- =================================_================================

/*
# [Table] students
Stores student records for schools.
*/
CREATE TABLE IF NOT EXISTS public.students (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  admission_number text NOT NULL UNIQUE,
  first_name text NOT NULL,
  last_name text NOT NULL,
  date_of_birth date,
  class_level text NOT NULL,
  parent_name text NOT NULL,
  parent_phone text NOT NULL,
  parent_email text,
  address text,
  fee_amount numeric NOT NULL,
  fee_status text NOT NULL, -- 'paid', 'unpaid', 'partial', 'overdue'
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on students" ON public.students FOR ALL USING (public.is_business_member(business_id, auth.uid()));

/*
# [Table] fee_payments
Tracks school fee payments from students.
*/
CREATE TABLE IF NOT EXISTS public.fee_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  amount numeric NOT NULL,
  payment_date date NOT NULL,
  status text NOT NULL, -- 'paid', 'pending'
  mpesa_code text,
  notes text,
  term text,
  created_at timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.fee_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on fee_payments" ON public.fee_payments FOR ALL USING (public.is_business_member(business_id, auth.uid()));


-- =================================================================
-- HOSPITALITY TABLES (Hotel, Airbnb)
-- =================================================================

/*
# [Table] rooms
Stores information about hotel rooms.
*/
CREATE TABLE IF NOT EXISTS public.rooms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  room_number text NOT NULL,
  room_type text NOT NULL,
  capacity integer,
  rate_per_night numeric NOT NULL,
  description text,
  amenities text[],
  status text NOT NULL, -- 'Available', 'Occupied', 'Cleaning', 'Maintenance'
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on rooms" ON public.rooms FOR ALL USING (public.is_business_member(business_id, auth.uid()));

/*
# [Table] listings
Stores information about Airbnb-style listings.
*/
CREATE TABLE IF NOT EXISTS public.listings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name text NOT NULL,
  location text,
  status text, -- 'Listed', 'Booked', 'Maintenance'
  rate_per_night numeric NOT NULL,
  image_url text,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.listings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on listings" ON public.listings FOR ALL USING (public.is_business_member(business_id, auth.uid()));

/*
# [Table] bookings
Stores booking information for rooms or listings.
*/
CREATE TABLE IF NOT EXISTS public.bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  room_id uuid REFERENCES public.rooms(id) ON DELETE SET NULL,
  listing_id uuid REFERENCES public.listings(id) ON DELETE SET NULL,
  guest_name text NOT NULL,
  guest_phone text NOT NULL,
  guest_email text,
  check_in_date date NOT NULL,
  check_out_date date NOT NULL,
  guests_count integer,
  total_amount numeric NOT NULL,
  paid_amount numeric DEFAULT 0,
  booking_status text NOT NULL, -- 'Confirmed', 'Checked-in', 'Checked-out', 'Cancelled'
  payment_status text NOT NULL, -- 'paid', 'pending', 'overdue'
  notes text,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow full access to business members on bookings" ON public.bookings FOR ALL USING (public.is_business_member(business_id, auth.uid()));

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_staff_roles_business_user ON public.staff_roles(business_id, user_id);
CREATE INDEX IF NOT EXISTS idx_products_business_id ON public.products(business_id);
CREATE INDEX IF NOT EXISTS idx_sales_business_id ON public.sales(business_id);
CREATE INDEX IF NOT EXISTS idx_tenants_business_id ON public.tenants(business_id);
CREATE INDEX IF NOT EXISTS idx_students_business_id ON public.students(business_id);
CREATE INDEX IF NOT EXISTS idx_bookings_business_id ON public.bookings(business_id);

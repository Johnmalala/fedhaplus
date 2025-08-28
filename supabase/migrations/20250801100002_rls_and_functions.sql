/*
          # Operation: Row-Level Security (RLS) and Functions
          [This script enables Row-Level Security on all tables and creates the necessary policies to ensure users can only access their own data.]

          ## Query Description: [This is a critical security operation. It locks down all tables and creates rules (policies) that control who can see or modify data. For example, a user will only be able to see the businesses they own. This prevents data leaks between different users. This script is safe to run and is essential for security.]
          
          ## Metadata:
          - Schema-Category: "Dangerous"
          - Impact-Level: "High"
          - Requires-Backup: false
          - Reversible: true
          
          ## Structure Details:
          - All tables will have RLS enabled.
          - SELECT, INSERT, UPDATE, DELETE policies will be created for all tables.
          
          ## Security Implications:
          - RLS Status: Enabled
          - Policy Changes: Yes
          - Auth Requirements: All data access will now require authentication.
          
          ## Performance Impact:
          - Indexes: None.
          - Triggers: None.
          - Estimated Impact: Low to Medium. RLS policies can add a small overhead to queries, but it's necessary for security.
          */

-- Helper function to get the current user's ID
CREATE OR REPLACE FUNCTION auth.current_user_id()
RETURNS uuid AS $$
BEGIN
  RETURN auth.uid();
END;
$$ LANGUAGE plpgsql STABLE;

-- Helper function to check if a user is a staff member of a business
CREATE OR REPLACE FUNCTION is_staff_of_business(p_business_id uuid, p_user_id uuid)
RETURNS boolean AS $$
DECLARE
  is_staff boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM staff_roles
    WHERE business_id = p_business_id AND user_id = p_user_id AND is_active = true
  ) INTO is_staff;
  RETURN is_staff;
END;
$$ LANGUAGE plpgsql STABLE;

-- Enable RLS on all tables
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

-- Profiles Policies
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view their own profile" ON public.profiles FOR SELECT
USING (auth.current_user_id() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE
USING (auth.current_user_id() = id);

-- Businesses Policies
DROP POLICY IF EXISTS "Users can view their own businesses" ON public.businesses;
CREATE POLICY "Users can view their own businesses" ON public.businesses FOR SELECT
USING (auth.current_user_id() = owner_id);

DROP POLICY IF EXISTS "Users can create businesses" ON public.businesses;
CREATE POLICY "Users can create businesses" ON public.businesses FOR INSERT
WITH CHECK (auth.current_user_id() = owner_id);

DROP POLICY IF EXISTS "Owners can update their own businesses" ON public.businesses;
CREATE POLICY "Owners can update their own businesses" ON public.businesses FOR UPDATE
USING (auth.current_user_id() = owner_id);

DROP POLICY IF EXISTS "Owners can delete their own businesses" ON public.businesses;
CREATE POLICY "Owners can delete their own businesses" ON public.businesses FOR DELETE
USING (auth.current_user_id() = owner_id);

-- Staff Roles Policies
DROP POLICY IF EXISTS "Owners can manage staff in their business" ON public.staff_roles;
CREATE POLICY "Owners can manage staff in their business" ON public.staff_roles FOR ALL
USING (business_id IN (SELECT id FROM businesses WHERE owner_id = auth.current_user_id()));

DROP POLICY IF EXISTS "Staff can view their own role" ON public.staff_roles;
CREATE POLICY "Staff can view their own role" ON public.staff_roles FOR SELECT
USING (user_id = auth.current_user_id());

-- Generic Policies for Business-Owned Data
-- Products
DROP POLICY IF EXISTS "Staff can manage products in their business" ON public.products;
CREATE POLICY "Staff can manage products in their business" ON public.products FOR ALL
USING (is_staff_of_business(business_id, auth.current_user_id()));

-- Sales
DROP POLICY IF EXISTS "Staff can manage sales in their business" ON public.sales;
CREATE POLICY "Staff can manage sales in their business" ON public.sales FOR ALL
USING (is_staff_of_business(business_id, auth.current_user_id()));

-- Sale Items (relies on sales table access)
DROP POLICY IF EXISTS "Staff can manage sale items" ON public.sale_items;
CREATE POLICY "Staff can manage sale items" ON public.sale_items FOR ALL
USING (sale_id IN (SELECT id FROM sales WHERE is_staff_of_business(business_id, auth.current_user_id())));

-- Tenants
DROP POLICY IF EXISTS "Staff can manage tenants in their business" ON public.tenants;
CREATE POLICY "Staff can manage tenants in their business" ON public.tenants FOR ALL
USING (is_staff_of_business(business_id, auth.current_user_id()));

-- Rent Payments (relies on tenants table access)
DROP POLICY IF EXISTS "Staff can manage rent payments" ON public.rent_payments;
CREATE POLICY "Staff can manage rent payments" ON public.rent_payments FOR ALL
USING (tenant_id IN (SELECT id FROM tenants WHERE is_staff_of_business(business_id, auth.current_user_id())));

-- Students
DROP POLICY IF EXISTS "Staff can manage students in their business" ON public.students;
CREATE POLICY "Staff can manage students in their business" ON public.students FOR ALL
USING (is_staff_of_business(business_id, auth.current_user_id()));

-- Fee Payments (relies on students table access)
DROP POLICY IF EXISTS "Staff can manage fee payments" ON public.fee_payments;
CREATE POLICY "Staff can manage fee payments" ON public.fee_payments FOR ALL
USING (student_id IN (SELECT id FROM students WHERE is_staff_of_business(business_id, auth.current_user_id())));

-- Rooms
DROP POLICY IF EXISTS "Staff can manage rooms in their business" ON public.rooms;
CREATE POLICY "Staff can manage rooms in their business" ON public.rooms FOR ALL
USING (is_staff_of_business(business_id, auth.current_user_id()));

-- Bookings
DROP POLICY IF EXISTS "Staff can manage bookings in their business" ON public.bookings;
CREATE POLICY "Staff can manage bookings in their business" ON public.bookings FOR ALL
USING (is_staff_of_business(business_id, auth.current_user_id()));

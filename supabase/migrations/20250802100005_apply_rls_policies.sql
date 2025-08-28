/*
          # [Operation Name] Apply Row Level Security (RLS)
          [This script enables RLS on all data tables and creates policies to ensure users can only access data related to their own businesses.]

          ## Query Description: [This is a critical security operation. It restricts all access to tables by default and then adds specific policies to allow access based on user roles and business ownership. This prevents data leaks between different businesses. This operation is DANGEROUS if you have existing data without proper ownership links.]
          
          ## Metadata:
          - Schema-Category: "Dangerous"
          - Impact-Level: "High"
          - Requires-Backup: true
          - Reversible: false
          
          ## Structure Details:
          - Tables Affected: profiles, businesses, products, sales, sale_items, tenants, rent_payments, rooms, bookings, students, fee_payments
          - RLS Enabled: On all listed tables.
          - Policies Created: SELECT, INSERT, UPDATE, DELETE policies for each table.
          
          ## Security Implications:
          - RLS Status: Enabled
          - Policy Changes: Yes
          - Auth Requirements: All data access will now require an authenticated user session.
          
          ## Performance Impact:
          - Indexes: RLS can have a minor performance impact, but policies are written to use indexed columns (owner_id, business_id).
          - Triggers: None
          - Estimated Impact: Medium. Queries will have an additional security check.
          */
-- Enable RLS for all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rent_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fee_payments ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to prevent errors
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Owners can manage their own businesses" ON public.businesses;
DROP POLICY IF EXISTS "Users can manage items in their own businesses" ON public.products;
DROP POLICY IF EXISTS "Users can manage sales in their own businesses" ON public.sales;
DROP POLICY IF EXISTS "Users can manage sale items in their own businesses" ON public.sale_items;
DROP POLICY IF EXISTS "Users can manage tenants in their own businesses" ON public.tenants;
DROP POLICY IF EXISTS "Users can manage rent payments in their own businesses" ON public.rent_payments;
DROP POLICY IF EXISTS "Users can manage rooms in their own businesses" ON public.rooms;
DROP POLICY IF EXISTS "Users can manage bookings in their own businesses" ON public.bookings;
DROP POLICY IF EXISTS "Users can manage students in their own businesses" ON public.students;
DROP POLICY IF EXISTS "Users can manage fee payments in their own businesses" ON public.fee_payments;

-- RLS Policies
-- Profiles
CREATE POLICY "Users can view their own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Businesses
CREATE POLICY "Owners can manage their own businesses" ON public.businesses FOR ALL USING (auth.uid() = owner_id);

-- Products
CREATE POLICY "Users can manage items in their own businesses" ON public.products FOR ALL USING (
  business_id IN (SELECT id FROM public.businesses WHERE owner_id = auth.uid())
);

-- Sales
CREATE POLICY "Users can manage sales in their own businesses" ON public.sales FOR ALL USING (
  business_id IN (SELECT id FROM public.businesses WHERE owner_id = auth.uid())
);

-- Sale Items
CREATE POLICY "Users can manage sale items in their own businesses" ON public.sale_items FOR ALL USING (
  sale_id IN (SELECT id FROM public.sales WHERE business_id IN (SELECT id FROM public.businesses WHERE owner_id = auth.uid()))
);

-- Tenants
CREATE POLICY "Users can manage tenants in their own businesses" ON public.tenants FOR ALL USING (
  business_id IN (SELECT id FROM public.businesses WHERE owner_id = auth.uid())
);

-- Rent Payments
CREATE POLICY "Users can manage rent payments in their own businesses" ON public.rent_payments FOR ALL USING (
  tenant_id IN (SELECT id FROM public.tenants WHERE business_id IN (SELECT id FROM public.businesses WHERE owner_id = auth.uid()))
);

-- Rooms
CREATE POLICY "Users can manage rooms in their own businesses" ON public.rooms FOR ALL USING (
  business_id IN (SELECT id FROM public.businesses WHERE owner_id = auth.uid())
);

-- Bookings
CREATE POLICY "Users can manage bookings in their own businesses" ON public.bookings FOR ALL USING (
  business_id IN (SELECT id FROM public.businesses WHERE owner_id = auth.uid())
);

-- Students
CREATE POLICY "Users can manage students in their own businesses" ON public.students FOR ALL USING (
  business_id IN (SELECT id FROM public.businesses WHERE owner_id = auth.uid())
);

-- Fee Payments
CREATE POLICY "Users can manage fee payments in their own businesses" ON public.fee_payments FOR ALL USING (
  student_id IN (SELECT id FROM public.students WHERE business_id IN (SELECT id FROM public.businesses WHERE owner_id = auth.uid()))
);

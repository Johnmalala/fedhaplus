/*
          # [Staff and RLS Policy Setup]
          This script creates the staff management table and applies Row Level Security policies to all data tables, ensuring users can only access data related to their own business.

          ## Query Description: "This critical security operation creates the 'staff_roles' table and applies strict access control policies across all data tables. This ensures that a user associated with one business cannot see data from another. It is safe to run but essential for data privacy."
          
          ## Metadata:
          - Schema-Category: "Security"
          - Impact-Level: "High"
          - Requires-Backup: false
          - Reversible: true
          
          ## Structure Details:
          - Tables Created: staff_roles
          - Policies Created: On all data tables (products, sales, tenants, etc.)
          
          ## Security Implications:
          - RLS Status: Enabled
          - Policy Changes: Yes, this is the primary purpose.
          - Auth Requirements: None for migration, but policies rely on auth.uid().
          
          ## Performance Impact:
          - Indexes: Adds indexes on staff_roles.
          - Triggers: None.
          - Estimated Impact: Low to Medium. RLS policies add a small overhead to every query.
          */

-- 1. STAFF ROLES TABLE
CREATE TABLE IF NOT EXISTS public.staff_roles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role text NOT NULL,
    permissions jsonb,
    invited_by uuid REFERENCES public.profiles(id),
    invited_at timestamptz DEFAULT now(),
    is_active boolean DEFAULT true,
    UNIQUE(business_id, user_id)
);
COMMENT ON TABLE public.staff_roles IS 'Assigns roles to users for specific businesses.';

-- 2. ENABLE RLS
ALTER TABLE public.staff_roles ENABLE ROW LEVEL SECURITY;

-- 3. HELPER FUNCTION to check if a user is a member of a business
CREATE OR REPLACE FUNCTION public.is_business_member(p_business_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.businesses b
    WHERE b.id = p_business_id AND b.owner_id = p_user_id
  ) OR EXISTS (
    SELECT 1 FROM public.staff_roles sr
    WHERE sr.business_id = p_business_id AND sr.user_id = p_user_id AND sr.is_active = true
  );
END;
$$;

-- 4. APPLY RLS POLICIES TO ALL TABLES
-- Staff Roles
CREATE POLICY "Business owners can manage their staff" ON public.staff_roles
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.businesses b
      WHERE b.id = staff_roles.business_id AND b.owner_id = auth.uid()
    )
  );
CREATE POLICY "Staff can view their own role" ON public.staff_roles
  FOR SELECT USING (user_id = auth.uid());

-- Products
CREATE POLICY "Business members can manage products" ON public.products
  FOR ALL USING (is_business_member(business_id, auth.uid()));

-- Sales
CREATE POLICY "Business members can manage sales" ON public.sales
  FOR ALL USING (is_business_member(business_id, auth.uid()));

-- Sale Items
CREATE POLICY "Business members can manage sale items" ON public.sale_items
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.sales s
      WHERE s.id = sale_items.sale_id AND is_business_member(s.business_id, auth.uid())
    )
  );

-- Tenants
CREATE POLICY "Business members can manage tenants" ON public.tenants
  FOR ALL USING (is_business_member(business_id, auth.uid()));

-- Rent Payments
CREATE POLICY "Business members can manage rent payments" ON public.rent_payments
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.tenants t
      WHERE t.id = rent_payments.tenant_id AND is_business_member(t.business_id, auth.uid())
    )
  );

-- Students
CREATE POLICY "Business members can manage students" ON public.students
  FOR ALL USING (is_business_member(business_id, auth.uid()));

-- Fee Payments
CREATE POLICY "Business members can manage fee payments" ON public.fee_payments
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.students s
      WHERE s.id = fee_payments.student_id AND is_business_member(s.business_id, auth.uid())
    )
  );

-- Rooms
CREATE POLICY "Business members can manage rooms" ON public.rooms
  FOR ALL USING (is_business_member(business_id, auth.uid()));

-- Bookings
CREATE POLICY "Business members can manage bookings" ON public.bookings
  FOR ALL USING (is_business_member(business_id, auth.uid()));

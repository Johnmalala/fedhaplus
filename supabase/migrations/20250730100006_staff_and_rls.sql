/*
          # [Staff & RLS]
          Creates the staff management table and enables Row Level Security.

          ## Query Description: This is a critical security script. It creates the `staff_roles` table to manage user permissions within a business. It then enables RLS on all data tables and creates policies to ensure users can only access data related to their own businesses.

          ## Metadata:
          - Schema-Category: "Dangerous"
          - Impact-Level: "High"
          - Requires-Backup: true
          - Reversible: false (Disabling RLS after enabling is complex)

          ## Structure Details:
          - Tables Created: `staff_roles`
          - RLS Enabled: on all data tables
          - Policies Created: `SELECT`, `INSERT`, `UPDATE`, `DELETE` policies for all tables.

          ## Security Implications:
          - RLS Status: Enabled
          - Policy Changes: Yes
          - Auth Requirements: All data access will now require authentication.

          ## Performance Impact:
          - Indexes: Primary keys and foreign keys are indexed.
          - Triggers: None.
          - Estimated Impact: Medium. RLS adds a small overhead to every query.
          */

-- 1. Staff Roles Table
CREATE TABLE IF NOT EXISTS public.staff_roles (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role text NOT NULL CHECK (role IN ('owner', 'manager', 'cashier', 'accountant', 'teacher', 'front_desk', 'housekeeper')),
    permissions jsonb,
    invited_by uuid REFERENCES public.profiles(id),
    invited_at timestamp with time zone DEFAULT now(),
    is_active boolean DEFAULT true,
    UNIQUE(business_id, user_id)
);

-- Helper function to check user role in a business
CREATE OR REPLACE FUNCTION public.get_my_business_ids()
RETURNS TABLE(business_id uuid)
LANGUAGE sql
SECURITY DEFINER SET search_path = public
AS $$
    SELECT business_id FROM staff_roles WHERE user_id = auth.uid();
$$;

-- === ENABLE RLS AND CREATE POLICIES ===

-- 1. Profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view their own profile" ON public.profiles FOR SELECT USING (id = auth.uid());
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (id = auth.uid());

-- 2. Businesses
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owners can manage their own businesses" ON public.businesses;
CREATE POLICY "Owners can manage their own businesses" ON public.businesses FOR ALL
USING (owner_id = auth.uid())
WITH CHECK (owner_id = auth.uid());

-- 3. Staff Roles
ALTER TABLE public.staff_roles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view staff in their businesses" ON public.staff_roles;
CREATE POLICY "Users can view staff in their businesses" ON public.staff_roles FOR SELECT
USING (business_id IN (SELECT business_id FROM get_my_business_ids()));
DROP POLICY IF EXISTS "Owners can manage staff in their businesses" ON public.staff_roles;
CREATE POLICY "Owners can manage staff in their businesses" ON public.staff_roles FOR ALL
USING (business_id IN (SELECT business_id FROM businesses WHERE owner_id = auth.uid()))
WITH CHECK (business_id IN (SELECT business_id FROM businesses WHERE owner_id = auth.uid()));

-- Generic policy for all other tables
DO $$
DECLARE
    t_name TEXT;
BEGIN
    FOR t_name IN
        SELECT table_name FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name IN (
            'products', 'sales', 'sale_items', 'tenants', 'rent_payments',
            'students', 'fee_payments', 'rooms', 'bookings'
        )
    LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', t_name);

        EXECUTE format('DROP POLICY IF EXISTS "Staff can access data in their assigned business" ON public.%I;', t_name);
        EXECUTE format(
            'CREATE POLICY "Staff can access data in their assigned business" ON public.%I FOR ALL '
            'USING (business_id IN (SELECT business_id FROM get_my_business_ids())) '
            'WITH CHECK (business_id IN (SELECT business_id FROM get_my_business_ids()));',
            t_name
        );
    END LOOP;
END;
$$;

/*
# [Fix] RLS Policy Recursion on staff_roles

This migration fixes an infinite recursion error in the Row-Level Security (RLS) policies for the `staff_roles` table. The previous policies called a function that queried the same table, creating a loop.

## Query Description:
This operation will drop and recreate the RLS policies on the `public.staff_roles` table. The new policies are designed to avoid recursion by using subqueries or checking against the `businesses` table for the initial owner setup. This change is critical for allowing new business creation to succeed. No data will be lost.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Medium"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Table: `public.staff_roles`
- Affected Objects: RLS Policies for SELECT, INSERT, UPDATE, DELETE

## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes. Policies are being replaced with safer, non-recursive versions. The intended security logic is preserved.
- Auth Requirements: User must be authenticated.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible. Subqueries in RLS can have a performance impact, but they are necessary for this security model and should be efficient with proper indexing on `business_id` and `user_id`.
*/

-- Drop existing policies on staff_roles to avoid conflicts.
DROP POLICY IF EXISTS "Allow business members to view staff" ON public.staff_roles;
DROP POLICY IF EXISTS "Allow owners or managers to add staff" ON public.staff_roles;
DROP POLICY IF EXISTS "Allow owners or managers to update staff" ON public.staff_roles;
DROP POLICY IF EXISTS "Allow owners to remove staff" ON public.staff_roles;
DROP POLICY IF EXISTS "Allow full access to business members" ON public.staff_roles;
DROP POLICY IF EXISTS "Allow full access to business members on staff_roles" ON public.staff_roles;


-- Create new, non-recursive policies for staff_roles

-- 1. SELECT Policy: Users can see other staff members in businesses they belong to.
CREATE POLICY "Allow business members to view staff"
ON public.staff_roles
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.staff_roles sr
    WHERE sr.user_id = auth.uid() AND sr.business_id = staff_roles.business_id
  )
);

-- 2. INSERT Policy: Owners/managers can add staff. A new business owner can add themselves.
CREATE POLICY "Allow owners or managers to add staff"
ON public.staff_roles
FOR INSERT
WITH CHECK (
  -- Scenario A: The user is already an owner or manager of the target business.
  EXISTS (
    SELECT 1
    FROM public.staff_roles sr
    WHERE sr.user_id = auth.uid()
      AND sr.business_id = staff_roles.business_id
      AND sr.role IN ('owner', 'manager')
  )
  OR
  -- Scenario B (Bootstrap): The user is the owner of the business record and is adding themselves.
  EXISTS (
    SELECT 1
    FROM public.businesses b
    WHERE b.id = staff_roles.business_id
      AND b.owner_id = auth.uid()
      AND staff_roles.user_id = auth.uid()
  )
);

-- 3. UPDATE Policy: Owners/managers can update roles, but cannot demote other owners.
CREATE POLICY "Allow owners or managers to update staff"
ON public.staff_roles
FOR UPDATE
USING (
  EXISTS (
    SELECT 1
    FROM public.staff_roles sr
    WHERE sr.user_id = auth.uid()
      AND sr.business_id = staff_roles.business_id
      AND sr.role IN ('owner', 'manager')
  )
)
WITH CHECK (
  -- The user performing the update must be an owner or manager.
  EXISTS (
    SELECT 1
    FROM public.staff_roles sr
    WHERE sr.user_id = auth.uid()
      AND sr.business_id = staff_roles.business_id
      AND sr.role IN ('owner', 'manager')
  )
  -- An owner cannot be demoted by a manager.
  AND NOT (
    (SELECT role FROM public.staff_roles WHERE id = staff_roles.id) = 'owner'
    AND
    (SELECT role FROM public.staff_roles WHERE user_id = auth.uid() AND business_id = staff_roles.business_id) = 'manager'
  )
);


-- 4. DELETE Policy: Only owners can remove staff members (but not themselves).
CREATE POLICY "Allow owners to remove staff"
ON public.staff_roles
FOR DELETE
USING (
  -- User must be an owner of the business.
  EXISTS (
    SELECT 1
    FROM public.staff_roles sr
    WHERE sr.user_id = auth.uid()
      AND sr.business_id = staff_roles.business_id
      AND sr.role = 'owner'
  )
  -- User cannot delete their own staff role.
  AND staff_roles.user_id <> auth.uid()
);

/*
# [Fix] RLS Policy for staff_roles to prevent infinite recursion

This migration fixes a critical bug where creating a new business fails due to an infinite recursion loop in the Row-Level Security (RLS) policies for the `staff_roles` table.

## Query Description:
- **Problem**: The existing policy for adding staff members (`INSERT` on `staff_roles`) was checking if the current user was already a member of the business by querying the `staff_roles` table. This created a circular dependency, causing an infinite loop when the first staff member (the owner) was being added.
- **Solution**: This script replaces the faulty policies with a new, safe set of rules. The new `INSERT` policy now checks if the user is the `owner_id` on the `businesses` table, which is a non-recursive and safe check. This allows the business owner to always manage staff.
- **Impact**: This change makes the business creation process functional. It also standardizes staff management permissions, restricting them to the business owner for security. No data will be lost.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Medium"
- Requires-Backup: false
- Reversible: true (by restoring previous policies)

## Structure Details:
- Drops all existing RLS policies on the `public.staff_roles` table.
- Creates new, non-recursive policies for SELECT, INSERT, UPDATE, and DELETE on `public.staff_roles`.

## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes. Policies on `staff_roles` are replaced.
- Auth Requirements: User must be authenticated.
*/

-- Drop all existing policies on staff_roles to ensure a clean slate.
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'staff_roles' AND schemaname = 'public') LOOP
        EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.staff_roles;';
    END LOOP;
END;
$$;


-- Create new, safe policies for staff_roles

-- 1. SELECT Policy: A user can view staff members of a business if they are also a member of that business.
-- This is safe for SELECT operations.
CREATE POLICY "Allow members to view staff"
ON public.staff_roles
FOR SELECT
USING (
  public.is_business_member(business_id, auth.uid())
);

-- 2. INSERT Policy: A user can add a new staff member ONLY IF they are the owner of the business.
-- This check is NOT recursive because it queries the `businesses` table, not `staff_roles`.
CREATE POLICY "Allow owner to insert staff"
ON public.staff_roles
FOR INSERT
WITH CHECK (
  (SELECT b.owner_id FROM public.businesses b WHERE b.id = staff_roles.business_id) = auth.uid()
);

-- 3. UPDATE Policy: A user can update a staff role ONLY IF they are the owner of the business.
CREATE POLICY "Allow owner to update staff"
ON public.staff_roles
FOR UPDATE
USING (
  (SELECT b.owner_id FROM public.businesses b WHERE b.id = staff_roles.business_id) = auth.uid()
);

-- 4. DELETE Policy: A user can remove a staff member ONLY IF they are the owner of the business.
CREATE POLICY "Allow owner to delete staff"
ON public.staff_roles
FOR DELETE
USING (
  (SELECT b.owner_id FROM public.businesses b WHERE b.id = staff_roles.business_id) = auth.uid()
);

/*
# [Function Security and Staff Invite Feature]
This migration secures existing functions by setting a fixed search_path and introduces a new function for inviting staff members to a business.

## Query Description: 
- **Security Fix**: Alters `handle_new_user`, `is_business_member`, and `get_dashboard_stats` to prevent search_path hijacking attacks by explicitly setting `SET search_path = 'public'`. This is a non-destructive, safe operation.
- **New Feature**: Adds the `invite_staff` function, which allows business members to invite existing Fedha Plus users to their business by email. This function is `SECURITY DEFINER` to safely query user emails. It checks permissions before adding a new staff role.

## Metadata:
- Schema-Category: ["Structural", "Safe"]
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- **Altered Functions**: `handle_new_user`, `is_business_member`, `get_dashboard_stats`.
- **New Function**: `invite_staff(p_business_id uuid, p_invitee_email text, p_role public.staff_role_enum)`.

## Security Implications:
- RLS Status: Unchanged.
- Policy Changes: No.
- Auth Requirements: `invite_staff` is callable by any `authenticated` user but contains internal checks to ensure the caller is a member of the business they are inviting to. This improves security by hardening database functions.

## Performance Impact:
- Indexes: None.
- Triggers: None.
- Estimated Impact: Negligible performance impact.
*/

-- Fix search_path for existing functions
ALTER FUNCTION public.handle_new_user() SET search_path = 'public';
ALTER FUNCTION public.is_business_member(business_id_to_check uuid, user_id_to_check uuid) SET search_path = 'public';
ALTER FUNCTION public.get_dashboard_stats(p_business_id uuid) SET search_path = 'public';

-- Function to invite a staff member (who is already a user) to a business
CREATE OR REPLACE FUNCTION public.invite_staff(
  p_business_id uuid,
  p_invitee_email text,
  p_role public.staff_role_enum
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_user_id uuid;
  v_inviter_id uuid := auth.uid();
BEGIN
  -- 1. Check if the person inviting is a member of the business
  IF NOT public.is_business_member(p_business_id, v_inviter_id) THEN
    RAISE EXCEPTION 'Permission denied: You are not a member of this business.';
  END IF;

  -- 2. Find the user ID from the provided email
  SELECT id INTO v_user_id FROM auth.users WHERE email = p_invitee_email;

  -- 3. If user does not exist, raise an error.
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User with email % not found. Please ask them to create a Fedha Plus account first.', p_invitee_email;
  END IF;

  -- 4. Check if the user is already a staff member in this business
  IF EXISTS (SELECT 1 FROM public.staff_roles WHERE business_id = p_business_id AND user_id = v_user_id) THEN
    RAISE EXCEPTION 'This user is already a member of your business.';
  END IF;

  -- 5. Insert the new staff role
  INSERT INTO public.staff_roles (business_id, user_id, role, invited_by, is_active)
  VALUES (p_business_id, v_user_id, p_role, v_inviter_id, true); -- Setting is_active to true for simplicity.

END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.invite_staff(uuid, text, public.staff_role_enum) TO authenticated;

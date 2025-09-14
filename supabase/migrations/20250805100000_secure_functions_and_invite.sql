/*
# [Operation Name]
Create staff_role_enum type if it does not exist

## Query Description: [This operation safely creates the required 'staff_role_enum' type, which was missing from a previous migration. It will not affect any existing data and is necessary for subsequent functions and tables to work correctly. This fixes a critical dependency issue.]

## Metadata:
- Schema-Category: ["Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: [false]
- Reversible: [false]

## Structure Details:
- Types: [public.staff_role_enum]

## Security Implications:
- RLS Status: [N/A]
- Policy Changes: [No]
- Auth Requirements: [N/A]

## Performance Impact:
- Estimated Impact: [None]
*/
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'staff_role_enum') THEN
        CREATE TYPE public.staff_role_enum AS ENUM ('owner', 'manager', 'cashier', 'accountant', 'teacher', 'front_desk', 'housekeeper');
    END IF;
END$$;


/*
# [Operation Name]
Secure existing functions by setting search_path

## Query Description: [This operation enhances security by explicitly setting the 'search_path' for existing functions. This prevents potential hijacking attacks by ensuring functions only search in trusted schemas ('public'). It is a safe, non-destructive operation with no impact on data.]

## Metadata:
- Schema-Category: ["Safe"]
- Impact-Level: ["Low"]
- Requires-Backup: [false]
- Reversible: [true]

## Structure Details:
- Functions: [public.get_dashboard_stats, public.is_business_member]

## Security Implications:
- RLS Status: [N/A]
- Policy Changes: [No]
- Auth Requirements: [N/A]

## Performance Impact:
- Estimated Impact: [None]
*/
ALTER FUNCTION public.get_dashboard_stats(p_business_id uuid) SET search_path = public;
ALTER FUNCTION public.is_business_member(p_business_id uuid, p_user_id uuid) SET search_path = public;


/*
# [Operation Name]
Create invite_staff function

## Query Description: [This operation creates a new function 'invite_staff' that allows a business owner to invite an existing Fedha Plus user to their business. It checks if the invitee exists and if the inviter is the owner. It is a safe operation that adds functionality without altering existing data.]

## Metadata:
- Schema-Category: ["Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: [false]
- Reversible: [true]

## Structure Details:
- Functions: [public.invite_staff]

## Security Implications:
- RLS Status: [N/A]
- Policy Changes: [No]
- Auth Requirements: [This function can only be run by authenticated users.]

## Performance Impact:
- Estimated Impact: [Low, as it performs checks on tables.]
*/
CREATE OR REPLACE FUNCTION public.invite_staff(
    p_business_id UUID,
    p_invitee_email TEXT,
    p_role public.staff_role_enum
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    invitee_user_id UUID;
    inviter_user_id UUID := auth.uid();
    is_owner BOOLEAN;
BEGIN
    -- 1. Check if the inviter is the owner of the business
    SELECT owner_id = inviter_user_id INTO is_owner
    FROM businesses
    WHERE id = p_business_id;

    IF NOT is_owner THEN
        RAISE EXCEPTION 'Only the business owner can invite staff.';
    END IF;

    -- 2. Find the user ID of the invitee from their email
    SELECT id INTO invitee_user_id
    FROM auth.users
    WHERE email = p_invitee_email;

    IF invitee_user_id IS NULL THEN
        RAISE EXCEPTION 'User with email % not found. Please ask them to sign up for Fedha Plus first.', p_invitee_email;
    END IF;
    
    -- 3. Check if the user is already a member of this business
    IF EXISTS (
        SELECT 1 FROM staff_roles 
        WHERE business_id = p_business_id AND user_id = invitee_user_id
    ) THEN
        RAISE EXCEPTION 'User is already a member of this business.';
    END IF;

    -- 4. Insert the new staff role (invitation)
    INSERT INTO staff_roles (business_id, user_id, role, invited_by, is_active)
    VALUES (p_business_id, invitee_user_id, p_role, inviter_user_id, true); -- Setting to active immediately for simplicity

END;
$$;

-- Since the function is SECURITY DEFINER, we grant execute to authenticated users.
-- RLS on the `businesses` and `staff_roles` tables will handle access control.
GRANT EXECUTE ON FUNCTION public.invite_staff(UUID, TEXT, public.staff_role_enum) TO authenticated;

/*
# [Final Security Hardening]
This migration addresses the remaining "Function Search Path Mutable" security warnings by explicitly setting the `search_path` for all custom functions. This is a non-destructive operation that enhances security by preventing potential search path hijacking attacks.

## Query Description:
This script uses `ALTER FUNCTION` to modify the configuration of existing functions. It does not change the function logic, drop any objects, or affect any data. It is safe to run on a production database.

## Metadata:
- Schema-Category: ["Safe", "Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: true (by altering the function to reset the search_path)

## Structure Details:
- Modifies configuration for the following functions:
  - is_business_member
  - get_dashboard_stats
  - invite_staff
  - create_sale_and_items
  - get_my_businesses
  - create_booking
  - handle_new_user

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: None
- Mitigates `search_path` vulnerabilities for all custom functions.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible. This is a one-time configuration change.
*/

ALTER FUNCTION public.is_business_member(business_id uuid, user_id uuid) SET search_path = 'public';

ALTER FUNCTION public.get_dashboard_stats(p_business_id uuid) SET search_path = 'public';

ALTER FUNCTION public.invite_staff(p_business_id uuid, p_invitee_email text, p_role public.staff_role_enum) SET search_path = 'public';

ALTER FUNCTION public.create_sale_and_items(p_business_id uuid, p_cashier_id uuid, p_items jsonb) SET search_path = 'public';

ALTER FUNCTION public.get_my_businesses() SET search_path = 'public';

ALTER FUNCTION public.create_booking(p_business_id uuid, p_guest_name text, p_guest_phone text, p_check_in_date date, p_check_out_date date, p_guests_count integer, p_total_amount numeric, p_room_id uuid, p_listing_id uuid) SET search_path = 'public';

-- The trigger function `handle_new_user` also needs its search path set.
ALTER FUNCTION public.handle_new_user() SET search_path = 'public';

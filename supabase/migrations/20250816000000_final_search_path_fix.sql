/*
# [Security Hardening] Final Search Path Fix
This migration addresses the final "Function Search Path Mutable" security warnings by explicitly setting the `search_path` for all custom functions. This is a non-destructive operation that enhances security by preventing potential hijacking attacks.

## Query Description:
This operation alters existing functions to lock their search path. It does not modify function logic or data. It is a safe and recommended security practice.

## Metadata:
- Schema-Category: ["Safe", "Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: true (by altering the function back)

## Structure Details:
- Alters `handle_new_user`
- Alters `is_business_member`
- Alters `get_dashboard_stats`
- Alters `invite_staff`
- Alters `create_sale_and_items`
- Alters `create_booking`
- Alters `get_my_businesses`

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: None
- Mitigates: Function search path vulnerabilities.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible performance impact.
*/

-- Set a secure search path for all custom functions using ALTER FUNCTION
-- This is a non-destructive way to apply security settings.
ALTER FUNCTION public.handle_new_user() SET search_path = public;
ALTER FUNCTION public.is_business_member(uuid, uuid) SET search_path = public;
ALTER FUNCTION public.get_dashboard_stats(uuid) SET search_path = public;
ALTER FUNCTION public.invite_staff(uuid, text, public.staff_role_enum) SET search_path = public;
ALTER FUNCTION public.create_sale_and_items(uuid, uuid, jsonb) SET search_path = public;
ALTER FUNCTION public.create_booking(uuid, text, text, date, date, integer, numeric, uuid, uuid) SET search_path = public;
ALTER FUNCTION public.get_my_businesses() SET search_path = public;

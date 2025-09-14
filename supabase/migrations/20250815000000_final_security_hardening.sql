/*
# [Final Security Hardening]
This migration addresses the final security warnings by setting a fixed search_path for all remaining custom functions.

## Query Description:
This operation safely modifies existing function configurations using ALTER FUNCTION. It prevents potential search path hijacking vulnerabilities. No data is affected, and this change is reversible.

## Metadata:
- Schema-Category: ["Safe", "Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: true

## Structure Details:
- All custom functions in the 'public' schema will have their search_path set.

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: None

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible
*/

ALTER FUNCTION public.create_booking(uuid, text, text, date, date, integer, numeric, uuid, uuid) SET search_path = public, extensions;
ALTER FUNCTION public.create_sale_and_items(uuid, uuid, jsonb) SET search_path = public, extensions;
ALTER FUNCTION public.get_dashboard_stats(p_business_id uuid) SET search_path = public, extensions;
ALTER FUNCTION public.get_my_businesses() SET search_path = public, extensions;
ALTER FUNCTION public.handle_new_user() SET search_path = public, extensions;
ALTER FUNCTION public.invite_staff(uuid, text, public.staff_role_enum) SET search_path = public, extensions;
ALTER FUNCTION public.is_business_member(uuid, uuid) SET search_path = public, extensions;

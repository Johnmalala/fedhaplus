/*
# [Operation Name]
Secure All Custom Functions

## Query Description: [This operation updates all custom functions to set a fixed `search_path`. This is a security best practice that prevents potential context-switching vulnerabilities. It is a non-destructive operation and will not affect your data or the logic of the functions.]

## Metadata:
- Schema-Category: ["Security", "Safe"]
- Impact-Level: ["Low"]
- Requires-Backup: [false]
- Reversible: [true]

## Structure Details:
- Modifies the `search_path` property of existing functions.

## Security Implications:
- RLS Status: [Not Affected]
- Policy Changes: [No]
- Auth Requirements: [None]

## Performance Impact:
- Indexes: [Not Affected]
- Triggers: [Not Affected]
- Estimated Impact: [None]
*/

-- Secure all custom functions by setting a fixed search_path
ALTER FUNCTION public.handle_new_user() SET search_path = public;
ALTER FUNCTION public.is_business_member(uuid, uuid) SET search_path = public;
ALTER FUNCTION public.get_my_businesses() SET search_path = public;
ALTER FUNCTION public.get_dashboard_stats(uuid) SET search_path = public;
ALTER FUNCTION public.invite_staff(uuid, text, staff_role_enum) SET search_path = public;
ALTER FUNCTION public.create_sale_and_items(uuid, uuid, jsonb) SET search_path = public;
ALTER FUNCTION public.create_booking(uuid, text, text, date, date, integer, numeric, uuid, uuid) SET search_path = public;

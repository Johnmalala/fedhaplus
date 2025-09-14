/*
# [Final Function Security Hardening]
This migration addresses the final security warnings by explicitly setting the `search_path` for all custom functions. This prevents potential search path hijacking vulnerabilities.

## Query Description:
This operation safely alters existing functions to enforce a secure search path. It is non-destructive and will not affect your data or existing logic. It enhances security by ensuring functions only search within expected schemas.

## Metadata:
- Schema-Category: ["Safe", "Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Alters the following functions:
  - `handle_new_user()`
  - `is_business_member(uuid, uuid)`
  - `get_my_businesses()`
  - `get_dashboard_stats(uuid)`
  - `invite_staff(uuid, text, public.staff_role_enum)`
  - `create_sale_and_items(uuid, uuid, jsonb)`
  - `create_booking(uuid, text, text, date, date, integer, numeric, uuid, uuid)`

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: None
- Mitigates "Function Search Path Mutable" warnings.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible.
*/

ALTER FUNCTION public.handle_new_user() SET search_path = public;
ALTER FUNCTION public.is_business_member(p_business_id uuid, p_user_id uuid) SET search_path = public;
ALTER FUNCTION public.get_my_businesses() SET search_path = public;
ALTER FUNCTION public.get_dashboard_stats(p_business_id uuid) SET search_path = public;
ALTER FUNCTION public.invite_staff(p_business_id uuid, p_invitee_email text, p_role public.staff_role_enum) SET search_path = public;
ALTER FUNCTION public.create_sale_and_items(p_business_id uuid, p_cashier_id uuid, p_items jsonb) SET search_path = public;
ALTER FUNCTION public.create_booking(p_business_id uuid, p_guest_name text, p_guest_phone text, p_check_in_date date, p_check_out_date date, p_guests_count integer, p_total_amount numeric, p_room_id uuid, p_listing_id uuid) SET search_path = public;

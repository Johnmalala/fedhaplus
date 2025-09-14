/*
# [Final Security Hardening]
This script applies the final security hardening by setting a fixed `search_path` for all custom database functions. This is a best practice to prevent potential security vulnerabilities.

## Query Description:
This operation is safe and non-destructive. It uses `ALTER FUNCTION` to modify the configuration of existing functions without changing their logic or dropping them. This resolves the "Function Search Path Mutable" security warnings.

## Metadata:
- Schema-Category: ["Safe", "Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: true (by altering the function again)

## Structure Details:
- Modifies the search_path property of all custom functions.

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: None

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible
*/

-- Set a secure search path for all custom functions to resolve security advisories.
-- This is safe to run multiple times.

ALTER FUNCTION public.handle_new_user() SET search_path = public;

ALTER FUNCTION public.is_business_member(uuid, uuid) SET search_path = public;

ALTER FUNCTION public.get_dashboard_stats(p_business_id uuid) SET search_path = public;

ALTER FUNCTION public.create_sale_and_items(p_business_id uuid, p_cashier_id uuid, p_items jsonb) SET search_path = public;

ALTER FUNCTION public.invite_staff(p_business_id uuid, p_invitee_email text, p_role public.staff_role_enum) SET search_path = public;

ALTER FUNCTION public.create_booking(p_business_id uuid, p_guest_name text, p_guest_phone text, p_check_in_date date, p_check_out_date date, p_guests_count integer, p_total_amount numeric, p_room_id uuid, p_listing_id uuid) SET search_path = public;

ALTER FUNCTION public.get_my_businesses() SET search_path = public;

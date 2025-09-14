/*
# [Finalize Security]
This migration secures all custom database functions by setting a fixed `search_path`.
This addresses the "Function Search Path Mutable" security warnings and is a best practice to prevent potential schema-hijacking attacks.

## Query Description:
This is a safe, non-destructive operation. It uses `ALTER FUNCTION` to modify the configuration of existing functions without changing their logic or dropping them. There is no risk to existing data or policies.

## Metadata:
- Schema-Category: ["Safe", "Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: true (by unsetting the search_path)

## Structure Details:
- Modifies the configuration of all custom functions to enhance security.

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: None
- Mitigates `search_path` vulnerabilities.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible.
*/

-- Set a secure search path for all custom functions
ALTER FUNCTION public.handle_new_user() SET search_path = public;
ALTER FUNCTION public.is_business_member(uuid, uuid) SET search_path = public;
ALTER FUNCTION public.get_dashboard_stats(p_business_id uuid) SET search_path = public;
ALTER FUNCTION public.invite_staff(p_business_id uuid, p_invitee_email text, p_role public.staff_role_enum) SET search_path = public;
ALTER FUNCTION public.create_sale_and_items(p_business_id uuid, p_cashier_id uuid, p_items jsonb) SET search_path = public;
ALTER FUNCTION public.create_booking(p_business_id uuid, p_guest_name text, p_guest_phone text, p_check_in_date date, p_check_out_date date, p_guests_count integer, p_total_amount numeric, p_room_id uuid, p_listing_id uuid) SET search_path = public;
ALTER FUNCTION public.get_my_businesses() SET search_path = public;

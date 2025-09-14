/*
# [Operation Name] Harden Function Search Paths
[This script sets a fixed search_path for all custom database functions to mitigate security risks, addressing the "Function Search Path Mutable" warning.]

## Query Description: [This operation enhances security by explicitly defining the schema search path for custom functions. It prevents potential hijacking attacks where a malicious user could create objects in other schemas that get executed unintentionally. This is a safe, non-destructive operation with no impact on data.]

## Metadata:
- Schema-Category: ["Safe", "Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: true

## Structure Details:
[Alters the configuration of the following functions: is_business_member, handle_new_user, get_dashboard_stats, invite_staff, create_sale_and_items, create_booking, get_my_businesses]

## Security Implications:
- RLS Status: [Enabled]
- Policy Changes: [No]
- Auth Requirements: [None]

## Performance Impact:
- Indexes: [None]
- Triggers: [None]
- Estimated Impact: [No performance impact.]
*/

ALTER FUNCTION public.is_business_member(uuid, uuid) SET search_path = 'public';
ALTER FUNCTION public.handle_new_user() SET search_path = 'public';
ALTER FUNCTION public.get_dashboard_stats(uuid) SET search_path = 'public';
ALTER FUNCTION public.invite_staff(p_business_id uuid, p_invitee_email text, p_role public.staff_role_enum) SET search_path = 'public';
ALTER FUNCTION public.create_sale_and_items(p_business_id uuid, p_cashier_id uuid, p_items jsonb) SET search_path = 'public';
ALTER FUNCTION public.create_booking(p_business_id uuid, p_guest_name text, p_guest_phone text, p_check_in_date text, p_check_out_date text, p_guests_count integer, p_total_amount numeric, p_room_id uuid, p_listing_id uuid) SET search_path = 'public';
ALTER FUNCTION public.get_my_businesses() SET search_path = 'public';

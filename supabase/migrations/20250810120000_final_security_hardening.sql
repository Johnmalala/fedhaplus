-- Final Security Hardening
-- This script safely sets the search_path for all custom functions to address the final security warnings.
-- Using ALTER FUNCTION is non-destructive and avoids dependency issues.

/*
# [Operation Name] Secure All Custom Functions
[This operation sets a fixed search_path for all custom database functions to mitigate security risks related to search path hijacking.]

## Query Description: [This is a safe, non-destructive operation that enhances security by explicitly defining the schema search path for each function. It does not alter function logic or data.]

## Metadata:
- Schema-Category: ["Safe", "Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: [false]
- Reversible: [true]

## Structure Details:
[Alters the configuration of the following functions: is_business_member, get_dashboard_stats, create_sale_and_items, invite_staff, create_booking, get_my_businesses]
*/

ALTER FUNCTION public.is_business_member(uuid, uuid)
SET search_path = public;

ALTER FUNCTION public.get_dashboard_stats(p_business_id uuid)
SET search_path = public;

ALTER FUNCTION public.create_sale_and_items(p_business_id uuid, p_cashier_id uuid, p_items jsonb)
SET search_path = public;

ALTER FUNCTION public.invite_staff(p_business_id uuid, p_invitee_email text, p_role public.staff_role_enum)
SET search_path = public;

ALTER FUNCTION public.create_booking(p_business_id uuid, p_guest_name text, p_guest_phone text, p_check_in_date date, p_check_out_date date, p_guests_count integer, p_total_amount numeric, p_room_id uuid, p_listing_id uuid)
SET search_path = public;

ALTER FUNCTION public.get_my_businesses()
SET search_path = public;

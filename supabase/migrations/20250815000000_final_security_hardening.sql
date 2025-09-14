/*
          # [Operation Name] Final Security Hardening
          [This script safely applies the recommended 'search_path' setting to all custom database functions to resolve the final security warnings. It uses non-destructive ALTER FUNCTION commands.]

          ## Query Description: [This operation modifies the metadata of existing functions to improve security. It is a safe, non-destructive operation with no impact on data or application logic. No backup is required.]
          
          ## Metadata:
          - Schema-Category: ["Safe", "Structural"]
          - Impact-Level: ["Low"]
          - Requires-Backup: [false]
          - Reversible: [true]
          
          ## Structure Details:
          [Affects the 'search_path' configuration for: handle_new_user, is_business_member, get_dashboard_stats, invite_staff, create_sale_and_items, get_my_businesses, create_booking]
          
          ## Security Implications:
          - RLS Status: [Enabled]
          - Policy Changes: [No]
          - Auth Requirements: [None]
          
          ## Performance Impact:
          - Indexes: [None]
          - Triggers: [None]
          - Estimated Impact: [Negligible performance impact.]
          */

-- Set a secure search path for all custom functions to resolve security warnings.
-- This is a non-destructive operation.

ALTER FUNCTION public.handle_new_user() SET search_path = public;

ALTER FUNCTION public.is_business_member(uuid, uuid) SET search_path = public;

ALTER FUNCTION public.get_dashboard_stats(p_business_id uuid) SET search_path = public;

ALTER FUNCTION public.invite_staff(p_business_id uuid, p_invitee_email text, p_role public.staff_role_enum) SET search_path = public;

ALTER FUNCTION public.create_sale_and_items(p_business_id uuid, p_cashier_id uuid, p_items jsonb) SET search_path = public;

ALTER FUNCTION public.get_my_businesses() SET search_path = public;

ALTER FUNCTION public.create_booking(p_business_id uuid, p_guest_name text, p_guest_phone text, p_check_in_date date, p_check_out_date date, p_guests_count integer, p_total_amount numeric, p_room_id uuid, p_listing_id uuid) SET search_path = public;

/*
          # [Final Security Hardening]
          This migration applies the final security patches to all custom database functions by setting a fixed `search_path`. This is a non-destructive operation that resolves the "Function Search Path Mutable" security warnings.

          ## Query Description: [This operation will alter existing functions to enhance security. It is a safe, non-destructive update and does not affect any data or core logic. No backup is required.]
          
          ## Metadata:
          - Schema-Category: ["Safe", "Structural"]
          - Impact-Level: ["Low"]
          - Requires-Backup: false
          - Reversible: true
          
          ## Structure Details:
          - Affects functions: `create_booking`, `create_sale_and_items`, `get_dashboard_stats`, `get_my_businesses`, `invite_staff`, `is_business_member`
          
          ## Security Implications:
          - RLS Status: [Enabled]
          - Policy Changes: [No]
          - Auth Requirements: [None]
          
          ## Performance Impact:
          - Indexes: [None]
          - Triggers: [None]
          - Estimated Impact: [Negligible performance impact. This is a security-only change.]
          */

-- Set a secure search path for the 'create_booking' function.
ALTER FUNCTION public.create_booking(p_business_id uuid, p_guest_name text, p_guest_phone text, p_check_in_date date, p_check_out_date date, p_guests_count integer, p_total_amount numeric, p_room_id uuid, p_listing_id uuid)
SET search_path = public;

-- Set a secure search path for the 'create_sale_and_items' function.
ALTER FUNCTION public.create_sale_and_items(p_business_id uuid, p_cashier_id uuid, p_items jsonb)
SET search_path = public;

-- Set a secure search path for the 'get_dashboard_stats' function.
ALTER FUNCTION public.get_dashboard_stats(p_business_id uuid)
SET search_path = public;

-- Set a secure search path for the 'get_my_businesses' function.
ALTER FUNCTION public.get_my_businesses()
SET search_path = public;

-- Set a secure search path for the 'invite_staff' function.
ALTER FUNCTION public.invite_staff(p_business_id uuid, p_invitee_email text, p_role text)
SET search_path = public;

-- Set a secure search path for the 'is_business_member' function.
ALTER FUNCTION public.is_business_member(business_id uuid, user_id uuid)
SET search_path = public;

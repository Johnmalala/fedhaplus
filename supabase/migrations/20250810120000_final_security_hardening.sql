/*
          # [Final Security Hardening]
          This script addresses the final 'Function Search Path Mutable' security warnings by explicitly setting the search_path for all custom functions using the non-destructive ALTER FUNCTION command. This prevents potential security vulnerabilities without affecting existing data or policies.

          ## Query Description: [This is a safe, non-destructive operation that applies security best practices to your database functions. It makes your application more resilient to certain types of attacks.]
          
          ## Metadata:
          - Schema-Category: ["Safe", "Structural"]
          - Impact-Level: ["Low"]
          - Requires-Backup: false
          - Reversible: true
          
          ## Structure Details:
          - Alters the configuration of existing functions:
            - create_booking
            - create_sale_and_items
            - get_dashboard_stats
            - get_my_businesses
            - invite_staff
            - is_business_member
          
          ## Security Implications:
          - RLS Status: [Enabled]
          - Policy Changes: [No]
          - Auth Requirements: [None]
          
          ## Performance Impact:
          - Indexes: [None]
          - Triggers: [None]
          - Estimated Impact: [Negligible performance impact. This is a metadata change.]
          */

ALTER FUNCTION public.create_booking(p_business_id uuid, p_guest_name text, p_guest_phone text, p_check_in_date date, p_check_out_date date, p_guests_count integer, p_total_amount numeric, p_room_id uuid, p_listing_id uuid)
SET search_path = 'public';

ALTER FUNCTION public.create_sale_and_items(p_business_id uuid, p_cashier_id uuid, p_items jsonb)
SET search_path = 'public';

ALTER FUNCTION public.get_dashboard_stats(p_business_id uuid)
SET search_path = 'public';

ALTER FUNCTION public.get_my_businesses()
SET search_path = 'public';

ALTER FUNCTION public.invite_staff(p_business_id uuid, p_invitee_email text, p_role public.staff_role_enum)
SET search_path = 'public';

ALTER FUNCTION public.is_business_member(p_business_id uuid, p_user_id uuid)
SET search_path = 'public';

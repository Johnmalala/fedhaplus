/*
# [FINAL SECURITY FIX] Set Function Search Paths
This migration safely updates the remaining custom functions to set a non-mutable search_path.
This is a security best practice that prevents potential context-switching vulnerabilities.

## Query Description:
- This operation uses `ALTER FUNCTION` which is non-destructive and safe to run.
- It will not affect your data or the logic of the functions.
- It will resolve the final "Function Search Path Mutable" warnings from the Supabase security advisor.

## Metadata:
- Schema-Category: ["Safe", "Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: true (by altering the function again)

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: Supabase Admin
*/

-- Secure the create_sale_and_items function
ALTER FUNCTION public.create_sale_and_items(p_business_id uuid, p_cashier_id uuid, p_items jsonb)
SET search_path = public;

-- Secure the get_my_businesses function
ALTER FUNCTION public.get_my_businesses()
SET search_path = public;

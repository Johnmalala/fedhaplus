/*
# [Security Fix] Set Function Search Path
This migration fixes the remaining 'Function Search Path Mutable' security warnings by explicitly setting the search_path for custom functions. This is a security best practice to prevent potential schema-hijacking attacks.

## Query Description:
This operation uses `ALTER FUNCTION` to modify the configuration of existing functions. It is a non-destructive change and does not affect any data or table structures. It only enhances the security of the function execution environment.

## Metadata:
- Schema-Category: ["Safe", "Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: true (by altering the function again to reset the search_path)

## Structure Details:
- Functions affected:
  - `create_booking(uuid, text, text, text, text, integer, numeric, uuid, uuid)`
  - `create_sale_and_items(uuid, uuid, jsonb)`

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: None

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible.
*/

-- Secure the create_booking function
ALTER FUNCTION public.create_booking(p_business_id uuid, p_guest_name text, p_guest_phone text, p_check_in_date text, p_check_out_date text, p_guests_count integer, p_total_amount numeric, p_room_id uuid, p_listing_id uuid)
SET search_path = public;

-- Secure the create_sale_and_items function
ALTER FUNCTION public.create_sale_and_items(p_business_id uuid, p_cashier_id uuid, p_items jsonb)
SET search_path = public;

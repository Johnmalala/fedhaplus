/*
          # [Final Security Hardening]
          This script applies the final security settings to the remaining custom database functions by setting a fixed search_path. This is a non-destructive operation that resolves the "Function Search Path Mutable" security warnings.

          ## Query Description: [This operation alters existing functions to improve security. It is a safe, non-destructive change that does not affect data or application logic. No backup is required.]
          
          ## Metadata:
          - Schema-Category: ["Safe", "Structural"]
          - Impact-Level: ["Low"]
          - Requires-Backup: false
          - Reversible: true
          
          ## Structure Details:
          - Alters the `create_booking` function.
          - Alters the `create_sale_and_items` function.
          
          ## Security Implications:
          - RLS Status: [No Change]
          - Policy Changes: [No]
          - Auth Requirements: [None]
          
          ## Performance Impact:
          - Indexes: [No Change]
          - Triggers: [No Change]
          - Estimated Impact: [None]
          */

-- Secure the create_booking function
ALTER FUNCTION public.create_booking(uuid, text, text, date, date, integer, numeric, uuid, uuid) SET search_path = public;

-- Secure the create_sale_and_items function
ALTER FUNCTION public.create_sale_and_items(uuid, uuid, jsonb) SET search_path = public;

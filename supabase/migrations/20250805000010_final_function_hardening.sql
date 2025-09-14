/*
# [Function Hardening]
This migration secures the remaining database functions by setting a fixed, empty search_path. This is a critical security measure to prevent search path hijacking attacks.

## Query Description:
- This operation will safely drop and recreate the `get_dashboard_stats` function and update the `handle_new_user` function.
- It ensures these functions are not vulnerable to search path manipulation.
- There is no risk to existing data.

## Metadata:
- Schema-Category: "Safe"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (by reverting to the previous function definitions)

## Structure Details:
- Functions affected: `get_dashboard_stats`, `handle_new_user`

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: None
- Mitigates: Search path hijacking vulnerabilities.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible.
*/

-- Drop the function first to avoid return type conflicts
DROP FUNCTION IF EXISTS public.get_dashboard_stats(uuid);

-- Recreate get_dashboard_stats with a secure search path
CREATE OR REPLACE FUNCTION public.get_dashboard_stats(p_business_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    revenue_data json;
    customer_count int;
BEGIN
    -- Aggregate revenue data
    SELECT json_agg(json_build_object('amount', total_amount, 'created_at', created_at))
    INTO revenue_data
    FROM public.sales
    WHERE business_id = p_business_id;

    -- Get distinct customer count based on business type
    SELECT
        CASE
            WHEN (SELECT business_type FROM public.businesses WHERE id = p_business_id) = 'school'
                THEN (SELECT count(*) FROM public.students WHERE business_id = p_business_id AND is_active = true)
            WHEN (SELECT business_type FROM public.businesses WHERE id = p_business_id) = 'rentals'
                THEN (SELECT count(*) FROM public.tenants WHERE business_id = p_business_id AND is_active = true)
            ELSE (SELECT count(DISTINCT customer_phone) FROM public.sales WHERE business_id = p_business_id AND customer_phone IS NOT NULL)
        END
    INTO customer_count;

    RETURN json_build_object(
        'revenue_data', COALESCE(revenue_data, '[]'::json),
        'customer_count', COALESCE(customer_count, 0)
    );
END;
$$;


-- Recreate handle_new_user with a secure search path
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, phone)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.email,
    new.raw_user_meta_data->>'phone'
  );
  RETURN new;
END;
$$;

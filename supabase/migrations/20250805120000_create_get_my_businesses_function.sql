/*
# [Function] `get_my_businesses`
Creates a function to securely fetch all businesses a user is a member of.

## Query Description: 
This function provides a reliable way to get a user's associated businesses. It joins `businesses` and `staff_roles` and filters by the currently authenticated user's ID. Using `SECURITY DEFINER` ensures the function runs with the permissions of the function owner, bypassing potential RLS issues for the calling user while remaining secure due to the `auth.uid()` filter. This resolves issues where businesses might not be loaded correctly on the client side.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (the function can be dropped)

## Structure Details:
- Function: `public.get_my_businesses()`

## Security Implications:
- RLS Status: Not applicable to function directly, but it helps bypass client-side RLS complexities.
- Policy Changes: No
- Auth Requirements: Requires an authenticated user session (`auth.uid()`).

## Performance Impact:
- Indexes: Relies on existing indexes on `staff_roles(user_id)` and `businesses(id)`.
- Triggers: No
- Estimated Impact: Low. Improves data fetching performance and reliability.
*/
CREATE OR REPLACE FUNCTION public.get_my_businesses()
RETURNS SETOF public.businesses
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT b.*
    FROM public.businesses b
    JOIN public.staff_roles sr ON b.id = sr.business_id
    WHERE sr.user_id = auth.uid()
    ORDER BY b.created_at DESC;
END;
$$;

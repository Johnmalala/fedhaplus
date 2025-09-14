/*
# [Fix] Recreate create_booking function
This migration safely drops and recreates the `create_booking` function to resolve a return type conflict.

## Query Description:
This operation will temporarily drop the `create_booking` function and then immediately recreate it with the correct definition. This is necessary to align the database function with the application's expectations and will not result in data loss.

## Metadata:
- Schema-Category: ["Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Drops the existing `create_booking` function.
- Recreates the `create_booking` function with the correct return type and logic.

## Security Implications:
- RLS Status: [Enabled]
- Policy Changes: [No]
- Auth Requirements: [Authenticated users with business membership]

## Performance Impact:
- Indexes: [None]
- Triggers: [None]
- Estimated Impact: [Negligible impact on performance.]
*/

-- Drop the existing function to avoid signature conflicts as per the error hint
DROP FUNCTION IF EXISTS public.create_booking(uuid, text, text, date, date, integer, numeric, uuid, uuid);

-- Recreate the function with the correct definition and security settings
CREATE OR REPLACE FUNCTION public.create_booking(
    p_business_id uuid,
    p_guest_name text,
    p_guest_phone text,
    p_check_in_date date,
    p_check_out_date date,
    p_guests_count integer,
    p_total_amount numeric,
    p_room_id uuid,
    p_listing_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    new_booking_id uuid;
BEGIN
    -- Ensure the user is a member of the business
    IF NOT is_business_member(p_business_id, auth.uid()) THEN
        RAISE EXCEPTION 'User is not a member of this business';
    END IF;

    -- Insert the new booking
    INSERT INTO public.bookings (
        business_id,
        guest_name,
        guest_phone,
        check_in_date,
        check_out_date,
        guests_count,
        total_amount,
        paid_amount,
        booking_status,
        payment_status,
        room_id,
        listing_id
    )
    VALUES (
        p_business_id,
        p_guest_name,
        p_guest_phone,
        p_check_in_date,
        p_check_out_date,
        p_guests_count,
        p_total_amount,
        0, -- Initial paid amount is zero
        'Confirmed',
        'pending',
        p_room_id,
        p_listing_id
    )
    RETURNING id INTO new_booking_id;

    -- Update the status of the room or listing
    IF p_room_id IS NOT NULL THEN
        UPDATE public.rooms
        SET status = 'Occupied'
        WHERE id = p_room_id AND business_id = p_business_id;
    END IF;

    IF p_listing_id IS NOT NULL THEN
        UPDATE public.listings
        SET status = 'Booked'
        WHERE id = p_listing_id AND business_id = p_business_id;
    END IF;

END;
$$;

/*
# [Create Booking Function]
This script creates the `create_booking` function, which is required to add new bookings from the application. This function was missing, causing errors on the Bookings page.

## Query Description:
This operation is safe and non-destructive. It adds a new function to the database and does not affect existing data.

## Metadata:
- Schema-Category: ["Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Adds function: `public.create_booking`

## Security Implications:
- RLS Status: Not applicable
- Policy Changes: No
- Auth Requirements: The function internally checks for business membership.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Low
*/

-- Create the function to handle booking creation in a single transaction
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
BEGIN
  -- Check permissions: ensure the user is a member of the business
  IF NOT public.is_business_member(p_business_id, auth.uid()) THEN
    RAISE EXCEPTION 'User is not an active member of this business';
  END IF;

  -- Insert the new booking record
  INSERT INTO bookings (
    business_id, guest_name, guest_phone, check_in_date, check_out_date,
    guests_count, total_amount, paid_amount, booking_status, payment_status,
    room_id, listing_id
  ) VALUES (
    p_business_id, p_guest_name, p_guest_phone, p_check_in_date, p_check_out_date,
    p_guests_count, p_total_amount, 0, 'Confirmed', 'pending',
    p_room_id, p_listing_id
  );

  -- Update the status of the associated room or listing to prevent double-booking
  IF p_room_id IS NOT NULL THEN
    UPDATE rooms SET status = 'Occupied' WHERE id = p_room_id;
  ELSIF p_listing_id IS NOT NULL THEN
    UPDATE listings SET status = 'Booked' WHERE id = p_listing_id;
  END IF;
END;
$$;

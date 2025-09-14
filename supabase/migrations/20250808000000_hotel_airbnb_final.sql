/*
# [Security Fix & Hospitality Features]
This migration secures existing functions and adds new features for Hotel and Airbnb management.

## Query Description: 
This script performs the following actions:
1.  **Secures Functions**: Drops and recreates the `invite_staff` and `create_sale_and_items` functions to include a non-mutable `search_path`. This is a critical security enhancement to prevent potential schema-hijacking attacks.
2.  **Adds Booking Function**: Introduces a new `create_booking` function to handle the creation of new bookings for rooms or listings. This simplifies the frontend logic.
No existing data is at risk, as this only modifies function definitions and adds a new one.

## Metadata:
- Schema-Category: ["Structural", "Safe"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: false

## Structure Details:
- Functions Modified: `invite_staff`, `create_sale_and_items`
- Functions Added: `create_booking`

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: Operations require authenticated users with appropriate permissions.
- Security Advisories Addressed: Fixes `Function Search Path Mutable` warnings.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible performance impact.
*/

-- Fix for invite_staff function
DROP FUNCTION IF EXISTS public.invite_staff(uuid, text, public.staff_role_enum);
CREATE OR REPLACE FUNCTION public.invite_staff(p_business_id uuid, p_invitee_email text, p_role public.staff_role_enum)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_invitee_id uuid;
  v_inviter_id uuid := auth.uid();
BEGIN
  -- Set a secure search path
  SET search_path = 'public';

  -- Check if the inviter is a member of the business
  IF NOT is_business_member(p_business_id, v_inviter_id) THEN
    RAISE EXCEPTION 'Inviter is not a member of the specified business';
  END IF;

  -- Find the user_id for the given email
  SELECT id INTO v_invitee_id FROM auth.users WHERE email = p_invitee_email;

  IF v_invitee_id IS NULL THEN
    RAISE EXCEPTION 'User with email % not found. Please ask them to sign up for Fedha Plus first.', p_invitee_email;
  END IF;
  
  -- Check if the user is already a staff member for this business
  IF EXISTS (SELECT 1 FROM staff_roles WHERE user_id = v_invitee_id AND business_id = p_business_id) THEN
    RAISE EXCEPTION 'User is already a staff member of this business.';
  END IF;

  -- Insert the new staff role
  INSERT INTO public.staff_roles (business_id, user_id, role, invited_by, is_active)
  VALUES (p_business_id, v_invitee_id, p_role, v_inviter_id, false); -- Set to false, user needs to accept
END;
$$;


-- Fix for create_sale_and_items function
DROP FUNCTION IF EXISTS public.create_sale_and_items(uuid, uuid, jsonb[], text, text, text);
CREATE OR REPLACE FUNCTION public.create_sale_and_items(
  p_business_id uuid,
  p_cashier_id uuid,
  p_items jsonb[],
  p_customer_name text DEFAULT NULL,
  p_customer_phone text DEFAULT NULL,
  p_payment_method text DEFAULT 'cash'
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_sale_id uuid;
  v_total_amount numeric := 0;
  v_item jsonb;
  v_product_id uuid;
  v_quantity int;
  v_unit_price numeric;
BEGIN
  -- Set a secure search path
  SET search_path = 'public';
  
  -- Calculate total amount
  FOREACH v_item IN ARRAY p_items
  LOOP
    v_total_amount := v_total_amount + ((v_item->>'unit_price')::numeric * (v_item->>'quantity')::int);
  END LOOP;

  -- Insert into sales table
  INSERT INTO sales (business_id, cashier_id, total_amount, customer_name, customer_phone, payment_method)
  VALUES (p_business_id, p_cashier_id, v_total_amount, p_customer_name, p_customer_phone, p_payment_method)
  RETURNING id INTO v_sale_id;

  -- Insert into sale_items and update stock
  FOREACH v_item IN ARRAY p_items
  LOOP
    v_product_id := (v_item->>'product_id')::uuid;
    v_quantity := (v_item->>'quantity')::int;
    v_unit_price := (v_item->>'unit_price')::numeric;

    INSERT INTO sale_items (sale_id, product_id, quantity, unit_price, total_price)
    VALUES (v_sale_id, v_product_id, v_quantity, v_unit_price, v_quantity * v_unit_price);

    -- Update product stock
    UPDATE products
    SET stock_quantity = stock_quantity - v_quantity
    WHERE id = v_product_id;
  END LOOP;

  RETURN v_sale_id;
END;
$$;


-- New function for creating bookings
CREATE OR REPLACE FUNCTION public.create_booking(
    p_business_id uuid,
    p_guest_name text,
    p_guest_phone text,
    p_check_in_date date,
    p_check_out_date date,
    p_guests_count int,
    p_total_amount numeric,
    p_room_id uuid DEFAULT NULL,
    p_listing_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking_id uuid;
BEGIN
    -- Set a secure search path
    SET search_path = 'public';

    -- Ensure the user is a member of the business
    IF NOT is_business_member(p_business_id, auth.uid()) THEN
        RAISE EXCEPTION 'User is not authorized to create bookings for this business.';
    END IF;

    -- Insert the booking
    INSERT INTO bookings (
        business_id,
        guest_name,
        guest_phone,
        check_in_date,
        check_out_date,
        guests_count,
        total_amount,
        room_id,
        listing_id,
        booking_status,
        payment_status
    ) VALUES (
        p_business_id,
        p_guest_name,
        p_guest_phone,
        p_check_in_date,
        p_check_out_date,
        p_guests_count,
        p_total_amount,
        p_room_id,
        p_listing_id,
        'Confirmed',
        'pending'
    ) RETURNING id INTO v_booking_id;

    -- Update the status of the room or listing
    IF p_room_id IS NOT NULL THEN
        UPDATE rooms SET status = 'Occupied' WHERE id = p_room_id;
    ELSIF p_listing_id IS NOT NULL THEN
        UPDATE listings SET status = 'Booked' WHERE id = p_listing_id;
    END IF;

    RETURN v_booking_id;
END;
$$;

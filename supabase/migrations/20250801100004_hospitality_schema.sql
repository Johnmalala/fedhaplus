/*
          # [Hospitality Schema Setup]
          This script creates tables for Hospitality businesses like Hotels and Airbnbs.

          ## Query Description: "This operation adds 'rooms' and 'bookings' tables for hospitality management. It will not affect existing data."
          
          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: false
          
          ## Structure Details:
          - Tables Created: rooms, bookings
          
          ## Security Implications:
          - RLS Status: Enabled
          - Policy Changes: No
          - Auth Requirements: None
          
          ## Performance Impact:
          - Indexes: Primary and foreign keys are indexed.
          - Triggers: None
          - Estimated Impact: Low.
          */

-- 1. ROOMS TABLE
CREATE TABLE IF NOT EXISTS public.rooms (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    room_number text NOT NULL,
    room_type text,
    capacity integer,
    rate_per_night numeric,
    description text,
    amenities text[],
    status text,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.rooms IS 'Stores room information for hotels or rentals.';

-- 2. BOOKINGS TABLE
CREATE TABLE IF NOT EXISTS public.bookings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    room_id uuid REFERENCES public.rooms(id),
    guest_name text NOT NULL,
    guest_phone text,
    guest_email text,
    check_in_date date NOT NULL,
    check_out_date date NOT NULL,
    guests_count integer,
    total_amount numeric,
    paid_amount numeric,
    booking_status text,
    payment_status text,
    notes text,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.bookings IS 'Records guest bookings.';

-- 3. ENABLE RLS
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

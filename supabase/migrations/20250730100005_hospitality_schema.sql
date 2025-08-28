/*
          # [Hospitality Schema]
          Creates tables for Hotel and Airbnb management.

          ## Query Description: This script adds tables for managing rooms and bookings, specific to the "Hotel" and "Airbnb" business types.

          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true

          ## Structure Details:
          - Tables Created: `rooms`, `bookings`

          ## Security Implications:
          - RLS Status: Disabled (will be enabled in a later script)
          - Policy Changes: No
          - Auth Requirements: None

          ## Performance Impact:
          - Indexes: Primary keys and foreign keys are indexed.
          - Triggers: None.
          - Estimated Impact: Low.
          */

-- 1. Rooms Table
CREATE TABLE IF NOT EXISTS public.rooms (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    room_number text NOT NULL,
    room_type text,
    capacity integer,
    rate_per_night numeric(10, 2) NOT NULL,
    description text,
    amenities text[],
    status text DEFAULT 'available',
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 2. Bookings Table
CREATE TABLE IF NOT EXISTS public.bookings (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    room_id uuid REFERENCES public.rooms(id),
    guest_name text NOT NULL,
    guest_phone character varying(20) NOT NULL,
    guest_email character varying(255),
    check_in_date timestamp with time zone NOT NULL,
    check_out_date timestamp with time zone NOT NULL,
    guests_count integer,
    total_amount numeric(10, 2) NOT NULL,
    paid_amount numeric(10, 2) DEFAULT 0,
    booking_status text DEFAULT 'confirmed',
    payment_status text DEFAULT 'pending',
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

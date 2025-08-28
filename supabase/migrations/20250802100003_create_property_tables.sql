/*
          # [Operation Name] Create Property Management Tables
          [This script creates tables for property management businesses like Rentals, Airbnb, and Hotels.]

          ## Query Description: [This operation adds 'tenants', 'rent_payments', 'rooms', and 'bookings' tables. It is a structural change and will not affect existing data. It is safe to run.]
          
          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true
          
          ## Structure Details:
          - Tables Created: tenants, rent_payments, rooms, bookings
          - Columns Added: All columns for the respective tables
          - Constraints Added: Primary keys, foreign keys
          
          ## Security Implications:
          - RLS Status: Disabled by default
          - Policy Changes: No
          - Auth Requirements: None for creation
          
          ## Performance Impact:
          - Indexes: Primary key indexes are created automatically.
          - Triggers: None
          - Estimated Impact: Low.
          */
CREATE TABLE IF NOT EXISTS public.tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(255),
    id_number VARCHAR(50),
    unit_number VARCHAR(50) NOT NULL,
    rent_amount NUMERIC(10, 2) NOT NULL,
    deposit_amount NUMERIC(10, 2),
    lease_start DATE NOT NULL,
    lease_end DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.rent_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL,
    payment_date DATE NOT NULL,
    payment_method VARCHAR(50),
    status VARCHAR(50) DEFAULT 'paid',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    room_number VARCHAR(50) NOT NULL,
    room_type VARCHAR(100),
    capacity INT,
    rate_per_night NUMERIC(10, 2) NOT NULL,
    description TEXT,
    amenities TEXT[],
    status VARCHAR(50) DEFAULT 'available',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    room_id UUID REFERENCES public.rooms(id),
    guest_name VARCHAR(255) NOT NULL,
    guest_phone VARCHAR(20) NOT NULL,
    guest_email VARCHAR(255),
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    guests_count INT,
    total_amount NUMERIC(10, 2),
    paid_amount NUMERIC(10, 2),
    booking_status VARCHAR(50) DEFAULT 'confirmed',
    payment_status VARCHAR(50) DEFAULT 'pending',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

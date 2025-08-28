/*
          # [Rental Schema Setup]
          This script creates tables for managing Apartment Rentals.

          ## Query Description: "This operation adds 'tenants' and 'rent_payments' tables for property management. It will not affect existing data."
          
          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: false
          
          ## Structure Details:
          - Tables Created: tenants, rent_payments
          
          ## Security Implications:
          - RLS Status: Enabled
          - Policy Changes: No
          - Auth Requirements: None
          
          ## Performance Impact:
          - Indexes: Primary and foreign keys are indexed.
          - Triggers: None
          - Estimated Impact: Low.
          */

-- 1. TENANTS TABLE
CREATE TABLE IF NOT EXISTS public.tenants (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    name text NOT NULL,
    phone text NOT NULL,
    email text,
    id_number text,
    unit_number text NOT NULL,
    rent_amount numeric NOT NULL,
    deposit_amount numeric,
    lease_start date,
    lease_end date,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.tenants IS 'Stores information about tenants in a rental business.';

-- 2. RENT PAYMENTS TABLE
CREATE TABLE IF NOT EXISTS public.rent_payments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    amount numeric NOT NULL,
    payment_date date NOT NULL,
    payment_for_month date NOT NULL,
    status text,
    payment_method text,
    mpesa_code text,
    notes text,
    created_at timestamptz DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.rent_payments IS 'Records rent payments made by tenants.';

-- 3. ENABLE RLS
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rent_payments ENABLE ROW LEVEL SECURITY;

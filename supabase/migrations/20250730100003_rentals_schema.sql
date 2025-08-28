/*
          # [Rentals Schema]
          Creates tables for property rental management.

          ## Query Description: This script adds tables for managing tenants and their rent payments, specific to the "Rentals" business type.

          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true

          ## Structure Details:
          - Tables Created: `tenants`, `rent_payments`

          ## Security Implications:
          - RLS Status: Disabled (will be enabled in a later script)
          - Policy Changes: No
          - Auth Requirements: None

          ## Performance Impact:
          - Indexes: Primary keys and foreign keys are indexed.
          - Triggers: None.
          - Estimated Impact: Low.
          */

-- 1. Tenants Table
CREATE TABLE IF NOT EXISTS public.tenants (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    name text NOT NULL,
    phone character varying(20) NOT NULL,
    email character varying(255),
    id_number text,
    unit_number text NOT NULL,
    rent_amount numeric(10, 2) NOT NULL,
    deposit_amount numeric(10, 2),
    lease_start date,
    lease_end date,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 2. Rent Payments Table
CREATE TABLE IF NOT EXISTS public.rent_payments (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    amount numeric(10, 2) NOT NULL,
    payment_date date NOT NULL,
    payment_for_month date NOT NULL,
    status text NOT NULL CHECK (status IN ('pending', 'paid', 'overdue', 'cancelled')),
    payment_method text,
    mpesa_code text,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

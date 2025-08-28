/*
          # [School Schema]
          Creates tables for school management.

          ## Query Description: This script adds tables for managing students and their fee payments, specific to the "School" business type.

          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true

          ## Structure Details:
          - Tables Created: `students`, `fee_payments`

          ## Security Implications:
          - RLS Status: Disabled (will be enabled in a later script)
          - Policy Changes: No
          - Auth Requirements: None

          ## Performance Impact:
          - Indexes: Primary keys and foreign keys are indexed.
          - Triggers: None.
          - Estimated Impact: Low.
          */

-- 1. Students Table
CREATE TABLE IF NOT EXISTS public.students (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    admission_number text UNIQUE NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    date_of_birth date,
    class_level text NOT NULL,
    parent_name text NOT NULL,
    parent_phone character varying(20) NOT NULL,
    parent_email character varying(255),
    address text,
    fee_amount numeric(10, 2) NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 2. Fee Payments Table
CREATE TABLE IF NOT EXISTS public.fee_payments (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    amount numeric(10, 2) NOT NULL,
    payment_date date NOT NULL,
    term text NOT NULL,
    status text NOT NULL CHECK (status IN ('pending', 'paid', 'overdue', 'cancelled')),
    payment_method text,
    mpesa_code text,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

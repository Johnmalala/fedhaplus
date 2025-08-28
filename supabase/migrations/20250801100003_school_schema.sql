/*
          # [School Schema Setup]
          This script creates tables for School Management.

          ## Query Description: "This operation adds 'students' and 'fee_payments' tables for school administration. It will not affect existing data."
          
          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: false
          
          ## Structure Details:
          - Tables Created: students, fee_payments
          
          ## Security Implications:
          - RLS Status: Enabled
          - Policy Changes: No
          - Auth Requirements: None
          
          ## Performance Impact:
          - Indexes: Primary and foreign keys are indexed.
          - Triggers: None
          - Estimated Impact: Low.
          */

-- 1. STUDENTS TABLE
CREATE TABLE IF NOT EXISTS public.students (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    admission_number text UNIQUE NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    date_of_birth date,
    class_level text,
    parent_name text,
    parent_phone text,
    parent_email text,
    address text,
    fee_amount numeric,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.students IS 'Stores student information for a school.';

-- 2. FEE PAYMENTS TABLE
CREATE TABLE IF NOT EXISTS public.fee_payments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    amount numeric NOT NULL,
    payment_date date NOT NULL,
    term text,
    status text,
    payment_method text,
    mpesa_code text,
    notes text,
    created_at timestamptz DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.fee_payments IS 'Records school fee payments made for students.';

-- 3. ENABLE RLS
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fee_payments ENABLE ROW LEVEL SECURITY;

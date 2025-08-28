/*
          # [Operation Name] Create School Management Tables
          [This script creates tables required for School Management businesses.]

          ## Query Description: [This operation adds 'students' and 'fee_payments' tables. It is a structural change and will not affect existing data. It is safe to run.]
          
          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true
          
          ## Structure Details:
          - Tables Created: students, fee_payments
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
CREATE TABLE IF NOT EXISTS public.students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    admission_number VARCHAR(50) UNIQUE NOT NULL,
    first_name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255) NOT NULL,
    date_of_birth DATE,
    class_level VARCHAR(50),
    parent_name VARCHAR(255),
    parent_phone VARCHAR(20),
    parent_email VARCHAR(255),
    address TEXT,
    fee_amount NUMERIC(10, 2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.fee_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL,
    payment_date DATE NOT NULL,
    payment_method VARCHAR(50),
    status VARCHAR(50) DEFAULT 'paid',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

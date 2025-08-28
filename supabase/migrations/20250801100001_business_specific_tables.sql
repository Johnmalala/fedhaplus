/*
          # Operation: Business-Specific Tables
          [This script creates all the tables required for the different business types, such as products, sales, tenants, students, etc.]

          ## Query Description: [This operation adds the data tables needed for the application to function. It includes tables for sales, inventory, tenants, students, and bookings. It's safe to run as it only creates new tables and does not modify existing data.]
          
          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Medium"
          - Requires-Backup: false
          - Reversible: true
          
          ## Structure Details:
          - Tables Created: products, sales, sale_items, tenants, rent_payments, students, fee_payments, rooms, bookings
          - Types Created: payment_status_enum
          
          ## Security Implications:
          - RLS Status: Disabled (will be enabled in a later script)
          - Policy Changes: No
          - Auth Requirements: None for this script.
          
          ## Performance Impact:
          - Indexes: Foreign keys will be indexed.
          - Triggers: None.
          - Estimated Impact: Low.
          */

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status_enum') THEN
        CREATE TYPE payment_status_enum AS ENUM ('pending', 'paid', 'overdue', 'cancelled');
    END IF;
END
$$;

-- Hardware & Supermarket Tables
CREATE TABLE IF NOT EXISTS public.products (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    name text NOT NULL,
    description text,
    sku text,
    category text,
    buying_price numeric,
    selling_price numeric NOT NULL,
    stock_quantity integer DEFAULT 0,
    min_stock_level integer DEFAULT 0,
    unit text,
    image_url text,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sales (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    cashier_id uuid REFERENCES public.profiles(id),
    customer_name text,
    customer_phone text,
    total_amount numeric NOT NULL,
    payment_method text,
    mpesa_code text,
    notes text,
    receipt_number text,
    created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sale_items (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    sale_id uuid NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id),
    quantity integer NOT NULL,
    unit_price numeric NOT NULL,
    total_price numeric NOT NULL
);

-- Rentals Tables
CREATE TABLE IF NOT EXISTS public.tenants (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
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
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.rent_payments (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    amount numeric NOT NULL,
    payment_date date NOT NULL,
    month_of_payment date NOT NULL,
    status payment_status_enum DEFAULT 'paid',
    created_at timestamp with time zone DEFAULT now()
);

-- School Tables
CREATE TABLE IF NOT EXISTS public.students (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    admission_number text UNIQUE,
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
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.fee_payments (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    amount numeric NOT NULL,
    payment_date date NOT NULL,
    term text,
    status payment_status_enum DEFAULT 'paid',
    created_at timestamp with time zone DEFAULT now()
);

-- Hotel & Airbnb Tables
CREATE TABLE IF NOT EXISTS public.rooms (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    room_number text NOT NULL,
    room_type text,
    capacity integer,
    rate_per_night numeric,
    description text,
    amenities text[],
    status text,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.bookings (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    room_id uuid REFERENCES public.rooms(id),
    guest_name text NOT NULL,
    guest_phone text,
    guest_email text,
    check_in_date date,
    check_out_date date,
    guests_count integer,
    total_amount numeric,
    paid_amount numeric DEFAULT 0,
    booking_status text,
    payment_status payment_status_enum,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

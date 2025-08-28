/*
          # [Commerce Schema]
          Creates tables for e-commerce functionality (Hardware & Supermarket).

          ## Query Description: This script adds tables required for managing products, sales, and sale items. This is essential for the Hardware and Supermarket business types.

          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true

          ## Structure Details:
          - Tables Created: `products`, `sales`, `sale_items`

          ## Security Implications:
          - RLS Status: Disabled (will be enabled in a later script)
          - Policy Changes: No
          - Auth Requirements: None

          ## Performance Impact:
          - Indexes: Primary keys and foreign keys are indexed.
          - Triggers: None.
          - Estimated Impact: Low.
          */

-- 1. Products Table
CREATE TABLE IF NOT EXISTS public.products (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    name text NOT NULL,
    description text,
    sku text,
    category text,
    buying_price numeric(10, 2),
    selling_price numeric(10, 2) NOT NULL,
    stock_quantity integer NOT NULL DEFAULT 0,
    min_stock_level integer DEFAULT 0,
    unit text,
    image_url text,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 2. Sales Table
CREATE TABLE IF NOT EXISTS public.sales (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    cashier_id uuid REFERENCES public.profiles(id),
    customer_name text,
    customer_phone character varying(20),
    total_amount numeric(10, 2) NOT NULL,
    payment_method text NOT NULL,
    mpesa_code text,
    notes text,
    receipt_number text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 3. Sale Items Table
CREATE TABLE IF NOT EXISTS public.sale_items (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    sale_id uuid NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id),
    quantity integer NOT NULL,
    unit_price numeric(10, 2) NOT NULL,
    total_price numeric(10, 2) NOT NULL
);

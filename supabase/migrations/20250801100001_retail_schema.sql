/*
          # [Retail Schema Setup]
          This script creates the tables required for retail-based businesses like Hardware Shops and Supermarkets.

          ## Query Description: "This operation adds tables for 'products', 'sales', and 'sale_items' to support retail functionality. It is designed for businesses managing inventory and sales transactions. It will not affect existing data."
          
          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: false
          
          ## Structure Details:
          - Tables Created: products, sales, sale_items
          
          ## Security Implications:
          - RLS Status: Enabled
          - Policy Changes: No
          - Auth Requirements: None
          
          ## Performance Impact:
          - Indexes: Primary and foreign keys are indexed.
          - Triggers: None
          - Estimated Impact: Low.
          */

-- 1. PRODUCTS TABLE
CREATE TABLE IF NOT EXISTS public.products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    name text NOT NULL,
    description text,
    sku text,
    category text,
    buying_price numeric,
    selling_price numeric NOT NULL,
    stock_quantity integer DEFAULT 0 NOT NULL,
    min_stock_level integer DEFAULT 0,
    unit text,
    image_url text,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.products IS 'Stores product and inventory information.';

-- 2. SALES TABLE
CREATE TABLE IF NOT EXISTS public.sales (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    cashier_id uuid REFERENCES public.profiles(id),
    customer_name text,
    customer_phone text,
    total_amount numeric NOT NULL,
    payment_method text NOT NULL,
    mpesa_code text,
    notes text,
    receipt_number text,
    created_at timestamptz DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.sales IS 'Records each sales transaction.';

-- 3. SALE ITEMS TABLE
CREATE TABLE IF NOT EXISTS public.sale_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    sale_id uuid NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id),
    quantity integer NOT NULL,
    unit_price numeric NOT NULL,
    total_price numeric NOT NULL
);
COMMENT ON TABLE public.sale_items IS 'Details of items included in a sale.';

-- 4. ENABLE RLS
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;

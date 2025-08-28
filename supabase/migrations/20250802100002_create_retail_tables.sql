/*
          # [Operation Name] Create Retail-Specific Tables
          [This script creates tables required for retail-oriented businesses like Hardware shops and Supermarkets.]

          ## Query Description: [This operation adds 'products', 'sales', and 'sale_items' tables. It is a structural change and will not affect existing data. It is safe to run.]
          
          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true
          
          ## Structure Details:
          - Tables Created: products, sales, sale_items
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
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    sku VARCHAR(100),
    category VARCHAR(100),
    buying_price NUMERIC(10, 2),
    selling_price NUMERIC(10, 2) NOT NULL,
    stock_quantity INT NOT NULL DEFAULT 0,
    min_stock_level INT DEFAULT 0,
    unit VARCHAR(50),
    image_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.sales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    cashier_id UUID REFERENCES public.profiles(id),
    customer_name VARCHAR(255),
    customer_phone VARCHAR(20),
    total_amount NUMERIC(10, 2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    mpesa_code VARCHAR(50),
    notes TEXT,
    receipt_number VARCHAR(100) UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.sale_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sale_id UUID NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id),
    quantity INT NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,
    total_price NUMERIC(10, 2) NOT NULL
);

/*
          # [Operation Name] Create Core Tables
          [This script creates the essential tables for user profiles and business management, which are the foundation of the application.]

          ## Query Description: [This operation creates the 'profiles' and 'businesses' tables. It is a structural change and is safe to run on a new database. It does not affect any existing data as it only creates new structures.]
          
          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true
          
          ## Structure Details:
          - Tables Created: profiles, businesses
          - Columns Added: All columns for the respective tables
          - Constraints Added: Primary keys, foreign keys
          
          ## Security Implications:
          - RLS Status: Disabled by default on new tables
          - Policy Changes: No
          - Auth Requirements: None for creation
          
          ## Performance Impact:
          - Indexes: Primary key indexes are created automatically.
          - Triggers: None
          - Estimated Impact: Low. Simple table creations.
          */
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    full_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.businesses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    business_type VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    phone VARCHAR(20),
    location VARCHAR(255),
    logo_url TEXT,
    settings JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

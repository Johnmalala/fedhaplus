/*
          # Operation: Initial Schema Setup
          [This script creates the core tables for user profiles, businesses, and staff roles. It also sets up the necessary business type and staff role enums.]

          ## Query Description: [This operation establishes the foundational structure of your database. It creates the main tables that will hold user and business information. There is no risk to existing data as these tables are being created for the first time. This script is safe to run on a new database.]
          
          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true
          
          ## Structure Details:
          - Tables Created: profiles, businesses, staff_roles
          - Types Created: business_type_enum, staff_role_enum
          
          ## Security Implications:
          - RLS Status: Disabled (will be enabled in a later script)
          - Policy Changes: No
          - Auth Requirements: None for this script.
          
          ## Performance Impact:
          - Indexes: Primary keys are automatically indexed.
          - Triggers: A trigger is added to create a user profile automatically.
          - Estimated Impact: Low. Initial table creation has minimal performance impact.
          */

-- Create custom types for business and staff roles
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'business_type_enum') THEN
        CREATE TYPE business_type_enum AS ENUM ('hardware', 'supermarket', 'rentals', 'airbnb', 'hotel', 'school');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'staff_role_enum') THEN
        CREATE TYPE staff_role_enum AS ENUM ('owner', 'manager', 'cashier', 'accountant', 'teacher', 'front_desk', 'housekeeper');
    END IF;
END
$$;

-- Create profiles table to store user data
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name text,
    phone text,
    email text,
    updated_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now()
);
COMMENT ON TABLE public.profiles IS 'Stores public profile information for each user.';

-- Function to create a profile for a new user
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, email)
    VALUES (new.id, new.raw_user_meta_data->>'full_name', new.email);
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to call the function when a new user signs up
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create businesses table
CREATE TABLE IF NOT EXISTS public.businesses (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    business_type business_type_enum NOT NULL,
    name text NOT NULL,
    description text,
    phone text,
    location text,
    logo_url text,
    settings jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);
COMMENT ON TABLE public.businesses IS 'Stores information about each business owned by a user.';

-- Create staff_roles table
CREATE TABLE IF NOT EXISTS public.staff_roles (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role staff_role_enum NOT NULL,
    permissions jsonb,
    invited_by uuid REFERENCES public.profiles(id),
    invited_at timestamp with time zone DEFAULT now(),
    is_active boolean DEFAULT true,
    UNIQUE(business_id, user_id)
);
COMMENT ON TABLE public.staff_roles IS 'Assigns roles to users for specific businesses.';

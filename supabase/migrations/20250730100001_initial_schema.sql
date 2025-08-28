/*
          # [Initial Schema]
          Creates the core tables for user profiles and businesses.

          ## Query Description: This script sets up the foundational tables for the application. It includes the `profiles` table to store user data linked to Supabase Auth and the `businesses` table to store information about each business created by a user. It also includes a trigger to automatically create a user profile upon successful sign-up.

          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true

          ## Structure Details:
          - Tables Created: `profiles`, `businesses`
          - Functions Created: `handle_new_user()`
          - Triggers Created: on `auth.users`

          ## Security Implications:
          - RLS Status: Disabled (will be enabled in a later script)
          - Policy Changes: No
          - Auth Requirements: None

          ## Performance Impact:
          - Indexes: Primary keys and foreign keys are indexed.
          - Triggers: Adds a trigger to `auth.users`.
          - Estimated Impact: Low.
          */

-- 1. Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email character varying(255) UNIQUE,
    phone character varying(20),
    full_name text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.profiles IS 'Stores public user profile information.';

-- 2. Businesses Table
CREATE TABLE IF NOT EXISTS public.businesses (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    business_type text NOT NULL CHECK (business_type IN ('hardware', 'supermarket', 'rentals', 'airbnb', 'hotel', 'school')),
    name text NOT NULL,
    description text,
    phone character varying(20),
    location text,
    logo_url text,
    settings jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.businesses IS 'Stores information about each business entity.';

-- 3. Function to create a profile for a new user
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email)
  VALUES (new.id, new.raw_user_meta_data->>'full_name', new.email);
  RETURN new;
END;
$$;

-- 4. Trigger to call the function on new user creation
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

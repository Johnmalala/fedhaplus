/*
          # [Operation Name] Create User Profile Trigger
          [This script sets up an automation that creates a new user profile in the 'profiles' table whenever a new user signs up and confirms their email.]

          ## Query Description: [This operation creates a trigger function that automatically populates the 'profiles' table from 'auth.users'. This ensures data consistency between authentication and user data. It is safe to run and will not affect existing users, only new sign-ups.]
          
          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true
          
          ## Structure Details:
          - Functions Created: handle_new_user
          - Triggers Created: on_auth_user_created on auth.users
          
          ## Security Implications:
          - RLS Status: Not applicable to triggers
          - Policy Changes: No
          - Auth Requirements: The trigger fires based on Supabase Auth events.
          
          ## Performance Impact:
          - Indexes: None
          - Triggers: Adds a trigger to the auth.users table, which has a negligible impact on insert performance.
          - Estimated Impact: Low.
          */
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (new.id, new.email, new.raw_user_meta_data->>'full_name');
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

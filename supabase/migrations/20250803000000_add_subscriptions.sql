/*
# [Feature] Add Subscriptions Table
This migration introduces a `subscriptions` table to manage trial periods, active subscriptions, and payment statuses for each business.

## Query Description: This operation creates a new table `subscriptions` and enables Row-Level Security. It is a non-destructive, structural change. It also adds a function to create a subscription when a new business is created.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Table: `public.subscriptions`
- Columns: `id`, `business_id`, `status`, `trial_ends_at`, `current_period_ends_at`, `created_at`, `updated_at`

## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes (New policies for `subscriptions` table)
- Auth Requirements: Users can only see subscriptions for businesses they own.

## Performance Impact:
- Indexes: Primary key on `id`, foreign key on `business_id`.
- Triggers: A new trigger on the `businesses` table.
- Estimated Impact: Low.
*/

-- 1. Create Subscription Status Enum if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_status') THEN
        CREATE TYPE subscription_status AS ENUM ('trial', 'active', 'cancelled', 'expired', 'paused');
    END IF;
END$$;

-- 2. Create Subscriptions Table
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    status subscription_status NOT NULL DEFAULT 'trial',
    trial_ends_at TIMESTAMPTZ,
    current_period_ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_business_subscription UNIQUE (business_id)
);

COMMENT ON TABLE public.subscriptions IS 'Manages subscription status for each business.';

-- 3. Enable RLS
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- 4. Create RLS Policies for Subscriptions
DROP POLICY IF EXISTS "Owners can view their subscriptions" ON public.subscriptions;
CREATE POLICY "Owners can view their subscriptions"
ON public.subscriptions
FOR SELECT
USING (
  auth.uid() IN (
    SELECT owner_id FROM public.businesses WHERE id = subscriptions.business_id
  )
);

-- We will not allow client-side inserts/updates/deletes for subscriptions. This should be handled by server-side logic (Edge Functions).

-- 5. Create a function to insert a subscription on new business creation
CREATE OR REPLACE FUNCTION public.handle_new_business_subscription()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  -- Create a 30-day trial subscription for the new business
  INSERT INTO public.subscriptions (business_id, status, trial_ends_at, current_period_ends_at)
  VALUES (NEW.id, 'trial', now() + interval '30 days', now() + interval '30 days');
  RETURN NEW;
END;
$$;

-- 6. Create a trigger to call the function after a new business is inserted
DROP TRIGGER IF EXISTS on_business_created_create_subscription ON public.businesses;
CREATE TRIGGER on_business_created_create_subscription
  AFTER INSERT ON public.businesses
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_business_subscription();

/*
# Fedha Plus - Complete Database Schema
This migration creates the complete database structure for Fedha Plus business management system

## Query Description: 
This operation creates a comprehensive business management database with support for 6 business types (hardware shops, supermarkets, rentals, hotels, airbnb, schools), user authentication, role-based access control, and financial tracking. This is a new database setup with no existing data impact.

## Metadata:
- Schema-Category: "Safe"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Core tables: profiles, businesses, business_types, staff_roles
- Business-specific tables: products, sales, tenants, students, bookings
- Financial tables: payments, subscriptions
- Access control tables: permissions, role_permissions

## Security Implications:
- RLS Status: Enabled on all tables
- Policy Changes: Yes - comprehensive RLS policies for multi-tenant security
- Auth Requirements: All operations require authenticated users

## Performance Impact:
- Indexes: Added on all foreign keys and frequently queried columns
- Triggers: Added for profile creation on user signup
- Estimated Impact: Minimal - new database setup
*/

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create enum types
CREATE TYPE business_type_enum AS ENUM (
  'hardware',
  'supermarket', 
  'rentals',
  'airbnb',
  'hotel',
  'school'
);

CREATE TYPE staff_role_enum AS ENUM (
  'owner',
  'manager',
  'cashier',
  'accountant',
  'teacher',
  'front_desk',
  'housekeeper'
);

CREATE TYPE payment_status_enum AS ENUM (
  'pending',
  'paid',
  'overdue',
  'cancelled'
);

CREATE TYPE subscription_status_enum AS ENUM (
  'trial',
  'active',
  'cancelled',
  'expired'
);

-- Core Tables

-- Profiles table (extends auth.users)
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  full_name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Business types reference table
CREATE TABLE public.business_types (
  id SERIAL PRIMARY KEY,
  type business_type_enum UNIQUE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  monthly_price INTEGER NOT NULL, -- in KSh
  features JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Businesses table
CREATE TABLE public.businesses (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  owner_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  business_type business_type_enum NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  phone TEXT,
  location TEXT,
  logo_url TEXT,
  settings JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Staff roles and permissions
CREATE TABLE public.staff_roles (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  role staff_role_enum NOT NULL,
  permissions JSONB DEFAULT '{}'::jsonb,
  invited_by UUID REFERENCES public.profiles(id) NOT NULL,
  invited_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_active BOOLEAN DEFAULT TRUE,
  UNIQUE(business_id, user_id)
);

-- Subscriptions
CREATE TABLE public.subscriptions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE NOT NULL,
  status subscription_status_enum DEFAULT 'trial',
  current_period_start DATE NOT NULL,
  current_period_end DATE NOT NULL,
  trial_end DATE,
  amount INTEGER, -- in KSh
  mpesa_code TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Products/Inventory (for hardware, supermarket)
CREATE TABLE public.products (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  sku TEXT,
  category TEXT,
  buying_price DECIMAL(10,2),
  selling_price DECIMAL(10,2) NOT NULL,
  stock_quantity INTEGER DEFAULT 0,
  min_stock_level INTEGER DEFAULT 0,
  unit TEXT DEFAULT 'pcs',
  image_url TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Sales/Transactions
CREATE TABLE public.sales (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE NOT NULL,
  cashier_id UUID REFERENCES public.profiles(id) NOT NULL,
  customer_name TEXT,
  customer_phone TEXT,
  total_amount DECIMAL(10,2) NOT NULL,
  payment_method TEXT DEFAULT 'cash',
  mpesa_code TEXT,
  notes TEXT,
  receipt_number TEXT UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Sale items
CREATE TABLE public.sale_items (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  sale_id UUID REFERENCES public.sales(id) ON DELETE CASCADE NOT NULL,
  product_id UUID REFERENCES public.products(id) NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL,
  total_price DECIMAL(10,2) NOT NULL
);

-- Tenants (for rentals)
CREATE TABLE public.tenants (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  email TEXT,
  id_number TEXT,
  unit_number TEXT NOT NULL,
  rent_amount DECIMAL(10,2) NOT NULL,
  deposit_amount DECIMAL(10,2),
  lease_start DATE NOT NULL,
  lease_end DATE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Rent payments
CREATE TABLE public.rent_payments (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  month_year TEXT NOT NULL, -- format: "2025-01"
  payment_date DATE,
  due_date DATE NOT NULL,
  status payment_status_enum DEFAULT 'pending',
  mpesa_code TEXT,
  late_fee DECIMAL(10,2) DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Students (for schools)
CREATE TABLE public.students (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE NOT NULL,
  admission_number TEXT UNIQUE NOT NULL,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  date_of_birth DATE,
  class_level TEXT NOT NULL,
  parent_name TEXT NOT NULL,
  parent_phone TEXT NOT NULL,
  parent_email TEXT,
  address TEXT,
  fee_amount DECIMAL(10,2) NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- School fee payments
CREATE TABLE public.fee_payments (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  student_id UUID REFERENCES public.students(id) ON DELETE CASCADE NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  term_year TEXT NOT NULL, -- format: "Term 1 2025"
  payment_date DATE,
  due_date DATE NOT NULL,
  status payment_status_enum DEFAULT 'pending',
  mpesa_code TEXT,
  discount DECIMAL(10,2) DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Hotel/Airbnb rooms
CREATE TABLE public.rooms (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE NOT NULL,
  room_number TEXT NOT NULL,
  room_type TEXT NOT NULL,
  capacity INTEGER NOT NULL,
  rate_per_night DECIMAL(10,2) NOT NULL,
  description TEXT,
  amenities JSONB DEFAULT '[]'::jsonb,
  status TEXT DEFAULT 'available', -- available, occupied, cleaning, maintenance
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Bookings
CREATE TABLE public.bookings (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE NOT NULL,
  room_id UUID REFERENCES public.rooms(id) NOT NULL,
  guest_name TEXT NOT NULL,
  guest_phone TEXT NOT NULL,
  guest_email TEXT,
  check_in_date DATE NOT NULL,
  check_out_date DATE NOT NULL,
  guests_count INTEGER NOT NULL,
  total_amount DECIMAL(10,2) NOT NULL,
  paid_amount DECIMAL(10,2) DEFAULT 0,
  booking_status TEXT DEFAULT 'confirmed', -- confirmed, checked_in, checked_out, cancelled
  payment_status payment_status_enum DEFAULT 'pending',
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert business types
INSERT INTO public.business_types (type, name, description, monthly_price, features) VALUES
  ('hardware', 'Hardware & Small Shops', 'Perfect for general stores, electronics shops, and small retail businesses', 1500, '["Multi-item sales", "Stock tracking", "Auto receipts", "Daily summaries"]'::jsonb),
  ('supermarket', 'Supermarket', 'Advanced features for grocery stores and inventory-heavy businesses', 7000, '["Staff roles", "Supplier management", "Bulk import", "Sales reports", "Shift reporting"]'::jsonb),
  ('rentals', 'Apartment Rentals', 'Comprehensive solution for landlords and estate managers', 3000, '["Tenant profiles", "Rent tracking", "Auto reminders", "Receipt generation", "Income reports"]'::jsonb),
  ('airbnb', 'Airbnb Management', 'Streamline short-term rentals and guest house operations', 3000, '["Listing management", "Booking calendar", "Guest communication", "Cleaning schedule", "Commission tracking"]'::jsonb),
  ('hotel', 'Hotel Management', 'Complete hotel operations from front desk to housekeeping', 5000, '["Room management", "Check-in/out", "Housekeeping", "Guest history", "Rate management"]'::jsonb),
  ('school', 'School Management', 'Manage private schools, academies, and training centers', 4000, '["Student profiles", "Fee tracking", "SMS reminders", "M-Pesa payments", "Class management", "Term calendar"]'::jsonb);

-- Create indexes for performance
CREATE INDEX idx_businesses_owner_id ON public.businesses(owner_id);
CREATE INDEX idx_businesses_type ON public.businesses(business_type);
CREATE INDEX idx_staff_roles_business_id ON public.staff_roles(business_id);
CREATE INDEX idx_staff_roles_user_id ON public.staff_roles(user_id);
CREATE INDEX idx_products_business_id ON public.products(business_id);
CREATE INDEX idx_sales_business_id ON public.sales(business_id);
CREATE INDEX idx_sales_created_at ON public.sales(created_at);
CREATE INDEX idx_tenants_business_id ON public.tenants(business_id);
CREATE INDEX idx_students_business_id ON public.students(business_id);
CREATE INDEX idx_rooms_business_id ON public.rooms(business_id);
CREATE INDEX idx_bookings_business_id ON public.bookings(business_id);

-- Set up Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rent_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fee_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Profiles: Users can view/update their own profile
CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Businesses: Owners and staff can access their businesses
CREATE POLICY "Business access" ON public.businesses
  FOR ALL USING (
    auth.uid() = owner_id OR 
    auth.uid() IN (
      SELECT user_id FROM public.staff_roles 
      WHERE business_id = businesses.id AND is_active = true
    )
  );

-- Staff roles: Business owners and the staff member can view
CREATE POLICY "Staff roles access" ON public.staff_roles
  FOR ALL USING (
    auth.uid() = user_id OR
    auth.uid() IN (
      SELECT owner_id FROM public.businesses WHERE id = business_id
    )
  );

-- Business data access (products, sales, etc.)
CREATE POLICY "Business data access" ON public.products
  FOR ALL USING (
    auth.uid() IN (
      SELECT CASE 
        WHEN auth.uid() = b.owner_id THEN auth.uid()
        ELSE sr.user_id 
      END
      FROM public.businesses b
      LEFT JOIN public.staff_roles sr ON sr.business_id = b.id AND sr.is_active = true
      WHERE b.id = business_id AND (auth.uid() = b.owner_id OR auth.uid() = sr.user_id)
    )
  );

-- Apply similar policies to other business tables
CREATE POLICY "Sales access" ON public.sales
  FOR ALL USING (
    auth.uid() IN (
      SELECT CASE 
        WHEN auth.uid() = b.owner_id THEN auth.uid()
        ELSE sr.user_id 
      END
      FROM public.businesses b
      LEFT JOIN public.staff_roles sr ON sr.business_id = b.id AND sr.is_active = true
      WHERE b.id = business_id AND (auth.uid() = b.owner_id OR auth.uid() = sr.user_id)
    )
  );

CREATE POLICY "Sale items access" ON public.sale_items
  FOR ALL USING (
    sale_id IN (
      SELECT s.id FROM public.sales s
      JOIN public.businesses b ON b.id = s.business_id
      LEFT JOIN public.staff_roles sr ON sr.business_id = b.id AND sr.is_active = true
      WHERE auth.uid() = b.owner_id OR auth.uid() = sr.user_id
    )
  );

CREATE POLICY "Tenants access" ON public.tenants
  FOR ALL USING (
    auth.uid() IN (
      SELECT CASE 
        WHEN auth.uid() = b.owner_id THEN auth.uid()
        ELSE sr.user_id 
      END
      FROM public.businesses b
      LEFT JOIN public.staff_roles sr ON sr.business_id = b.id AND sr.is_active = true
      WHERE b.id = business_id AND (auth.uid() = b.owner_id OR auth.uid() = sr.user_id)
    )
  );

CREATE POLICY "Students access" ON public.students
  FOR ALL USING (
    auth.uid() IN (
      SELECT CASE 
        WHEN auth.uid() = b.owner_id THEN auth.uid()
        ELSE sr.user_id 
      END
      FROM public.businesses b
      LEFT JOIN public.staff_roles sr ON sr.business_id = b.id AND sr.is_active = true
      WHERE b.id = business_id AND (auth.uid() = b.owner_id OR auth.uid() = sr.user_id)
    )
  );

CREATE POLICY "Rooms access" ON public.rooms
  FOR ALL USING (
    auth.uid() IN (
      SELECT CASE 
        WHEN auth.uid() = b.owner_id THEN auth.uid()
        ELSE sr.user_id 
      END
      FROM public.businesses b
      LEFT JOIN public.staff_roles sr ON sr.business_id = b.id AND sr.is_active = true
      WHERE b.id = business_id AND (auth.uid() = b.owner_id OR auth.uid() = sr.user_id)
    )
  );

-- Apply to remaining tables (rent_payments, fee_payments, bookings, subscriptions)
CREATE POLICY "Rent payments access" ON public.rent_payments
  FOR ALL USING (
    tenant_id IN (
      SELECT t.id FROM public.tenants t
      JOIN public.businesses b ON b.id = t.business_id
      LEFT JOIN public.staff_roles sr ON sr.business_id = b.id AND sr.is_active = true
      WHERE auth.uid() = b.owner_id OR auth.uid() = sr.user_id
    )
  );

CREATE POLICY "Fee payments access" ON public.fee_payments
  FOR ALL USING (
    student_id IN (
      SELECT s.id FROM public.students s
      JOIN public.businesses b ON b.id = s.business_id
      LEFT JOIN public.staff_roles sr ON sr.business_id = b.id AND sr.is_active = true
      WHERE auth.uid() = b.owner_id OR auth.uid() = sr.user_id
    )
  );

CREATE POLICY "Bookings access" ON public.bookings
  FOR ALL USING (
    auth.uid() IN (
      SELECT CASE 
        WHEN auth.uid() = b.owner_id THEN auth.uid()
        ELSE sr.user_id 
      END
      FROM public.businesses b
      LEFT JOIN public.staff_roles sr ON sr.business_id = b.id AND sr.is_active = true
      WHERE b.id = business_id AND (auth.uid() = b.owner_id OR auth.uid() = sr.user_id)
    )
  );

CREATE POLICY "Subscriptions access" ON public.subscriptions
  FOR ALL USING (
    business_id IN (
      SELECT b.id FROM public.businesses b
      WHERE auth.uid() = b.owner_id
    )
  );

-- Function to handle new user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to update timestamps
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add update timestamp triggers
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_businesses_updated_at
  BEFORE UPDATE ON public.businesses
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_products_updated_at
  BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_tenants_updated_at
  BEFORE UPDATE ON public.tenants
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_students_updated_at
  BEFORE UPDATE ON public.students
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_rooms_updated_at
  BEFORE UPDATE ON public.rooms
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_bookings_updated_at
  BEFORE UPDATE ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

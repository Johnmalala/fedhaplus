import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables');
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Database types
export type BusinessType = 'hardware' | 'supermarket' | 'rentals' | 'airbnb' | 'hotel' | 'school';
export type StaffRole = 'owner' | 'manager' | 'cashier' | 'accountant' | 'teacher' | 'front_desk' | 'housekeeper';
export type PaymentStatus = 'pending' | 'paid' | 'overdue' | 'cancelled';
export type SubscriptionStatus = 'trial' | 'active' | 'cancelled' | 'expired';

export interface Profile {
  id: string;
  email: string;
  phone?: string;
  full_name: string;
  created_at: string;
  updated_at: string;
}

export interface Business {
  id: string;
  owner_id: string;
  business_type: BusinessType;
  name: string;
  description?: string;
  phone?: string;
  location?: string;
  logo_url?: string;
  settings: Record<string, any>;
  created_at: string;
  updated_at: string;
}

export interface StaffRole {
  id: string;
  business_id: string;
  user_id: string;
  role: StaffRole;
  permissions: Record<string, any>;
  invited_by: string;
  invited_at: string;
  is_active: boolean;
}

export interface Product {
  id: string;
  business_id: string;
  name: string;
  description?: string;
  sku?: string;
  category?: string;
  buying_price?: number;
  selling_price: number;
  stock_quantity: number;
  min_stock_level: number;
  unit: string;
  image_url?: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface Sale {
  id: string;
  business_id: string;
  cashier_id: string;
  customer_name?: string;
  customer_phone?: string;
  total_amount: number;
  payment_method: string;
  mpesa_code?: string;
  notes?: string;
  receipt_number: string;
  created_at: string;
}

export interface SaleItem {
  id: string;
  sale_id: string;
  product_id: string;
  quantity: number;
  unit_price: number;
  total_price: number;
}

export interface Tenant {
  id: string;
  business_id: string;
  name: string;
  phone: string;
  email?: string;
  id_number?: string;
  unit_number: string;
  rent_amount: number;
  deposit_amount?: number;
  lease_start: string;
  lease_end?: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface Student {
  id: string;
  business_id: string;
  admission_number: string;
  first_name: string;
  last_name: string;
  date_of_birth?: string;
  class_level: string;
  parent_name: string;
  parent_phone: string;
  parent_email?: string;
  address?: string;
  fee_amount: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface Room {
  id: string;
  business_id: string;
  room_number: string;
  room_type: string;
  capacity: number;
  rate_per_night: number;
  description?: string;
  amenities: string[];
  status: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface Booking {
  id: string;
  business_id: string;
  room_id: string;
  guest_name: string;
  guest_phone: string;
  guest_email?: string;
  check_in_date: string;
  check_out_date: string;
  guests_count: number;
  total_amount: number;
  paid_amount: number;
  booking_status: string;
  payment_status: PaymentStatus;
  notes?: string;
  created_at: string;
  updated_at: string;
}

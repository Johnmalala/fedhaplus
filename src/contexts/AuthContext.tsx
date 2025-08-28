import React, { createContext, useContext, useState, useEffect } from 'react';
import { supabase, type Profile, type BusinessType } from '../lib/supabase';
import { User } from '@supabase/supabase-js';

interface NewBusinessInfo {
  businessName: string;
  fullName: string;
  businessType: BusinessType;
}

interface AuthContextType {
  user: User | null;
  profile: Profile | null;
  loading: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
  signInWithPhone: (phone: string) => Promise<void>;
  verifyOtpAndCreateBusiness: (phone: string, token: string, info: NewBusinessInfo) => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const getSession = async () => {
      const { data: { session } } = await supabase.auth.getSession();
      setUser(session?.user || null);
      if (session?.user) {
        await fetchProfile(session.user.id);
      }
      setLoading(false);
    };

    getSession();

    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (_event, session) => {
      setUser(session?.user || null);
      if (session?.user) {
        await fetchProfile(session.user.id);
      } else {
        setProfile(null);
      }
      if (_event === 'SIGNED_IN') {
        // This will be handled by the AppRoutes component
      }
    });

    return () => subscription.unsubscribe();
  }, []);

  const fetchProfile = async (userId: string) => {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .single();

      if (error) throw error;
      setProfile(data);
    } catch (error) {
      console.error('Error fetching profile:', error);
    }
  };

  const signInWithPhone = async (phone: string) => {
    const { error } = await supabase.auth.signInWithOtp({
      phone,
    });
    if (error) throw error;
  };

  const verifyOtpAndCreateBusiness = async (phone: string, token: string, info: NewBusinessInfo) => {
    const { data: { session }, error: otpError } = await supabase.auth.verifyOtp({
      phone,
      token,
      type: 'sms',
    });

    if (otpError) throw otpError;
    if (!session || !session.user) throw new Error('Could not sign in.');

    // Update user's profile with full name
    const { error: profileError } = await supabase
      .from('profiles')
      .update({ full_name: info.fullName })
      .eq('id', session.user.id);

    if (profileError) {
      console.error("Error updating profile:", profileError);
      // Non-fatal, continue with business creation
    }

    // Create the business
    const { data: business, error: businessError } = await supabase
      .from('businesses')
      .insert({
        name: info.businessName,
        business_type: info.businessType,
        owner_id: session.user.id,
      })
      .select()
      .single();

    if (businessError) throw businessError;

    // Create owner role in staff_roles
    const { error: staffError } = await supabase
      .from('staff_roles')
      .insert({
        business_id: business.id,
        user_id: session.user.id,
        role: 'owner',
        invited_by: session.user.id,
        is_active: true,
      });
      
    if (staffError) throw staffError;

    // The onAuthStateChange listener will handle setting the user and profile state.
  };

  const signIn = async (email: string, password: string) => {
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    if (error) throw error;
  };

  const signOut = async () => {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
  };

  return (
    <AuthContext.Provider value={{
      user,
      profile,
      loading,
      signIn,
      signOut,
      signInWithPhone,
      verifyOtpAndCreateBusiness,
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}

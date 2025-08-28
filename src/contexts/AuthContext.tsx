import React, { createContext, useContext, useState, useEffect } from 'react';
import { supabase, type Profile, type BusinessType } from '../lib/supabase';
import { User } from '@supabase/supabase-js';

interface SignUpInfo {
  businessName: string;
  fullName: string;
  phone: string;
  businessType: BusinessType;
}

interface AuthContextType {
  user: User | null;
  profile: Profile | null;
  loading: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
  signUpAndCreateBusiness: (email: string, password: string, info: SignUpInfo) => Promise<void>;
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

  const signUpAndCreateBusiness = async (email: string, password: string, info: SignUpInfo) => {
    // For automatic login after signup, you may need to disable "Confirm email" in your Supabase Auth settings.
    // Otherwise, the user must verify their email before they can log in.
    const { data: { session }, error: signUpError } = await supabase.auth.signUp({
      email,
      password,
      options: {
        // This data is passed to the `handle_new_user` trigger in Supabase.
        data: {
          full_name: info.fullName,
          phone: info.phone,
        }
      }
    });

    if (signUpError) throw signUpError;
    if (!session || !session.user) throw new Error('Could not sign up user. If email confirmation is enabled, please check your email to verify your account.');
    
    // The handle_new_user trigger in Supabase creates the profile.
    // Now, we create the associated business and staff role.
    const { data: business, error: businessError } = await supabase
      .from('businesses')
      .insert({
        name: info.businessName,
        business_type: info.businessType,
        owner_id: session.user.id,
        phone: info.phone,
      })
      .select()
      .single();

    if (businessError) throw businessError;

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

    // TODO: Implement sending a welcome SMS via a Supabase Edge Function
    console.log(`Simulating welcome SMS to ${info.phone}: "Karibu Fedha Plus! Biashara yako imeanzishwa."`);

    // The onAuthStateChange listener will handle setting the user and profile state, which triggers the redirect to the dashboard.
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
      signUpAndCreateBusiness,
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

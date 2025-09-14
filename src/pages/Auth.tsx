import React, { useState, useEffect } from 'react';
import { useLocation, useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { type BusinessType } from '../lib/supabase';
import AuthLayout from '../components/auth/AuthLayout';

const businessTypeDisplayMap: Record<string, string> = {
  'hardware': 'Hardware & Small Shops',
  'supermarket': 'Supermarket',
  'rentals': 'Apartment Rentals',
  'airbnb': 'Airbnb Management',
  'hotel': 'Hotel Management',
  'school': 'School Management',
};

export default function AuthPage() {
  const location = useLocation();
  const navigate = useNavigate();
  const query = new URLSearchParams(location.search);
  const businessType = query.get('type') as BusinessType | null;

  const [mode, setMode] = useState<'signup' | 'login'>(businessType ? 'signup' : 'login');
  
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [businessName, setBusinessName] = useState('');
  const [fullName, setFullName] = useState('');
  const [phone, setPhone] = useState('');

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  
  const { signIn, signUpAndCreateBusiness } = useAuth();
  
  const businessTypeName = businessType ? (businessTypeDisplayMap[businessType] || 'Business') : 'Business';

  useEffect(() => {
    if (mode === 'signup' && !businessType) {
      navigate('/#pricing');
    }
  }, [mode, businessType, navigate]);

  const handleFormSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    if (mode === 'signup') {
      if (password !== confirmPassword) {
        setError('Passwords do not match.');
        setLoading(false);
        return;
      }
      if (!businessType) {
        setError('No business type selected. Please choose a plan.');
        setLoading(false);
        return;
      }
      try {
        await signUpAndCreateBusiness(email, password, {
          businessName,
          fullName,
          phone,
          businessType,
        });
        // Navigation is handled by AppRoutes after auth state change
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to create account. The email might already be in use.');
      }
    } else { // Login mode
      try {
        await signIn(email, password);
        // Navigation is handled by AppRoutes after auth state change
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'An unexpected error occurred.';
        setError(errorMessage.includes('Invalid login credentials') ? 'Invalid email or password.' : errorMessage);
      }
    }
    setLoading(false);
  };

  const title = mode === 'login' 
    ? 'Welcome Back!' 
    : `Join for ${businessTypeName}`;
  const subtitle = mode === 'login'
    ? 'Enter your credentials to access your dashboard.'
    : "Start your 30-day free trial.";

  const footerContent = mode === 'signup' 
    ? <>Already have an account? <button type="button" onClick={() => setMode('login')} className="font-medium text-primary-600 hover:underline dark:text-primary-400">Log in</button></>
    : <>Don't have an account? <Link to="/#pricing" className="font-medium text-primary-600 hover:underline dark:text-primary-400">Sign up</Link></>;

  return (
    <AuthLayout
      title={title}
      subtitle={subtitle}
      footerContent={footerContent}
    >
      <form onSubmit={handleFormSubmit} className="space-y-4">
        {error && (
          <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-700 dark:text-red-300 px-4 py-3 rounded-lg text-sm">
            {error}
          </div>
        )}
        
        {mode === 'signup' && (
          <>
            <div className="grid grid-cols-2 gap-4">
              <Input id="full-name" placeholder="Your Name" required value={fullName} onChange={(e) => setFullName(e.target.value)} />
              <Input id="business-name" placeholder="Business Name" required value={businessName} onChange={(e) => setBusinessName(e.target.value)} />
            </div>
            <Input id="phone" type="tel" placeholder="Phone Number (e.g., 254...)" required value={phone} onChange={(e) => setPhone(e.target.value)} />
          </>
        )}

        <Input id="email" type="email" placeholder="Email Address" required value={email} onChange={(e) => setEmail(e.target.value)} />
        <Input id="password" type="password" placeholder="Password" required value={password} onChange={(e) => setPassword(e.target.value)} />
        
        {mode === 'signup' && (
          <Input id="confirm-password" type="password" placeholder="Confirm Password" required value={confirmPassword} onChange={(e) => setConfirmPassword(e.target.value)} />
        )}
        
        <Button type="submit" className="w-full" disabled={loading}>
          {loading ? 'Processing...' : (mode === 'signup' ? 'Create Account' : 'Log In')}
        </Button>
      </form>
    </AuthLayout>
  );
}

import React, { useState, useEffect } from 'react';
import { useLocation, useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { type BusinessType } from '../lib/supabase';
import AuthLayout from '../components/auth/AuthLayout';

const planMap: Record<string, string> = {
  'hardware-&-small-shops': 'Hardware & Small Shops',
  'supermarket': 'Supermarket',
  'apartment-rentals': 'Apartment Rentals',
  'airbnb-management': 'Airbnb Management',
  'hotel-management': 'Hotel Management',
  'school-management': 'School Management',
};

export default function Signup() {
  const [businessName, setBusinessName] = useState('');
  const [fullName, setFullName] = useState('');
  const [phone, setPhone] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  
  const navigate = useNavigate();
  const location = useLocation();
  const { signUpAndCreateBusiness } = useAuth();
  
  const query = new URLSearchParams(location.search);
  const plan = query.get('plan') as BusinessType | null;
  const planName = plan ? (planMap[plan.replace(/ /g, '-')] || 'Unknown Plan') : 'Unknown Plan';

  useEffect(() => {
    if (!plan) {
      navigate('/#pricing'); // Redirect if no plan is selected
    }
  }, [plan, navigate]);

  const handleSignUpSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (password !== confirmPassword) {
      setError('Passwords do not match.');
      return;
    }
    if (!plan) {
      setError('No business plan selected.');
      return;
    }
    setLoading(true);
    setError('');
    try {
      await signUpAndCreateBusiness(email, password, {
        businessName,
        fullName,
        phone,
        businessType: plan,
      });
      // On successful signup, the AuthProvider will redirect to the dashboard.
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create account. The email might already be in use.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthLayout
      title="Start your free trial"
      subtitle={`You've selected the ${planName} plan. Let's create your account.`}
      footerContent={
        <>
          Already have an account?{" "}
          <Link to="/login" className="font-medium text-primary-600 hover:underline dark:text-primary-400">
            Log in
          </Link>
        </>
      }
    >
      <form onSubmit={handleSignUpSubmit} className="space-y-4">
        {error && (
          <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-700 dark:text-red-300 px-4 py-3 rounded-lg text-sm">
            {error}
          </div>
        )}
        <div className="grid grid-cols-2 gap-4">
          <Input id="full-name" placeholder="Your Name" required value={fullName} onChange={(e) => setFullName(e.target.value)} />
          <Input id="business-name" placeholder="Business Name" required value={businessName} onChange={(e) => setBusinessName(e.target.value)} />
        </div>
        <Input id="phone" type="tel" placeholder="Phone Number (e.g., 254...)" required value={phone} onChange={(e) => setPhone(e.target.value)} />
        <Input id="email" type="email" placeholder="Email Address" required value={email} onChange={(e) => setEmail(e.target.value)} />
        <Input id="password" type="password" placeholder="Password" required value={password} onChange={(e) => setPassword(e.target.value)} />
        <Input id="confirm-password" type="password" placeholder="Confirm Password" required value={confirmPassword} onChange={(e) => setConfirmPassword(e.target.value)} />
        
        <Button type="submit" className="w-full" disabled={loading}>
          {loading ? 'Creating Account...' : 'Create Account & Start Trial'}
        </Button>
      </form>
    </AuthLayout>
  );
}

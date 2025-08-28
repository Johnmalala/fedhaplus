import React, { useState, useEffect } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { type BusinessType } from '../lib/supabase';

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
  const planName = plan ? planMap[plan] || 'Unknown Plan' : 'Unknown Plan';

  useEffect(() => {
    if (!plan) {
      navigate('/'); // Redirect if no plan is selected
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
      // Supabase may show a "Check your email" message if confirmation is enabled.
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create account. The email might already be in use.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 dark:bg-gray-900 px-4">
      <div className="max-w-md w-full space-y-8">
        <div className="text-center">
          <div className="w-12 h-12 mx-auto bg-gradient-to-r from-primary-500 to-secondary-500 rounded-lg flex items-center justify-center">
            <span className="text-white font-bold text-lg">F+</span>
          </div>
          <h2 className="mt-6 text-3xl font-bold text-gray-900 dark:text-white">
            Start your 30-day free trial
          </h2>
          <p className="mt-2 text-md text-gray-600 dark:text-gray-400">
            For: <span className="font-semibold text-primary-600">{planName}</span>
          </p>
        </div>

        {error && (
          <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-700 dark:text-red-300 px-4 py-3 rounded-lg text-sm">
            {error}
          </div>
        )}

        <form className="mt-8 space-y-6" onSubmit={handleSignUpSubmit}>
          <div className="rounded-md shadow-sm -space-y-px">
            <div>
              <label htmlFor="business-name" className="sr-only">Business Name</label>
              <Input
                id="business-name"
                name="business-name"
                type="text"
                required
                className="rounded-t-md"
                placeholder="Business Name (e.g., Mlimani Academy)"
                value={businessName}
                onChange={(e) => setBusinessName(e.target.value)}
              />
            </div>
            <div>
              <label htmlFor="full-name" className="sr-only">Your Name</label>
              <Input
                id="full-name"
                name="full-name"
                type="text"
                required
                className="border-t-0"
                placeholder="Your Name (e.g., Jane Muthoni)"
                value={fullName}
                onChange={(e) => setFullName(e.target.value)}
              />
            </div>
            <div>
              <label htmlFor="phone" className="sr-only">Phone Number</label>
              <Input
                id="phone"
                name="phone"
                type="tel"
                required
                className="border-t-0"
                placeholder="Phone Number (e.g., 254712345678)"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
              />
            </div>
            <div>
              <label htmlFor="email-address" className="sr-only">Email address</label>
              <Input
                id="email-address"
                name="email"
                type="email"
                autoComplete="email"
                required
                className="border-t-0"
                placeholder="Email address"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>
            <div>
              <label htmlFor="password-signup" className="sr-only">Password</label>
              <Input
                id="password-signup"
                name="password"
                type="password"
                autoComplete="new-password"
                required
                className="border-t-0"
                placeholder="Password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
            <div>
              <label htmlFor="confirm-password" className="sr-only">Confirm Password</label>
              <Input
                id="confirm-password"
                name="confirm-password"
                type="password"
                autoComplete="new-password"
                required
                className="rounded-b-md border-t-0"
                placeholder="Confirm Password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
              />
            </div>
          </div>
          <div>
            <Button type="submit" className="w-full" disabled={loading}>
              {loading ? 'Creating Account...' : 'Create Account & Start Trial'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}

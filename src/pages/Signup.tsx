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
  const [step, setStep] = useState<'details' | 'otp'>('details');
  const [businessName, setBusinessName] = useState('');
  const [fullName, setFullName] = useState('');
  const [phone, setPhone] = useState('');
  const [otp, setOtp] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  
  const navigate = useNavigate();
  const location = useLocation();
  const { signInWithPhone, verifyOtpAndCreateBusiness } = useAuth();
  
  const query = new URLSearchParams(location.search);
  const plan = query.get('plan') as BusinessType | null;
  const planName = plan ? planMap[plan] || 'Unknown Plan' : 'Unknown Plan';

  useEffect(() => {
    if (!plan) {
      navigate('/'); // Redirect if no plan is selected
    }
  }, [plan, navigate]);

  const handleDetailsSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      await signInWithPhone(phone);
      setStep('otp');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to send OTP. Please check the phone number.');
    } finally {
      setLoading(false);
    }
  };

  const handleOtpSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!plan) {
      setError('No business plan selected.');
      return;
    }
    setLoading(true);
    setError('');
    try {
      await verifyOtpAndCreateBusiness(phone, otp, {
        businessName,
        fullName,
        businessType: plan,
      });
      // On successful verification and creation, the AuthProvider will redirect to the dashboard
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Invalid OTP or failed to create business.');
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

        {step === 'details' && (
          <form className="mt-8 space-y-6" onSubmit={handleDetailsSubmit}>
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
                  className="rounded-b-md border-t-0"
                  placeholder="Phone Number (e.g., 254712345678)"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                />
              </div>
            </div>
            <div>
              <Button type="submit" className="w-full" disabled={loading}>
                {loading ? 'Sending OTP...' : 'Continue'}
              </Button>
            </div>
          </form>
        )}

        {step === 'otp' && (
          <form className="mt-8 space-y-6" onSubmit={handleOtpSubmit}>
            <p className="text-center text-gray-600 dark:text-gray-400">
              We've sent a 6-digit code to <span className="font-medium text-gray-900 dark:text-white">{phone}</span>. Please enter it below.
            </p>
            <div>
              <label htmlFor="otp" className="sr-only">One-Time Password</label>
              <Input
                id="otp"
                name="otp"
                type="text"
                required
                placeholder="Enter 6-digit OTP"
                value={otp}
                onChange={(e) => setOtp(e.target.value)}
              />
            </div>
            <div>
              <Button type="submit" className="w-full" disabled={loading}>
                {loading ? 'Verifying...' : 'Verify & Create Account'}
              </Button>
            </div>
            <div className="text-center">
              <button
                type="button"
                onClick={() => setStep('details')}
                className="text-sm font-medium text-primary-600 hover:text-primary-500"
              >
                Entered the wrong number?
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}

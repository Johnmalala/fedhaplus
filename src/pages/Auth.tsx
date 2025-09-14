import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import AuthLayout from '../components/auth/AuthLayout';

export default function AuthPage() {
  const navigate = useNavigate();
  const [mode, setMode] = useState<'signup' | 'login'>('login');
  
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [fullName, setFullName] = useState('');
  const [phone, setPhone] = useState('');

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  
  const { signIn, signUp } = useAuth();

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
      try {
        await signUp(email, password, {
          fullName,
          phone,
        });
        // On success, the onAuthStateChange listener will trigger,
        // and the routing logic will handle redirection.
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
    : 'Create Your Account';
  const subtitle = mode === 'login'
    ? 'Enter your credentials to access your dashboard.'
    : "Join Fedha Plus to manage your business efficiently.";

  const footerContent = mode === 'signup' 
    ? <>Already have an account? <button type="button" onClick={() => setMode('login')} className="font-medium text-primary-600 hover:underline dark:text-primary-400">Log in</button></>
    : <>Don't have an account? <button type="button" onClick={() => setMode('signup')} className="font-medium text-primary-600 hover:underline dark:text-primary-400">Sign up</button></>;

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
            <Input id="full-name" placeholder="Your Full Name" required value={fullName} onChange={(e) => setFullName(e.target.value)} />
            <Input id="phone" type="tel" placeholder="Phone Number (e.g., 254...)" required value={phone} onChange={(e) => setPhone(e.target.value)} />
          </>
        )}

        <Input id="email" type="email" placeholder="Email Address" required value={email} onChange={(e) => setEmail(e.target.value)} />
        <Input id="password" type="password" placeholder="Password" required value={password} onChange={(e) => setPassword(e.target.value)} />
        
        {mode === 'signup' && (
          <Input id="confirm-password" type="password" placeholder="Confirm Password" required value={confirmPassword} onChange={(e) => setConfirmPassword(e.target.value)} />
        )}
        
        <div className="flex items-center justify-between">
            {mode === 'login' && (
                <Link
                    to="/forgot-password"
                    className="text-sm text-primary-600 hover:underline dark:text-primary-400"
                >
                    Forgot password?
                </Link>
            )}
        </div>

        <Button type="submit" className="w-full" disabled={loading}>
          {loading ? 'Processing...' : (mode === 'signup' ? 'Create Account' : 'Log In')}
        </Button>
      </form>
    </AuthLayout>
  );
}

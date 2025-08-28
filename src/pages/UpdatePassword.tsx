import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import AuthLayout from '../components/auth/AuthLayout';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';

export default function UpdatePassword() {
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const navigate = useNavigate();

  const handleUpdatePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    if (password !== confirmPassword) {
      setError('Passwords do not match.');
      return;
    }
    if (password.length < 6) {
        setError('Password should be at least 6 characters.');
        return;
    }
    setLoading(true);
    setError('');
    setMessage('');

    // Supabase client automatically handles the session from the URL fragment.
    const { error } = await supabase.auth.updateUser({ password });

    setLoading(false);
    if (error) {
      setError(`Failed to update password: ${error.message}`);
    } else {
      setMessage('Your password has been updated successfully!');
      setTimeout(() => navigate('/login'), 3000);
    }
  };

  return (
    <AuthLayout
      title="Create a New Password"
      subtitle="Enter and confirm your new password below."
      footerContent={
        <Link to="/login" className="font-medium text-primary-600 hover:underline dark:text-primary-400">
          Back to Login
        </Link>
      }
    >
      <form onSubmit={handleUpdatePassword} className="space-y-4">
        {error && (
          <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-700 dark:text-red-300 px-4 py-2 rounded-lg text-sm">
            {error}
          </div>
        )}
        {message && (
          <div className="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 text-green-700 dark:text-green-300 px-4 py-2 rounded-lg text-sm">
            {message}
          </div>
        )}
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1" htmlFor="password">
            New Password
          </label>
          <Input
            id="password"
            type="password"
            placeholder="••••••••"
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            disabled={loading || !!message}
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1" htmlFor="confirm-password">
            Confirm New Password
          </label>
          <Input
            id="confirm-password"
            type="password"
            placeholder="••••••••"
            required
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            disabled={loading || !!message}
          />
        </div>
        <Button type="submit" className="w-full" disabled={loading || !!message}>
          {loading ? 'Updating...' : 'Update Password'}
        </Button>
      </form>
    </AuthLayout>
  );
}

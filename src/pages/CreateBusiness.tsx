import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase, type BusinessType } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import AuthLayout from '../components/auth/AuthLayout';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';

const businessTypeMap: Record<BusinessType, { name: string, icon: string }> = {
  hardware: { name: 'Hardware & Small Shops', icon: '🔧' },
  supermarket: { name: 'Supermarket', icon: '🛒' },
  rentals: { name: 'Apartment Rentals', icon: '🏠' },
  airbnb: { name: 'Airbnb Management', icon: '🏡' },
  hotel: { name: 'Hotel Management', icon: '🏨' },
  school: { name: 'School Management', icon: '🎒' },
};

export default function CreateBusinessPage() {
  const { user } = useAuth();
  const navigate = useNavigate();
  
  const [businessName, setBusinessName] = useState('');
  const [businessType, setBusinessType] = useState<BusinessType>('hardware');
  const [role, setRole] = useState<'owner' | 'manager'>('owner');
  
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleCreateBusiness = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) {
      setError("You must be logged in to create a business.");
      return;
    }
    setLoading(true);
    setError('');

    try {
      // 1. Create the business
      const { data: business, error: businessError } = await supabase
        .from('businesses')
        .insert({
          name: businessName,
          business_type: businessType,
          owner_id: user.id,
        })
        .select()
        .single();

      if (businessError) throw businessError;

      // 2. Assign the user's role in the new business
      const { error: staffError } = await supabase
        .from('staff_roles')
        .insert({
          business_id: business.id,
          user_id: user.id,
          role: role,
          is_active: true,
          invited_by: user.id,
        });
      
      if (staffError) throw staffError;

      // 3. Refresh session to update RLS claims
      await supabase.auth.refreshSession();

      // 4. Navigate to the dashboard for the new business
      navigate(`/dashboard?type=${businessType}`, { replace: true });

    } catch (err) {
      console.error("Error creating business:", err);
      setError(err instanceof Error ? err.message : 'An unexpected error occurred.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthLayout
      title="Set Up Your Business"
      subtitle="Tell us a little bit about your new business to get started."
      footerContent={<>This will be your first business on Fedha Plus. You can add more later.</>}
    >
      <form onSubmit={handleCreateBusiness} className="space-y-4">
        {error && (
          <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-700 dark:text-red-300 px-4 py-3 rounded-lg text-sm">
            {error}
          </div>
        )}
        
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1" htmlFor="business-name">
            Business Name
          </label>
          <Input id="business-name" placeholder="e.g., Kamau Hardware" required value={businessName} onChange={(e) => setBusinessName(e.target.value)} />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1" htmlFor="business-type">
            What kind of business is it?
          </label>
          <select
            id="business-type"
            value={businessType}
            onChange={(e) => setBusinessType(e.target.value as BusinessType)}
            className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent dark:bg-gray-800 dark:text-white"
            required
          >
            {Object.entries(businessTypeMap).map(([key, value]) => (
              <option key={key} value={key}>
                {value.icon} {value.name}
              </option>
            ))}
          </select>
        </div>
        
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1" htmlFor="role">
            What is your role?
          </label>
          <select
            id="role"
            value={role}
            onChange={(e) => setRole(e.target.value as 'owner' | 'manager')}
            className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent dark:bg-gray-800 dark:text-white"
            required
          >
            <option value="owner">I am the Owner</option>
            <option value="manager">I am a Manager</option>
          </select>
        </div>
        
        <Button type="submit" className="w-full" disabled={loading}>
          {loading ? 'Creating Business...' : 'Finish Setup'}
        </Button>
      </form>
    </AuthLayout>
  );
}

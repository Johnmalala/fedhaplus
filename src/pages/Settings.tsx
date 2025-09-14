import React, { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { supabase, type Business, type Profile } from '../lib/supabase';
import PageHeader from '../components/PageHeader';
import { Card, CardHeader, CardContent, CardFooter } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';

interface SettingsPageProps {
  business: Business | null;
  onBusinessUpdate: () => void; // Callback to refresh business list
}

export default function Settings({ business, onBusinessUpdate }: SettingsPageProps) {
  const { user, profile, loading: authLoading } = useAuth();
  const [businessDetails, setBusinessDetails] = useState<Partial<Business>>({});
  const [profileDetails, setProfileDetails] = useState<Partial<Profile>>({});
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (business) {
      setBusinessDetails({ name: business.name, phone: business.phone });
    }
    if (profile) {
      setProfileDetails({ full_name: profile.full_name, email: profile.email });
    }
  }, [business, profile]);

  const handleBusinessChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setBusinessDetails(prev => ({ ...prev, [e.target.name]: e.target.value }));
  };

  const handleProfileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setProfileDetails(prev => ({ ...prev, [e.target.name]: e.target.value }));
  };

  const handleBusinessSave = async () => {
    if (!business) return;
    setLoading(true);
    try {
      const { error } = await supabase
        .from('businesses')
        .update({ name: businessDetails.name, phone: businessDetails.phone })
        .eq('id', business.id);
      if (error) throw error;
      onBusinessUpdate(); // Refresh business data in parent
      alert('Business profile updated!');
    } catch (error) {
      console.error(error);
      alert('Failed to update business profile.');
    } finally {
      setLoading(false);
    }
  };

  const handleProfileSave = async () => {
    if (!user) return;
    setLoading(true);
    try {
      const { error } = await supabase
        .from('profiles')
        .update({ full_name: profileDetails.full_name, email: profileDetails.email })
        .eq('id', user.id);
      if (error) throw error;
      // Note: Auth context will refetch profile on its own, but an explicit refresh could be added
      alert('Account settings updated!');
    } catch (error) {
      console.error(error);
      alert('Failed to update account settings.');
    } finally {
      setLoading(false);
    }
  };

  if (authLoading || !business) {
    return <div>Loading settings...</div>;
  }

  return (
    <div>
      <PageHeader
        title="Settings"
        subtitle="Manage your business and account settings."
      />
      <div className="space-y-8">
        <Card>
          <CardHeader>
            <h3 className="text-lg font-semibold text-gray-900 dark:text-white">Business Profile</h3>
            <p className="text-sm text-gray-500 dark:text-gray-400">Update your business's public information.</p>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Business Name</label>
              <Input name="name" value={businessDetails.name || ''} onChange={handleBusinessChange} />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Contact Phone</label>
              <Input name="phone" value={businessDetails.phone || ''} onChange={handleBusinessChange} />
            </div>
          </CardContent>
          <CardFooter>
            <Button onClick={handleBusinessSave} disabled={loading}>{loading ? 'Saving...' : 'Save Changes'}</Button>
          </CardFooter>
        </Card>

        <Card>
          <CardHeader>
            <h3 className="text-lg font-semibold text-gray-900 dark:text-white">Account Settings</h3>
            <p className="text-sm text-gray-500 dark:text-gray-400">Manage your login and personal details.</p>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Full Name</label>
              <Input name="full_name" value={profileDetails.full_name || ''} onChange={handleProfileChange} />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Email Address</label>
              <Input name="email" type="email" value={profileDetails.email || ''} onChange={handleProfileChange} />
            </div>
          </CardContent>
          <CardFooter>
            <Button onClick={handleProfileSave} disabled={loading}>{loading ? 'Saving...' : 'Save Changes'}</Button>
          </CardFooter>
        </Card>
      </div>
    </div>
  );
}

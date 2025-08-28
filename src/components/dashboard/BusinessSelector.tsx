import React, { useState, useEffect } from 'react';
import { Dialog } from '@headlessui/react';
import { PlusIcon, XMarkIcon } from '@heroicons/react/24/outline';
import { supabase, type Business, type BusinessType } from '../../lib/supabase';
import { useAuth } from '../../contexts/AuthContext';
import { useLanguage } from '../../contexts/LanguageContext';

interface BusinessSelectorProps {
  selectedBusiness: Business | null;
  onBusinessSelect: (business: Business) => void;
}

const businessTypeMap: Record<BusinessType, { name: string, icon: string }> = {
  hardware: { name: 'Hardware Shop', icon: '🔧' },
  supermarket: { name: 'Supermarket', icon: '🛒' },
  rentals: { name: 'Apartment Rentals', icon: '🏠' },
  airbnb: { name: 'Airbnb Management', icon: '🏡' },
  hotel: { name: 'Hotel Management', icon: '🏨' },
  school: { name: 'School Management', icon: '🎒' },
};

export default function BusinessSelector({ selectedBusiness, onBusinessSelect }: BusinessSelectorProps) {
  const [businesses, setBusinesses] = useState<Business[]>([]);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [loading, setLoading] = useState(true);
  const [createLoading, setCreateLoading] = useState(false);
  
  const [newBusiness, setNewBusiness] = useState({
    name: '',
    business_type: 'hardware' as BusinessType,
    description: '',
    phone: '',
    location: '',
  });

  const { user } = useAuth();
  const { t } = useLanguage();

  useEffect(() => {
    if (user) {
      fetchBusinesses();
    }
  }, [user]);

  const fetchBusinesses = async () => {
    try {
      const { data, error } = await supabase
        .from('businesses')
        .select('*')
        .eq('owner_id', user?.id)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setBusinesses(data || []);
      
      // Auto-select first business if none selected
      if (data && data.length > 0 && !selectedBusiness) {
        onBusinessSelect(data[0]);
      }
    } catch (error) {
      console.error('Error fetching businesses:', error);
    } finally {
      setLoading(false);
    }
  };

  const createBusiness = async (e: React.FormEvent) => {
    e.preventDefault();
    setCreateLoading(true);

    try {
      const { data, error } = await supabase
        .from('businesses')
        .insert([{
          ...newBusiness,
          owner_id: user?.id,
        }])
        .select()
        .single();

      if (error) throw error;

      setBusinesses(prev => [data, ...prev]);
      onBusinessSelect(data);
      setShowCreateModal(false);
      setNewBusiness({
        name: '',
        business_type: 'hardware',
        description: '',
        phone: '',
        location: '',
      });
    } catch (error) {
      console.error('Error creating business:', error);
    } finally {
      setCreateLoading(false);
    }
  };

  if (loading) {
    return <div className="p-4">Loading businesses...</div>;
  }

  return (
    <div className="p-4 border-b border-gray-200 dark:border-gray-700">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-lg font-semibold text-gray-900 dark:text-white">
          Your Businesses
        </h2>
        <button
          onClick={() => setShowCreateModal(true)}
          className="flex items-center px-3 py-1 bg-primary-600 text-white rounded-lg hover:bg-primary-700 text-sm"
        >
          <PlusIcon className="h-4 w-4 mr-1" />
          Add Business
        </button>
      </div>

      {businesses.length === 0 ? (
        <div className="text-center py-8">
          <p className="text-gray-500 dark:text-gray-400 mb-4">
            No businesses found. Create your first business to get started.
          </p>
          <button
            onClick={() => setShowCreateModal(true)}
            className="bg-primary-600 text-white px-4 py-2 rounded-lg hover:bg-primary-700"
          >
            Create Business
          </button>
        </div>
      ) : (
        <div className="space-y-2">
          {businesses.map((business) => (
            <button
              key={business.id}
              onClick={() => onBusinessSelect(business)}
              className={`w-full text-left p-3 rounded-lg border-2 transition-colors ${
                selectedBusiness?.id === business.id
                  ? 'border-primary-500 bg-primary-50 dark:bg-primary-900/20'
                  : 'border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-600'
              }`}
            >
              <div className="flex items-center space-x-3">
                <span className="text-2xl">
                  {businessTypeMap[business.business_type]?.icon}
                </span>
                <div className="flex-1">
                  <div className="font-medium text-gray-900 dark:text-white">
                    {business.name}
                  </div>
                  <div className="text-sm text-gray-500 dark:text-gray-400">
                    {businessTypeMap[business.business_type]?.name}
                  </div>
                </div>
              </div>
            </button>
          ))}
        </div>
      )}

      {/* Create Business Modal */}
      <Dialog open={showCreateModal} onClose={() => setShowCreateModal(false)} className="relative z-50">
        <div className="fixed inset-0 bg-black/30" aria-hidden="true" />
        
        <div className="fixed inset-0 flex items-center justify-center p-4">
          <Dialog.Panel className="mx-auto max-w-md w-full bg-white dark:bg-gray-900 rounded-xl shadow-xl">
            <div className="flex items-center justify-between p-6 border-b border-gray-200 dark:border-gray-700">
              <Dialog.Title className="text-lg font-semibold text-gray-900 dark:text-white">
                Create New Business
              </Dialog.Title>
              <button
                onClick={() => setShowCreateModal(false)}
                className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
              >
                <XMarkIcon className="h-5 w-5" />
              </button>
            </div>

            <form onSubmit={createBusiness} className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Business Name *
                </label>
                <input
                  type="text"
                  value={newBusiness.name}
                  onChange={(e) => setNewBusiness(prev => ({ ...prev, name: e.target.value }))}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent dark:bg-gray-800 dark:text-white"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Business Type *
                </label>
                <select
                  value={newBusiness.business_type}
                  onChange={(e) => setNewBusiness(prev => ({ ...prev, business_type: e.target.value as BusinessType }))}
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
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Phone Number
                </label>
                <input
                  type="tel"
                  value={newBusiness.phone}
                  onChange={(e) => setNewBusiness(prev => ({ ...prev, phone: e.target.value }))}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent dark:bg-gray-800 dark:text-white"
                  placeholder="+254..."
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Location
                </label>
                <input
                  type="text"
                  value={newBusiness.location}
                  onChange={(e) => setNewBusiness(prev => ({ ...prev, location: e.target.value }))}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent dark:bg-gray-800 dark:text-white"
                  placeholder="Nairobi, Kenya"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Description
                </label>
                <textarea
                  value={newBusiness.description}
                  onChange={(e) => setNewBusiness(prev => ({ ...prev, description: e.target.value }))}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent dark:bg-gray-800 dark:text-white"
                  rows={3}
                  placeholder="Brief description of your business..."
                />
              </div>

              <button
                type="submit"
                disabled={createLoading}
                className="w-full bg-primary-600 hover:bg-primary-700 disabled:bg-primary-400 text-white py-2 px-4 rounded-lg font-medium transition-colors"
              >
                {createLoading ? 'Creating...' : 'Create Business'}
              </button>
            </form>
          </Dialog.Panel>
        </div>
      </Dialog>
    </div>
  );
}

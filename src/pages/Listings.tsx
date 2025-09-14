import React, { useState, useEffect, useCallback } from 'react';
import { supabase, type Listing } from '../lib/supabase';
import PageHeader from '../components/PageHeader';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Badge } from '../components/ui/Badge';
import { Modal } from '../components/ui/Modal';
import { Input } from '../components/ui/Input';
import { PlusIcon, Star, MapPin } from 'lucide-react';

interface ListingsPageProps {
  businessId: string;
}

const placeholderImage = "https://img-wrapper.vercel.app/image?url=https://placehold.co/600x400/e2e8f0/e2e8f0";

export default function Listings({ businessId }: ListingsPageProps) {
  const [listings, setListings] = useState<Listing[]>([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [newListing, setNewListing] = useState({
    name: '',
    location: '',
    rate_per_night: '',
  });

  const fetchListings = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('listings')
        .select('*')
        .eq('business_id', businessId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setListings(data || []);
    } catch (error) {
      console.error('Error fetching listings:', error);
    } finally {
      setLoading(false);
    }
  }, [businessId]);

  useEffect(() => {
    if (businessId) {
      fetchListings();
    }
  }, [businessId, fetchListings]);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setNewListing(prev => ({ ...prev, [name]: value }));
  };

  const handleAddListing = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!businessId) return;

    try {
      const { data, error } = await supabase
        .from('listings')
        .insert([{
          ...newListing,
          business_id: businessId,
          rate_per_night: parseFloat(newListing.rate_per_night),
          status: 'Listed',
        }])
        .select()
        .single();
      
      if (error) throw error;
      
      setListings(prev => [data, ...prev]);
      setIsModalOpen(false);
      setNewListing({ name: '', location: '', rate_per_night: '' });
    } catch (error) {
      console.error('Error adding listing:', error);
      alert(`Failed to add listing: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  };

  const getStatusVariant = (status: Listing['status']) => {
    switch (status) {
      case 'Listed': return 'success';
      case 'Booked': return 'warning';
      case 'Maintenance': return 'danger';
      default: return 'default';
    }
  };

  if (loading) {
    return <div className="text-center py-12">Loading listings...</div>;
  }

  return (
    <div>
      <PageHeader
        title="Airbnb Listings"
        subtitle="Manage all your short-term rental listings."
        actions={
          <Button icon={<PlusIcon />} onClick={() => setIsModalOpen(true)}>
            New Listing
          </Button>
        }
      />
      {listings.length === 0 ? (
        <Card>
          <CardContent className="text-center py-12">
            <h3 className="text-lg font-medium text-gray-900 dark:text-white">No Listings Found</h3>
            <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">Create your first Airbnb listing.</p>
            <div className="mt-6">
              <Button icon={<PlusIcon />} onClick={() => setIsModalOpen(true)}>Create First Listing</Button>
            </div>
          </CardContent>
        </Card>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {listings.map((listing) => (
            <Card key={listing.id}>
              <img src={listing.image_url || placeholderImage} alt={listing.name} className="h-48 w-full object-cover rounded-t-xl bg-gray-200" />
              <CardContent>
                <div className="flex justify-between items-start mb-2">
                  <h3 className="font-bold text-lg text-gray-900 dark:text-white leading-tight">{listing.name}</h3>
                  <Badge variant={getStatusVariant(listing.status)}>
                    {listing.status}
                  </Badge>
                </div>
                <div className="flex items-center text-sm text-gray-500 dark:text-gray-400 mb-2">
                  <MapPin className="h-4 w-4 mr-1" />
                  {listing.location}
                </div>
                <div className="flex justify-between items-center">
                  <p className="font-semibold text-gray-800 dark:text-gray-200">KSh {listing.rate_per_night.toLocaleString()} / night</p>
                  <div className="flex items-center">
                    <Star className="h-4 w-4 text-yellow-400 mr-1" />
                    <span className="font-medium text-gray-700 dark:text-gray-300">New</span>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      <Modal isOpen={isModalOpen} onClose={() => setIsModalOpen(false)} title="Create New Listing">
        <form onSubmit={handleAddListing} className="space-y-4">
          <Input name="name" placeholder="Listing Name (e.g., Cozy Studio in Kilimani)" onChange={handleInputChange} required />
          <Input name="location" placeholder="Location (e.g., Nairobi)" onChange={handleInputChange} required />
          <Input name="rate_per_night" type="number" placeholder="Rate per Night (KSh)" onChange={handleInputChange} required />
          <div className="flex justify-end space-x-2 pt-4">
            <Button type="button" variant="secondary" onClick={() => setIsModalOpen(false)}>Cancel</Button>
            <Button type="submit">Create Listing</Button>
          </div>
        </form>
      </Modal>
    </div>
  );
}

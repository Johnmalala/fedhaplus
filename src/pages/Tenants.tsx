import React, { useState, useEffect, useCallback } from 'react';
import { supabase, type Tenant } from '../lib/supabase';
import PageHeader from '../components/PageHeader';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Table, TableHeader, TableHead, TableBody, TableRow, TableCell } from '../components/ui/Table';
import { Badge } from '../components/ui/Badge';
import { Modal } from '../components/ui/Modal';
import { Input } from '../components/ui/Input';
import { PlusIcon, MoreVertical } from 'lucide-react';

interface TenantsPageProps {
  businessId: string;
}

export default function Tenants({ businessId }: TenantsPageProps) {
  const [tenants, setTenants] = useState<Tenant[]>([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [newTenant, setNewTenant] = useState({
    name: '',
    phone: '',
    unit_number: '',
    rent_amount: '',
    lease_start: new Date().toISOString().split('T')[0],
  });

  const fetchTenants = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('tenants')
        .select('*')
        .eq('business_id', businessId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setTenants(data || []);
    } catch (error) {
      console.error('Error fetching tenants:', error);
    } finally {
      setLoading(false);
    }
  }, [businessId]);

  useEffect(() => {
    if (businessId) {
      fetchTenants();
    }
  }, [businessId, fetchTenants]);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setNewTenant(prev => ({ ...prev, [name]: value }));
  };

  const handleAddTenant = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!businessId) return;

    try {
      const { data, error } = await supabase
        .from('tenants')
        .insert([{
          ...newTenant,
          business_id: businessId,
          rent_amount: parseFloat(newTenant.rent_amount),
          is_active: true,
        }])
        .select()
        .single();
      
      if (error) throw error;
      
      setTenants(prev => [data, ...prev]);
      setIsModalOpen(false);
      setNewTenant({ name: '', phone: '', unit_number: '', rent_amount: '', lease_start: new Date().toISOString().split('T')[0] });
    } catch (error) {
      console.error('Error adding tenant:', error);
      alert(`Failed to add tenant: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  };

  return (
    <div>
      <PageHeader
        title="Tenants"
        subtitle="Manage all your tenants and properties."
        actions={
          <Button icon={<PlusIcon />} onClick={() => setIsModalOpen(true)}>
            Add Tenant
          </Button>
        }
      />
      <Card>
        <CardContent>
          {loading ? (
            <div className="text-center py-12">Loading tenants...</div>
          ) : tenants.length === 0 ? (
            <div className="text-center py-12">
              <h3 className="text-lg font-medium text-gray-900 dark:text-white">No tenants found</h3>
              <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">Get started by adding your first tenant.</p>
              <div className="mt-6">
                  <Button icon={<PlusIcon />} onClick={() => setIsModalOpen(true)}>
                      Add First Tenant
                  </Button>
              </div>
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableHead>Tenant Name</TableHead>
                <TableHead>Unit No.</TableHead>
                <TableHead>Phone</TableHead>
                <TableHead>Rent Amount</TableHead>
                <TableHead>Status</TableHead>
                <TableHead><span className="sr-only">Actions</span></TableHead>
              </TableHeader>
              <TableBody>
                {tenants.map((tenant) => (
                  <TableRow key={tenant.id}>
                    <TableCell><div className="font-medium">{tenant.name}</div></TableCell>
                    <TableCell>{tenant.unit_number}</TableCell>
                    <TableCell>{tenant.phone}</TableCell>
                    <TableCell>KSh {tenant.rent_amount.toLocaleString()}</TableCell>
                    <TableCell>
                      <Badge variant={tenant.is_active ? 'success' : 'danger'}>
                        {tenant.is_active ? 'Active' : 'Inactive'}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-right">
                      <Button variant="ghost" size="sm" icon={<MoreVertical />} />
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      <Modal isOpen={isModalOpen} onClose={() => setIsModalOpen(false)} title="Add New Tenant">
        <form onSubmit={handleAddTenant} className="space-y-4">
          <Input name="name" placeholder="Tenant Full Name" onChange={handleInputChange} required />
          <Input name="phone" type="tel" placeholder="Phone Number (e.g., 254...)" onChange={handleInputChange} required />
          <Input name="unit_number" placeholder="Unit / House Number" onChange={handleInputChange} required />
          <Input name="rent_amount" type="number" placeholder="Monthly Rent (KSh)" onChange={handleInputChange} required />
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Lease Start Date</label>
            <Input name="lease_start" type="date" onChange={handleInputChange} value={newTenant.lease_start} required />
          </div>
          <div className="flex justify-end space-x-2 pt-4">
            <Button type="button" variant="secondary" onClick={() => setIsModalOpen(false)}>Cancel</Button>
            <Button type="submit">Add Tenant</Button>
          </div>
        </form>
      </Modal>
    </div>
  );
}

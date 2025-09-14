import React, { useState, useEffect, useCallback } from 'react';
import { supabase, type Tenant } from '../lib/supabase';
import PageHeader from '../components/PageHeader';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Table, TableHeader, TableHead, TableBody, TableRow, TableCell } from '../components/ui/Table';
import { Badge } from '../components/ui/Badge';
import { Modal } from '../components/ui/Modal';
import { Input } from '../components/ui/Input';
import { PlusIcon, MoreVertical, Pencil, Trash2 } from 'lucide-react';
import { Menu, Transition } from '@headlessui/react';
import { ConfirmDeleteModal } from '../components/ui/ConfirmDeleteModal';

interface TenantsPageProps {
  businessId: string;
}

export default function Tenants({ businessId }: TenantsPageProps) {
  const [tenants, setTenants] = useState<Tenant[]>([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingTenant, setEditingTenant] = useState<Tenant | null>(null);
  const [deletingTenant, setDeletingTenant] = useState<Tenant | null>(null);
  const [deleteLoading, setDeleteLoading] = useState(false);

  const [tenantForm, setTenantForm] = useState({
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

  useEffect(() => {
    if (editingTenant) {
      setTenantForm({
        name: editingTenant.name,
        phone: editingTenant.phone,
        unit_number: editingTenant.unit_number,
        rent_amount: String(editingTenant.rent_amount),
        lease_start: new Date(editingTenant.lease_start).toISOString().split('T')[0],
      });
    } else {
      setTenantForm({ name: '', phone: '', unit_number: '', rent_amount: '', lease_start: new Date().toISOString().split('T')[0] });
    }
  }, [editingTenant, isModalOpen]);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setTenantForm(prev => ({ ...prev, [name]: value }));
  };

  const openAddModal = () => {
    setEditingTenant(null);
    setIsModalOpen(true);
  };

  const openEditModal = (tenant: Tenant) => {
    setEditingTenant(tenant);
    setIsModalOpen(true);
  };

  const closeModal = () => {
    setIsModalOpen(false);
    setEditingTenant(null);
  };

  const handleSaveTenant = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!businessId) return;

    const tenantData = {
      ...tenantForm,
      business_id: businessId,
      rent_amount: parseFloat(tenantForm.rent_amount),
    };

    try {
      let savedTenant: Tenant | null = null;
      if (editingTenant) {
        const { data, error } = await supabase
          .from('tenants')
          .update(tenantData)
          .eq('id', editingTenant.id)
          .select()
          .single();
        if (error) throw error;
        savedTenant = data;
        setTenants(prev => prev.map(t => t.id === savedTenant!.id ? savedTenant! : t));
      } else {
        const { data, error } = await supabase
          .from('tenants')
          .insert({ ...tenantData, is_active: true })
          .select()
          .single();
        if (error) throw error;
        savedTenant = data;
        setTenants(prev => [savedTenant!, ...prev]);
      }
      closeModal();
    } catch (error) {
      console.error('Error saving tenant:', error);
    }
  };

  const handleDeleteTenant = async () => {
    if (!deletingTenant) return;
    setDeleteLoading(true);
    try {
      const { error } = await supabase.from('tenants').delete().eq('id', deletingTenant.id);
      if (error) throw error;
      setTenants(prev => prev.filter(t => t.id !== deletingTenant.id));
      setDeletingTenant(null);
    } catch (error) {
      console.error('Error deleting tenant:', error);
    } finally {
      setDeleteLoading(false);
    }
  };

  return (
    <div>
      <PageHeader
        title="Tenants"
        subtitle="Manage all your tenants and properties."
        actions={
          <Button icon={<PlusIcon />} onClick={openAddModal}>
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
                  <Button icon={<PlusIcon />} onClick={openAddModal}>
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
                       <Menu as="div" className="relative inline-block text-left">
                        <Menu.Button as={Button} variant="ghost" size="sm" icon={<MoreVertical className="h-4 w-4" />} />
                        <Transition as={React.Fragment} enter="transition ease-out duration-100" enterFrom="transform opacity-0 scale-95" enterTo="transform opacity-100 scale-100" leave="transition ease-in duration-75" leaveFrom="transform opacity-100 scale-100" leaveTo="transform opacity-0 scale-95">
                          <Menu.Items className="absolute right-0 z-10 mt-2 w-32 origin-top-right rounded-md bg-white dark:bg-gray-800 shadow-lg ring-1 ring-black/5 focus:outline-none">
                            <div className="px-1 py-1">
                              <Menu.Item>
                                {({ active }) => (
                                  <button onClick={() => openEditModal(tenant)} className={`${active ? 'bg-primary-100 dark:bg-gray-700' : ''} text-gray-900 dark:text-gray-100 group flex w-full items-center rounded-md px-2 py-2 text-sm`}>
                                    <Pencil className="mr-2 h-4 w-4" /> Edit
                                  </button>
                                )}
                              </Menu.Item>
                              <Menu.Item>
                                {({ active }) => (
                                  <button onClick={() => setDeletingTenant(tenant)} className={`${active ? 'bg-red-100 dark:bg-red-700' : ''} text-red-700 dark:text-red-400 group flex w-full items-center rounded-md px-2 py-2 text-sm`}>
                                    <Trash2 className="mr-2 h-4 w-4" /> Delete
                                  </button>
                                )}
                              </Menu.Item>
                            </div>
                          </Menu.Items>
                        </Transition>
                      </Menu>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      <Modal isOpen={isModalOpen} onClose={closeModal} title={editingTenant ? "Edit Tenant" : "Add New Tenant"}>
        <form onSubmit={handleSaveTenant} className="space-y-4">
          <Input name="name" placeholder="Tenant Full Name" value={tenantForm.name} onChange={handleInputChange} required />
          <Input name="phone" type="tel" placeholder="Phone Number (e.g., 254...)" value={tenantForm.phone} onChange={handleInputChange} required />
          <Input name="unit_number" placeholder="Unit / House Number" value={tenantForm.unit_number} onChange={handleInputChange} required />
          <Input name="rent_amount" type="number" placeholder="Monthly Rent (KSh)" value={tenantForm.rent_amount} onChange={handleInputChange} required />
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Lease Start Date</label>
            <Input name="lease_start" type="date" value={tenantForm.lease_start} onChange={handleInputChange} required />
          </div>
          <div className="flex justify-end space-x-2 pt-4">
            <Button type="button" variant="secondary" onClick={closeModal}>Cancel</Button>
            <Button type="submit">{editingTenant ? "Save Changes" : "Add Tenant"}</Button>
          </div>
        </form>
      </Modal>

      {deletingTenant && (
        <ConfirmDeleteModal
          isOpen={!!deletingTenant}
          onClose={() => setDeletingTenant(null)}
          onConfirm={handleDeleteTenant}
          itemName={deletingTenant.name}
          loading={deleteLoading}
          title="Delete Tenant"
          message={`Are you sure you want to delete ${deletingTenant.name}? This will also delete all associated rent payments.`}
          confirmText="Delete"
        />
      )}
    </div>
  );
}

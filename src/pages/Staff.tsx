import React, { useState, useEffect, useCallback } from 'react';
import { supabase, type StaffRole as StaffRoleType } from '../lib/supabase';
import PageHeader from '../components/PageHeader';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Badge } from '../components/ui/Badge';
import { Modal } from '../components/ui/Modal';
import { Input } from '../components/ui/Input';
import { PlusIcon, UserCircle, MoreVertical, ToggleLeft, ToggleRight } from 'lucide-react';
import { Menu, Transition } from '@headlessui/react';
import { ConfirmDeleteModal } from '../components/ui/ConfirmDeleteModal';

interface StaffPageProps {
  businessId: string;
}

type StaffMember = StaffRoleType & {
  profiles: { full_name: string; email: string } | null;
};

export default function Staff({ businessId }: StaffPageProps) {
  const [staff, setStaff] = useState<StaffMember[]>([]);
  const [loading, setLoading] = useState(true);
  const [isInviteModalOpen, setIsInviteModalOpen] = useState(false);
  const [togglingStaff, setTogglingStaff] = useState<StaffMember | null>(null);
  
  const [invite, setInvite] = useState({ email: '', role: 'cashier' as StaffRoleType['role'] });
  const [inviteError, setInviteError] = useState('');

  const fetchStaff = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('staff_roles')
        .select('*, profiles(full_name, email)')
        .eq('business_id', businessId);

      if (error) throw error;
      setStaff(data as StaffMember[] || []);
    } catch (error) {
      console.error('Error fetching staff:', error);
    } finally {
      setLoading(false);
    }
  }, [businessId]);

  useEffect(() => {
    if (businessId) {
      fetchStaff();
    }
  }, [businessId, fetchStaff]);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setInvite(prev => ({ ...prev, [name]: value }));
  };

  const handleInviteStaff = async (e: React.FormEvent) => {
    e.preventDefault();
    setInviteError('');
    if (!businessId) return;

    try {
      const { error } = await supabase.rpc('invite_staff', {
        p_business_id: businessId,
        p_invitee_email: invite.email,
        p_role: invite.role,
      });

      if (error) throw error;

      await fetchStaff();
      setIsInviteModalOpen(false);
      setInvite({ email: '', role: 'cashier' });
    } catch (error) {
      console.error('Error inviting staff:', error);
      setInviteError(error instanceof Error ? error.message : 'An unknown error occurred.');
    }
  };

  const handleToggleActive = async () => {
    if (!togglingStaff) return;
    try {
      const { data, error } = await supabase
        .from('staff_roles')
        .update({ is_active: !togglingStaff.is_active })
        .eq('id', togglingStaff.id)
        .select()
        .single();
      
      if (error) throw error;
      setStaff(prev => prev.map(s => s.id === data.id ? { ...s, is_active: data.is_active } : s));
      setTogglingStaff(null);
    } catch (error) {
      console.error('Error toggling staff status:', error);
    }
  };

  const staffRoles: StaffRoleType['role'][] = ['manager', 'cashier', 'accountant', 'teacher', 'front_desk', 'housekeeper'];

  return (
    <div>
      <PageHeader
        title="Staff Management"
        subtitle="Invite and manage staff members for your business."
        actions={
          <Button icon={<PlusIcon />} onClick={() => setIsInviteModalOpen(true)}>
            Invite Staff
          </Button>
        }
      />
      <Card>
        <CardContent>
          {loading ? (
            <div className="text-center py-12">Loading staff...</div>
          ) : staff.length === 0 ? (
            <div className="text-center py-12">
              <h3 className="text-lg font-medium text-gray-900 dark:text-white">No staff members found</h3>
              <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">Invite your first staff member to get started.</p>
              <div className="mt-6">
                  <Button icon={<PlusIcon />} onClick={() => setIsInviteModalOpen(true)}>
                      Invite Staff
                  </Button>
              </div>
            </div>
          ) : (
            <ul className="divide-y divide-gray-200 dark:divide-gray-700">
              {staff.map((staffMember) => (
                <li key={staffMember.id} className="py-4 flex items-center justify-between">
                  <div className="flex items-center">
                    <UserCircle className="h-10 w-10 text-gray-400" />
                    <div className="ml-3">
                      <p className="text-sm font-medium text-gray-900 dark:text-white">{staffMember.profiles?.full_name || 'Invited User'}</p>
                      <p className="text-sm text-gray-500 dark:text-gray-400">{staffMember.profiles?.email}</p>
                    </div>
                  </div>
                  <div className="flex items-center space-x-4">
                    <Badge>{staffMember.role}</Badge>
                    <Badge variant={staffMember.is_active ? 'success' : 'danger'}>
                      {staffMember.is_active ? 'Active' : 'Inactive'}
                    </Badge>
                     <Menu as="div" className="relative inline-block text-left">
                        <Menu.Button as={Button} variant="ghost" size="sm" icon={<MoreVertical className="h-4 w-4" />} />
                        <Transition as={React.Fragment} enter="transition ease-out duration-100" enterFrom="transform opacity-0 scale-95" enterTo="transform opacity-100 scale-100" leave="transition ease-in duration-75" leaveFrom="transform opacity-100 scale-100" leaveTo="transform opacity-0 scale-95">
                          <Menu.Items className="absolute right-0 z-10 mt-2 w-40 origin-top-right rounded-md bg-white dark:bg-gray-800 shadow-lg ring-1 ring-black/5 focus:outline-none">
                            <div className="px-1 py-1">
                              <Menu.Item>
                                {({ active }) => (
                                  <button onClick={() => setTogglingStaff(staffMember)} className={`${active ? 'bg-primary-100 dark:bg-gray-700' : ''} text-gray-900 dark:text-gray-100 group flex w-full items-center rounded-md px-2 py-2 text-sm`}>
                                    {staffMember.is_active ? <ToggleLeft className="mr-2 h-4 w-4 text-red-500" /> : <ToggleRight className="mr-2 h-4 w-4 text-green-500" />}
                                    {staffMember.is_active ? 'Deactivate' : 'Activate'}
                                  </button>
                                )}
                              </Menu.Item>
                            </div>
                          </Menu.Items>
                        </Transition>
                      </Menu>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>

      <Modal isOpen={isInviteModalOpen} onClose={() => setIsInviteModalOpen(false)} title="Invite Staff Member">
        <form onSubmit={handleInviteStaff} className="space-y-4">
          {inviteError && <div className="bg-red-100 text-red-700 p-3 rounded-lg text-sm">{inviteError}</div>}
          <p className="text-sm text-gray-600 dark:text-gray-400">
            Enter the email of an existing Fedha Plus user to add them to your business. If they don't have an account, please ask them to sign up first.
          </p>
          <Input name="email" type="email" placeholder="staff@example.com" onChange={handleInputChange} required />
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Role</label>
            <select name="role" onChange={handleInputChange} value={invite.role} required className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent dark:bg-gray-800 dark:text-white">
              {staffRoles.map(role => (
                <option key={role} value={role} className="capitalize">{role.replace('_', ' ')}</option>
              ))}
            </select>
          </div>
          <div className="flex justify-end space-x-2 pt-4">
            <Button type="button" variant="secondary" onClick={() => { setIsInviteModalOpen(false); setInviteError(''); }}>Cancel</Button>
            <Button type="submit">Send Invite</Button>
          </div>
        </form>
      </Modal>

      {togglingStaff && (
        <ConfirmDeleteModal
          isOpen={!!togglingStaff}
          onClose={() => setTogglingStaff(null)}
          onConfirm={handleToggleActive}
          itemName={togglingStaff.profiles?.full_name || togglingStaff.profiles?.email || 'this staff member'}
          loading={false}
          title={togglingStaff.is_active ? "Deactivate Staff" : "Activate Staff"}
          message={`Are you sure you want to ${togglingStaff.is_active ? 'deactivate' : 'activate'} this staff member?`}
          confirmText={togglingStaff.is_active ? "Deactivate" : "Activate"}
          confirmVariant={togglingStaff.is_active ? "danger" : "primary"}
        />
      )}
    </div>
  );
}

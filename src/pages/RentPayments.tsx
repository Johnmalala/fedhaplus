import React, { useState, useEffect, useCallback } from 'react';
import { supabase, type RentPayment, type Tenant } from '../lib/supabase';
import PageHeader from '../components/PageHeader';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Table, TableHeader, TableHead, TableBody, TableRow, TableCell } from '../components/ui/Table';
import { Badge } from '../components/ui/Badge';
import { PlusIcon, MoreVertical } from 'lucide-react';
import { format } from 'date-fns';
import { Modal } from '../components/ui/Modal';
import { Input } from '../components/ui/Input';

interface RentPaymentsPageProps {
  businessId: string;
}

type RentPaymentWithTenant = RentPayment & {
  tenants: { name: string; unit_number: string } | null;
};

export default function RentPayments({ businessId }: RentPaymentsPageProps) {
  const [payments, setPayments] = useState<RentPaymentWithTenant[]>([]);
  const [tenants, setTenants] = useState<Tenant[]>([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [newPayment, setNewPayment] = useState({
    tenant_id: '',
    amount: '',
    mpesa_code: '',
    notes: '',
  });

  const fetchPayments = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('rent_payments')
        .select('*, tenants(name, unit_number)')
        .eq('business_id', businessId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setPayments(data as RentPaymentWithTenant[] || []);
    } catch (error) {
      console.error('Error fetching rent payments:', error);
    } finally {
      setLoading(false);
    }
  }, [businessId]);

  const fetchTenants = useCallback(async () => {
    try {
      const { data, error } = await supabase
        .from('tenants')
        .select('id, name, unit_number, rent_amount')
        .eq('business_id', businessId)
        .eq('is_active', true);
      if (error) throw error;
      setTenants(data || []);
    } catch (error) {
      console.error('Error fetching tenants:', error);
    }
  }, [businessId]);

  useEffect(() => {
    if (businessId) {
      fetchPayments();
      fetchTenants();
    }
  }, [businessId, fetchPayments, fetchTenants]);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setNewPayment(prev => ({ ...prev, [name]: value }));
  };
  
  const handleTenantSelect = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const tenantId = e.target.value;
    const selectedTenant = tenants.find(t => t.id === tenantId);
    setNewPayment(prev => ({
      ...prev,
      tenant_id: tenantId,
      amount: selectedTenant ? String(selectedTenant.rent_amount) : ''
    }));
  };

  const handleAddPayment = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!businessId || !newPayment.tenant_id) return;

    try {
      const { data, error } = await supabase
        .from('rent_payments')
        .insert([{
          ...newPayment,
          business_id: businessId,
          amount: parseFloat(newPayment.amount),
          payment_date: new Date().toISOString(),
          status: 'paid',
        }])
        .select('*, tenants(name, unit_number)')
        .single();
      
      if (error) throw error;
      
      setPayments(prev => [data as RentPaymentWithTenant, ...prev]);
      setIsModalOpen(false);
      setNewPayment({ tenant_id: '', amount: '', mpesa_code: '', notes: '' });
    } catch (error) {
      console.error('Error adding payment:', error);
    }
  };

  return (
    <div>
      <PageHeader
        title="Rent Payments"
        subtitle="Track and manage tenant rent payments."
        actions={
          <Button icon={<PlusIcon />} onClick={() => setIsModalOpen(true)}>
            Record Payment
          </Button>
        }
      />
      <Card>
        <CardContent>
          {loading ? <p className="py-12 text-center">Loading payments...</p> : payments.length === 0 ? (
            <div className="text-center py-12">
              <h3 className="text-lg font-medium text-gray-900 dark:text-white">No Payments Recorded</h3>
              <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">Record your first rent payment.</p>
              <div className="mt-6">
                <Button icon={<PlusIcon />} onClick={() => setIsModalOpen(true)}>Record First Payment</Button>
              </div>
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableHead>Tenant Name</TableHead>
                <TableHead>Unit No.</TableHead>
                <TableHead>Date</TableHead>
                <TableHead>Amount</TableHead>
                <TableHead>Status</TableHead>
                <TableHead><span className="sr-only">Actions</span></TableHead>
              </TableHeader>
              <TableBody>
                {payments.map((payment) => (
                  <TableRow key={payment.id}>
                    <TableCell><div className="font-medium">{payment.tenants?.name}</div></TableCell>
                    <TableCell>{payment.tenants?.unit_number}</TableCell>
                    <TableCell>{format(new Date(payment.payment_date), 'MMM dd, yyyy')}</TableCell>
                    <TableCell>KSh {payment.amount.toLocaleString()}</TableCell>
                    <TableCell>
                      <Badge variant={payment.status === 'paid' ? 'success' : 'warning'}>
                        {payment.status}
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

      <Modal isOpen={isModalOpen} onClose={() => setIsModalOpen(false)} title="Record Rent Payment">
        <form onSubmit={handleAddPayment} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Tenant</label>
            <select name="tenant_id" onChange={handleTenantSelect} value={newPayment.tenant_id} required className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent dark:bg-gray-800 dark:text-white">
              <option value="" disabled>Select a tenant</option>
              {tenants.map(t => <option key={t.id} value={t.id}>{t.name} ({t.unit_number})</option>)}
            </select>
          </div>
          <Input name="amount" type="number" placeholder="Amount" value={newPayment.amount} onChange={handleInputChange} required />
          <Input name="mpesa_code" placeholder="M-Pesa Code (Optional)" onChange={handleInputChange} />
          <Input name="notes" placeholder="Notes (Optional)" onChange={handleInputChange} />
          <div className="flex justify-end space-x-2 pt-4">
            <Button type="button" variant="secondary" onClick={() => setIsModalOpen(false)}>Cancel</Button>
            <Button type="submit">Record Payment</Button>
          </div>
        </form>
      </Modal>
    </div>
  );
}

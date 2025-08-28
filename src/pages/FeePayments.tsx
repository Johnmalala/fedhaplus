import React, { useState, useEffect, useCallback } from 'react';
import { supabase, type FeePayment, type Student } from '../lib/supabase';
import PageHeader from '../components/PageHeader';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Table, TableHeader, TableHead, TableBody, TableRow, TableCell } from '../components/ui/Table';
import { Badge } from '../components/ui/Badge';
import { PlusIcon, MoreVertical } from 'lucide-react';
import { format } from 'date-fns';
import { Modal } from '../components/ui/Modal';
import { Input } from '../components/ui/Input';

interface FeePaymentsPageProps {
  businessId: string;
}

type FeePaymentWithStudent = FeePayment & {
  students: { first_name: string; last_name: string; admission_number: string } | null;
};

export default function FeePayments({ businessId }: FeePaymentsPageProps) {
  const [payments, setPayments] = useState<FeePaymentWithStudent[]>([]);
  const [students, setStudents] = useState<Student[]>([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [newPayment, setNewPayment] = useState({
    student_id: '',
    amount: '',
    mpesa_code: '',
    term: 'Term 1',
  });

  const fetchPayments = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('fee_payments')
        .select('*, students(first_name, last_name, admission_number)')
        .eq('business_id', businessId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setPayments(data as FeePaymentWithStudent[] || []);
    } catch (error) {
      console.error('Error fetching payments:', error);
    } finally {
      setLoading(false);
    }
  }, [businessId]);

  const fetchStudents = useCallback(async () => {
    try {
      const { data, error } = await supabase
        .from('students')
        .select('*')
        .eq('business_id', businessId);
      if (error) throw error;
      setStudents(data || []);
    } catch (error) {
      console.error('Error fetching students:', error);
    }
  }, [businessId]);

  useEffect(() => {
    if (businessId) {
      fetchPayments();
      fetchStudents();
    }
  }, [businessId, fetchPayments, fetchStudents]);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setNewPayment(prev => ({ ...prev, [name]: value }));
  };

  const handleAddPayment = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!businessId || !newPayment.student_id) return;

    try {
      const { data, error } = await supabase
        .from('fee_payments')
        .insert([{ 
          ...newPayment, 
          business_id: businessId, 
          amount: parseFloat(newPayment.amount),
          payment_date: new Date().toISOString(),
          status: 'paid'
        }])
        .select('*, students(first_name, last_name, admission_number)')
        .single();
      
      if (error) throw error;
      
      // TODO: Generate PDF receipt and send SMS confirmation via Edge Functions
      console.log(`Simulating SMS for payment of ${newPayment.amount}`);

      setPayments(prev => [data as FeePaymentWithStudent, ...prev]);
      setIsModalOpen(false);
      setNewPayment({ student_id: '', amount: '', mpesa_code: '', term: 'Term 1' });
    } catch (error) {
      console.error('Error adding payment:', error);
    }
  };

  return (
    <div>
      <PageHeader
        title="Fee Payments"
        subtitle="Track and manage student fee payments."
        actions={
          <Button icon={<PlusIcon />} onClick={() => setIsModalOpen(true)}>
            Record Payment
          </Button>
        }
      />
      <Card>
        <CardContent>
          {loading ? <p>Loading payments...</p> : (
            <Table>
              <TableHeader>
                <TableHead>Student Name</TableHead>
                <TableHead>Admission No.</TableHead>
                <TableHead>Date</TableHead>
                <TableHead>Amount</TableHead>
                <TableHead>Status</TableHead>
                <TableHead><span className="sr-only">Actions</span></TableHead>
              </TableHeader>
              <TableBody>
                {payments.map((payment) => (
                  <TableRow key={payment.id}>
                    <TableCell><div className="font-medium">{payment.students?.first_name} {payment.students?.last_name}</div></TableCell>
                    <TableCell>{payment.students?.admission_number}</TableCell>
                    <TableCell>{format(new Date(payment.created_at), 'MMM dd, yyyy')}</TableCell>
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

      <Modal isOpen={isModalOpen} onClose={() => setIsModalOpen(false)} title="Record Fee Payment">
        <form onSubmit={handleAddPayment} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Student</label>
            <select name="student_id" onChange={handleInputChange} value={newPayment.student_id} required className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent dark:bg-gray-800 dark:text-white">
              <option value="" disabled>Select a student</option>
              {students.map(s => <option key={s.id} value={s.id}>{s.first_name} {s.last_name} ({s.admission_number})</option>)}
            </select>
          </div>
          <Input name="amount" type="number" placeholder="Amount" onChange={handleInputChange} required />
          <Input name="mpesa_code" placeholder="M-Pesa Code (Optional)" onChange={handleInputChange} />
          <Input name="term" placeholder="Term (e.g., Term 1)" onChange={handleInputChange} required value={newPayment.term} />
          <div className="flex justify-end space-x-2 pt-4">
            <Button type="button" variant="secondary" onClick={() => setIsModalOpen(false)}>Cancel</Button>
            <Button type="submit">Record Payment</Button>
          </div>
        </form>
      </Modal>
    </div>
  );
}

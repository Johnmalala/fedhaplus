import React, { useState, useEffect, useCallback } from 'react';
import { supabase, type FeePayment } from '../../../lib/supabase';
import PageHeader from '../../PageHeader';
import { Card, CardContent } from '../../ui/Card';
import { Button } from '../../ui/Button';
import { Table, TableHeader, TableHead, TableBody, TableRow, TableCell } from '../../ui/Table';
import { Badge } from '../../ui/Badge';
import { format } from 'date-fns';
import { Printer } from 'lucide-react';
import jsPDF from 'jspdf';
import 'jspdf-autotable';

interface FeeReportProps {
  businessId: string;
}

type FeePaymentWithDetails = FeePayment & {
  students: {
    first_name: string;
    last_name: string;
    admission_number: string;
  } | null;
};

declare module 'jspdf' {
  interface jsPDF {
    autoTable: (options: any) => jsPDF;
  }
}

export default function FeeReport({ businessId }: FeeReportProps) {
  const [payments, setPayments] = useState<FeePaymentWithDetails[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchPayments = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('fee_payments')
        .select('*, students(first_name, last_name, admission_number)')
        .eq('business_id', businessId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setPayments(data as FeePaymentWithDetails[] || []);
    } catch (error) {
      console.error('Error fetching fee report data:', error);
    } finally {
      setLoading(false);
    }
  }, [businessId]);

  useEffect(() => {
    fetchPayments();
  }, [fetchPayments]);

  const printReport = () => {
    const doc = new jsPDF();
    doc.text("Fee Collection Report", 14, 16);
    
    const tableColumn = ["Date", "Student Name", "Adm No.", "Term", "Amount (KSh)"];
    const tableRows: (string | number)[][] = [];

    payments.forEach(payment => {
      const paymentData = [
        format(new Date(payment.payment_date), 'yyyy-MM-dd'),
        `${payment.students?.first_name || ''} ${payment.students?.last_name || ''}`,
        payment.students?.admission_number || '',
        payment.term,
        payment.amount.toLocaleString(),
      ];
      tableRows.push(paymentData);
    });

    doc.autoTable({
      head: [tableColumn],
      body: tableRows,
      startY: 20,
    });
    
    doc.save(`fee_report_${new Date().toISOString().split('T')[0]}.pdf`);
  };

  if (loading) {
    return <div className="text-center py-12">Generating fee report...</div>;
  }

  return (
    <div>
      <PageHeader
        title="Fee Collection Report"
        subtitle={`A detailed summary of all student fee payments.`}
        actions={
          <Button icon={<Printer />} onClick={printReport} disabled={payments.length === 0}>
            Print Report
          </Button>
        }
      />
      <Card>
        <CardContent>
          {payments.length === 0 ? (
            <div className="text-center py-12">
              <h3 className="text-lg font-medium text-gray-900 dark:text-white">No Fee Data</h3>
              <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">There are no fee payments recorded for this business yet.</p>
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableHead>Student Name</TableHead>
                <TableHead>Admission No.</TableHead>
                <TableHead>Date</TableHead>
                <TableHead>Term</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Total Amount</TableHead>
              </TableHeader>
              <TableBody>
                {payments.map((payment) => (
                  <TableRow key={payment.id}>
                    <TableCell>
                      <div className="font-medium">{payment.students?.first_name} {payment.students?.last_name}</div>
                    </TableCell>
                    <TableCell>{payment.students?.admission_number}</TableCell>
                    <TableCell>{format(new Date(payment.payment_date), 'MMM dd, yyyy')}</TableCell>
                    <TableCell>{payment.term}</TableCell>
                    <TableCell><Badge variant={payment.status === 'paid' ? 'success' : 'warning'}>{payment.status}</Badge></TableCell>
                    <TableCell>KSh {payment.amount.toLocaleString()}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

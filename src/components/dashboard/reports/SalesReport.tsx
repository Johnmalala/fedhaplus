import React, { useState, useEffect, useCallback } from 'react';
import { supabase, type Sale } from '../../../lib/supabase';
import PageHeader from '../../PageHeader';
import { Card, CardContent } from '../../ui/Card';
import { Button } from '../../ui/Button';
import { Table, TableHeader, TableHead, TableBody, TableRow, TableCell } from '../../ui/Table';
import { Badge } from '../../ui/Badge';
import { format } from 'date-fns';
import { Printer } from 'lucide-react';
import jsPDF from 'jspdf';
import 'jspdf-autotable';

interface SalesReportProps {
  businessId: string;
}

type SaleWithDetails = Sale & {
  sale_items: {
    quantity: number;
    products: { name: string } | null;
  }[];
};

declare module 'jspdf' {
  interface jsPDF {
    autoTable: (options: any) => jsPDF;
  }
}

export default function SalesReport({ businessId }: SalesReportProps) {
  const [sales, setSales] = useState<SaleWithDetails[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchSales = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('sales')
        .select('*, sale_items(*, products(name))')
        .eq('business_id', businessId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setSales(data as SaleWithDetails[] || []);
    } catch (error) {
      console.error('Error fetching sales report data:', error);
    } finally {
      setLoading(false);
    }
  }, [businessId]);

  useEffect(() => {
    fetchSales();
  }, [fetchSales]);

  const printReport = () => {
    const doc = new jsPDF();
    doc.text("Sales Report", 14, 16);
    
    const tableColumn = ["Date", "Receipt No.", "Items", "Total (KSh)"];
    const tableRows: (string | number)[][] = [];

    sales.forEach(sale => {
      const saleData = [
        format(new Date(sale.created_at), 'yyyy-MM-dd'),
        sale.receipt_number,
        sale.sale_items.reduce((acc, item) => acc + item.quantity, 0),
        sale.total_amount.toLocaleString(),
      ];
      tableRows.push(saleData);
    });

    doc.autoTable({
      head: [tableColumn],
      body: tableRows,
      startY: 20,
    });
    
    doc.save(`sales_report_${new Date().toISOString().split('T')[0]}.pdf`);
  };

  if (loading) {
    return <div className="text-center py-12">Generating sales report...</div>;
  }

  return (
    <div>
      <PageHeader
        title="Sales Report"
        subtitle={`A detailed summary of all sales transactions for your business.`}
        actions={
          <Button icon={<Printer />} onClick={printReport} disabled={sales.length === 0}>
            Print Report
          </Button>
        }
      />
      <Card>
        <CardContent>
          {sales.length === 0 ? (
            <div className="text-center py-12">
              <h3 className="text-lg font-medium text-gray-900 dark:text-white">No Sales Data</h3>
              <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">There are no sales recorded for this business yet.</p>
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableHead>Receipt No.</TableHead>
                <TableHead>Date</TableHead>
                <TableHead>Items Sold</TableHead>
                <TableHead>Payment</TableHead>
                <TableHead>Total Amount</TableHead>
              </TableHeader>
              <TableBody>
                {sales.map((sale) => (
                  <TableRow key={sale.id}>
                    <TableCell>
                      <div className="font-medium text-primary-600 dark:text-primary-400">{sale.receipt_number}</div>
                    </TableCell>
                    <TableCell>{format(new Date(sale.created_at), 'MMM dd, yyyy, h:mm a')}</TableCell>
                    <TableCell>{sale.sale_items.reduce((acc, item) => acc + item.quantity, 0)}</TableCell>
                    <TableCell><Badge>{sale.payment_method}</Badge></TableCell>
                    <TableCell>KSh {sale.total_amount.toLocaleString()}</TableCell>
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

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, type Product } from '../../../lib/supabase';
import PageHeader from '../../PageHeader';
import { Card, CardContent } from '../../ui/Card';
import { Button } from '../../ui/Button';
import { Table, TableHeader, TableHead, TableBody, TableRow, TableCell } from '../../ui/Table';
import { Badge } from '../../ui/Badge';
import { Printer } from 'lucide-react';
import jsPDF from 'jspdf';
import 'jspdf-autotable';

interface InventoryReportProps {
  businessId: string;
}

declare module 'jspdf' {
  interface jsPDF {
    autoTable: (options: any) => jsPDF;
  }
}

export default function InventoryReport({ businessId }: InventoryReportProps) {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchProducts = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('products')
        .select('*')
        .eq('business_id', businessId)
        .order('name', { ascending: true });

      if (error) throw error;
      setProducts(data || []);
    } catch (error) {
      console.error('Error fetching inventory report data:', error);
    } finally {
      setLoading(false);
    }
  }, [businessId]);

  useEffect(() => {
    fetchProducts();
  }, [fetchProducts]);

  const getStockStatus = (stock: number, minStock: number): { text: string; variant: 'success' | 'warning' | 'danger' } => {
    if (stock <= 0) return { text: 'Out of Stock', variant: 'danger' };
    if (stock <= minStock) return { text: 'Low Stock', variant: 'warning' };
    return { text: 'In Stock', variant: 'success' };
  };

  const printReport = () => {
    const doc = new jsPDF();
    doc.text("Inventory Summary Report", 14, 16);
    
    const tableColumn = ["Product Name", "Category", "Stock Quantity", "Unit", "Status"];
    const tableRows: (string | number)[][] = [];

    products.forEach(product => {
      const status = getStockStatus(product.stock_quantity, product.min_stock_level);
      const productData = [
        product.name,
        product.category || 'N/A',
        product.stock_quantity,
        product.unit,
        status.text,
      ];
      tableRows.push(productData);
    });

    doc.autoTable({
      head: [tableColumn],
      body: tableRows,
      startY: 20,
    });
    
    doc.save(`inventory_report_${new Date().toISOString().split('T')[0]}.pdf`);
  };

  if (loading) {
    return <div className="text-center py-12">Generating inventory report...</div>;
  }

  return (
    <div>
      <PageHeader
        title="Inventory Summary Report"
        subtitle={`A summary of all products and their stock levels.`}
        actions={
          <Button icon={<Printer />} onClick={printReport} disabled={products.length === 0}>
            Print Report
          </Button>
        }
      />
      <Card>
        <CardContent>
          {products.length === 0 ? (
            <div className="text-center py-12">
              <h3 className="text-lg font-medium text-gray-900 dark:text-white">No Product Data</h3>
              <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">There are no products in your inventory yet.</p>
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableHead>Product Name</TableHead>
                <TableHead>Category</TableHead>
                <TableHead>Stock Quantity</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Selling Price</TableHead>
              </TableHeader>
              <TableBody>
                {products.map((product) => {
                  const status = getStockStatus(product.stock_quantity, product.min_stock_level);
                  return (
                    <TableRow key={product.id}>
                      <TableCell>
                        <div className="font-medium">{product.name}</div>
                      </TableCell>
                      <TableCell>{product.category || 'N/A'}</TableCell>
                      <TableCell>{product.stock_quantity} {product.unit}(s)</TableCell>
                      <TableCell><Badge variant={status.variant}>{status.text}</Badge></TableCell>
                      <TableCell>KSh {product.selling_price.toLocaleString()}</TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

import React, { useState, useEffect, useCallback } from 'react';
import { supabase, type Sale, type Product } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import PageHeader from '../components/PageHeader';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Table, TableHeader, TableHead, TableBody, TableRow, TableCell } from '../components/ui/Table';
import { Badge } from '../components/ui/Badge';
import { PlusIcon, MoreVertical, XIcon, Trash2 } from 'lucide-react';
import { format } from 'date-fns';
import { Modal } from '../components/ui/Modal';
import { Input } from '../components/ui/Input';

interface SalesPageProps {
  businessId: string;
}

interface SaleItemInput {
  product_id: string;
  name: string;
  quantity: number;
  unit_price: number;
}

export default function Sales({ businessId }: SalesPageProps) {
  const { user } = useAuth();
  const [sales, setSales] = useState<Sale[]>([]);
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);

  const [saleItems, setSaleItems] = useState<SaleItemInput[]>([]);
  const [selectedProduct, setSelectedProduct] = useState('');

  const fetchSales = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('sales')
        .select('*')
        .eq('business_id', businessId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setSales(data || []);
    } catch (error) {
      console.error('Error fetching sales:', error);
    } finally {
      setLoading(false);
    }
  }, [businessId]);

  const fetchProducts = useCallback(async () => {
    try {
      const { data, error } = await supabase
        .from('products')
        .select('id, name, selling_price')
        .eq('business_id', businessId)
        .gt('stock_quantity', 0);
      if (error) throw error;
      setProducts(data || []);
    } catch (error) {
      console.error('Error fetching products:', error);
    }
  }, [businessId]);

  useEffect(() => {
    if (businessId) {
      fetchSales();
      fetchProducts();
    }
  }, [businessId, fetchSales, fetchProducts]);

  const handleAddProductToSale = () => {
    if (!selectedProduct) return;
    const product = products.find(p => p.id === selectedProduct);
    if (!product) return;

    // Check if product is already in the list
    if (saleItems.find(item => item.product_id === product.id)) {
      // Maybe increment quantity instead? For now, just prevent duplicates.
      return;
    }

    setSaleItems(prev => [...prev, {
      product_id: product.id,
      name: product.name,
      quantity: 1,
      unit_price: product.selling_price
    }]);
    setSelectedProduct('');
  };

  const handleItemQuantityChange = (productId: string, quantity: number) => {
    if (quantity < 1) return;
    setSaleItems(prev => prev.map(item =>
      item.product_id === productId ? { ...item, quantity } : item
    ));
  };
  
  const handleRemoveItem = (productId: string) => {
    setSaleItems(prev => prev.filter(item => item.product_id !== productId));
  };

  const totalSaleAmount = saleItems.reduce((acc, item) => acc + (item.unit_price * item.quantity), 0);

  const handleCreateSale = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user || !businessId || saleItems.length === 0) return;

    const itemsForRpc = saleItems.map(item => ({
      product_id: item.product_id,
      quantity: item.quantity,
      unit_price: item.unit_price,
    }));

    try {
      const { error } = await supabase.rpc('create_sale_and_items', {
        p_business_id: businessId,
        p_cashier_id: user.id,
        p_items: itemsForRpc,
      });

      if (error) throw error;

      await fetchSales(); // Refetch sales list
      await fetchProducts(); // Refetch products to update stock
      setIsModalOpen(false);
      setSaleItems([]);
    } catch (error) {
      console.error('Error creating sale:', error);
      alert(`Failed to create sale: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  };

  return (
    <div>
      <PageHeader
        title="Sales"
        subtitle="View and manage all sales transactions."
        actions={
          <Button icon={<PlusIcon />} onClick={() => setIsModalOpen(true)}>
            New Sale
          </Button>
        }
      />
      <Card>
        <CardContent>
          {loading ? <p className="py-12 text-center">Loading sales...</p> : sales.length === 0 ? (
             <div className="text-center py-12">
                <h3 className="text-lg font-medium text-gray-900 dark:text-white">No Sales Recorded</h3>
                <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">Record your first sale to get started.</p>
                <div className="mt-6">
                    <Button icon={<PlusIcon />} onClick={() => setIsModalOpen(true)}>Record First Sale</Button>
                </div>
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableHead>Receipt No.</TableHead>
                <TableHead>Date</TableHead>
                <TableHead>Payment</TableHead>
                <TableHead>Total</TableHead>
                <TableHead><span className="sr-only">Actions</span></TableHead>
              </TableHeader>
              <TableBody>
                {sales.map((sale) => (
                  <TableRow key={sale.id}>
                    <TableCell>
                      <div className="font-medium text-primary-600 dark:text-primary-400">{sale.receipt_number}</div>
                    </TableCell>
                    <TableCell>{format(new Date(sale.created_at), 'MMM dd, yyyy')}</TableCell>
                    <TableCell><Badge>{sale.payment_method}</Badge></TableCell>
                    <TableCell>KSh {sale.total_amount.toLocaleString()}</TableCell>
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

      <Modal isOpen={isModalOpen} onClose={() => setIsModalOpen(false)} title="Record New Sale">
        <form onSubmit={handleCreateSale} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Add Product</label>
            <div className="flex space-x-2">
              <select value={selectedProduct} onChange={(e) => setSelectedProduct(e.target.value)} className="flex-grow px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent dark:bg-gray-800 dark:text-white">
                <option value="" disabled>Select a product</option>
                {products.map(p => <option key={p.id} value={p.id}>{p.name}</option>)}
              </select>
              <Button type="button" onClick={handleAddProductToSale}>Add</Button>
            </div>
          </div>
          
          {saleItems.length > 0 && (
            <div className="space-y-2 max-h-60 overflow-y-auto pr-2">
              {saleItems.map(item => (
                <div key={item.product_id} className="flex items-center justify-between bg-gray-50 dark:bg-gray-700/50 p-2 rounded-lg">
                  <span className="text-sm font-medium">{item.name}</span>
                  <div className="flex items-center space-x-2">
                    <Input type="number" value={item.quantity} onChange={(e) => handleItemQuantityChange(item.product_id, parseInt(e.target.value))} className="w-16 text-center" />
                    <span className="text-sm">x KSh {item.unit_price.toLocaleString()}</span>
                    <Button type="button" variant="ghost" size="sm" icon={<Trash2 className="h-4 w-4 text-red-500" />} onClick={() => handleRemoveItem(item.product_id)} />
                  </div>
                </div>
              ))}
            </div>
          )}

          <div className="pt-4 border-t border-gray-200 dark:border-gray-700 flex justify-between items-center">
            <span className="text-lg font-bold">Total:</span>
            <span className="text-lg font-bold">KSh {totalSaleAmount.toLocaleString()}</span>
          </div>

          <div className="flex justify-end space-x-2 pt-4">
            <Button type="button" variant="secondary" onClick={() => setIsModalOpen(false)}>Cancel</Button>
            <Button type="submit" disabled={saleItems.length === 0}>Complete Sale</Button>
          </div>
        </form>
      </Modal>
    </div>
  );
}

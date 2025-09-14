import React, { useState, useEffect, useCallback } from 'react';
import { supabase, type Product } from '../lib/supabase';
import PageHeader from '../components/PageHeader';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { Table, TableHeader, TableHead, TableBody, TableRow, TableCell } from '../components/ui/Table';
import { Badge } from '../components/ui/Badge';
import { Modal } from '../components/ui/Modal';
import { ConfirmDeleteModal } from '../components/ui/ConfirmDeleteModal';
import { PlusIcon, SearchIcon, MoreVertical, Pencil, Trash2 } from 'lucide-react';
import { Menu, Transition } from '@headlessui/react';

interface ProductsPageProps {
  businessId: string;
}

export default function Products({ businessId }: ProductsPageProps) {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  
  const [editingProduct, setEditingProduct] = useState<Product | null>(null);
  const [productForm, setProductForm] = useState({
    name: '',
    sku: '',
    selling_price: '',
    stock_quantity: '',
    category: '',
    unit: 'piece',
  });

  const [deletingProduct, setDeletingProduct] = useState<Product | null>(null);
  const [deleteLoading, setDeleteLoading] = useState(false);

  const fetchProducts = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('products')
        .select('*')
        .eq('business_id', businessId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setProducts(data || []);
    } catch (error) {
      console.error('Error fetching products:', error);
    } finally {
      setLoading(false);
    }
  }, [businessId]);

  useEffect(() => {
    if (businessId) {
      fetchProducts();
    }
  }, [businessId, fetchProducts]);

  useEffect(() => {
    if (editingProduct) {
      setProductForm({
        name: editingProduct.name,
        sku: editingProduct.sku || '',
        selling_price: String(editingProduct.selling_price),
        stock_quantity: String(editingProduct.stock_quantity),
        category: editingProduct.category || '',
        unit: editingProduct.unit,
      });
    } else {
      setProductForm({ name: '', sku: '', selling_price: '', stock_quantity: '', category: '', unit: 'piece' });
    }
  }, [editingProduct, isModalOpen]);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setProductForm(prev => ({ ...prev, [name]: value }));
  };

  const openAddModal = () => {
    setEditingProduct(null);
    setIsModalOpen(true);
  };

  const openEditModal = (product: Product) => {
    setEditingProduct(product);
    setIsModalOpen(true);
  };
  
  const closeModal = () => {
    setIsModalOpen(false);
    setEditingProduct(null);
  };

  const handleSaveProduct = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!businessId) return;

    const productData = {
      ...productForm,
      business_id: businessId,
      selling_price: parseFloat(productForm.selling_price),
      stock_quantity: parseInt(productForm.stock_quantity, 10),
      min_stock_level: 10,
      is_active: true,
    };

    try {
      let savedProduct: Product | null = null;
      if (editingProduct) {
        const { data, error } = await supabase
          .from('products')
          .update(productData)
          .eq('id', editingProduct.id)
          .select()
          .single();
        if (error) throw error;
        savedProduct = data;
        setProducts(prev => prev.map(p => p.id === savedProduct!.id ? savedProduct! : p));
      } else {
        const { data, error } = await supabase
          .from('products')
          .insert(productData)
          .select()
          .single();
        if (error) throw error;
        savedProduct = data;
        setProducts(prev => [savedProduct!, ...prev]);
      }
      closeModal();
    } catch (error) {
      console.error('Error saving product:', error);
      alert(`Failed to save product: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  };

  const handleDeleteProduct = async () => {
    if (!deletingProduct) return;
    setDeleteLoading(true);
    try {
      const { error } = await supabase
        .from('products')
        .delete()
        .eq('id', deletingProduct.id);
      if (error) throw error;
      setProducts(prev => prev.filter(p => p.id !== deletingProduct.id));
      setDeletingProduct(null);
    } catch (error) {
      console.error('Error deleting product:', error);
      alert(`Failed to delete product: ${error instanceof Error ? error.message : 'Unknown error'}`);
    } finally {
      setDeleteLoading(false);
    }
  };

  const getStockStatus = (stock: number, minStock: number): { text: string; variant: 'success' | 'warning' | 'danger' } => {
    if (stock <= 0) return { text: 'Out of Stock', variant: 'danger' };
    if (stock <= minStock) return { text: 'Low Stock', variant: 'warning' };
    return { text: 'In Stock', variant: 'success' };
  };

  return (
    <div>
      <PageHeader
        title="Products"
        subtitle="Manage all products in your inventory."
        actions={
          <Button icon={<PlusIcon />} onClick={openAddModal}>
            Add Product
          </Button>
        }
      />
      <Card>
        <CardContent>
          <div className="flex justify-between items-center mb-4">
            <div className="w-full max-w-sm">
              <Input placeholder="Search products..." icon={<SearchIcon />} />
            </div>
          </div>
          {loading ? (
            <div className="text-center py-12">Loading products...</div>
          ) : products.length === 0 ? (
            <div className="text-center py-12">
              <h3 className="text-lg font-medium text-gray-900 dark:text-white">No products found</h3>
              <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">Get started by adding your first product.</p>
              <div className="mt-6">
                  <Button icon={<PlusIcon />} onClick={openAddModal}>
                      Add First Product
                  </Button>
              </div>
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableHead>Product Name</TableHead>
                <TableHead>SKU</TableHead>
                <TableHead>Price</TableHead>
                <TableHead>Stock</TableHead>
                <TableHead>Status</TableHead>
                <TableHead><span className="sr-only">Actions</span></TableHead>
              </TableHeader>
              <TableBody>
                {products.map((product) => {
                  const status = getStockStatus(product.stock_quantity, product.min_stock_level);
                  return (
                    <TableRow key={product.id}>
                      <TableCell><div className="font-medium">{product.name}</div></TableCell>
                      <TableCell>{product.sku || 'N/A'}</TableCell>
                      <TableCell>KSh {product.selling_price.toLocaleString()}</TableCell>
                      <TableCell>{product.stock_quantity} {product.unit}(s)</TableCell>
                      <TableCell>
                        <Badge variant={status.variant}>{status.text}</Badge>
                      </TableCell>
                      <TableCell className="text-right">
                        <Menu as="div" className="relative inline-block text-left">
                          <Menu.Button as={Button} variant="ghost" size="sm" icon={<MoreVertical className="h-4 w-4" />} />
                          <Transition
                            as={React.Fragment}
                            enter="transition ease-out duration-100"
                            enterFrom="transform opacity-0 scale-95"
                            enterTo="transform opacity-100 scale-100"
                            leave="transition ease-in duration-75"
                            leaveFrom="transform opacity-100 scale-100"
                            leaveTo="transform opacity-0 scale-95"
                          >
                            <Menu.Items className="absolute right-0 z-10 mt-2 w-32 origin-top-right divide-y divide-gray-100 dark:divide-gray-700 rounded-md bg-white dark:bg-gray-800 shadow-lg ring-1 ring-black/5 focus:outline-none">
                              <div className="px-1 py-1">
                                <Menu.Item>
                                  {({ active }) => (
                                    <button
                                      onClick={() => openEditModal(product)}
                                      className={`${active ? 'bg-primary-100 dark:bg-gray-700' : ''} text-gray-900 dark:text-gray-100 group flex w-full items-center rounded-md px-2 py-2 text-sm`}
                                    >
                                      <Pencil className="mr-2 h-4 w-4" />
                                      Edit
                                    </button>
                                  )}
                                </Menu.Item>
                                <Menu.Item>
                                  {({ active }) => (
                                    <button
                                      onClick={() => setDeletingProduct(product)}
                                      className={`${active ? 'bg-red-100 dark:bg-red-700' : ''} text-red-700 dark:text-red-400 group flex w-full items-center rounded-md px-2 py-2 text-sm`}
                                    >
                                      <Trash2 className="mr-2 h-4 w-4" />
                                      Delete
                                    </button>
                                  )}
                                </Menu.Item>
                              </div>
                            </Menu.Items>
                          </Transition>
                        </Menu>
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      <Modal isOpen={isModalOpen} onClose={closeModal} title={editingProduct ? "Edit Product" : "Add New Product"}>
        <form onSubmit={handleSaveProduct} className="space-y-4">
          <Input name="name" placeholder="Product Name" value={productForm.name} onChange={handleInputChange} required />
          <Input name="sku" placeholder="SKU / Barcode" value={productForm.sku} onChange={handleInputChange} />
          <Input name="category" placeholder="Category (e.g., Cement)" value={productForm.category} onChange={handleInputChange} />
          <Input name="selling_price" type="number" placeholder="Selling Price (KSh)" value={productForm.selling_price} onChange={handleInputChange} required />
          <Input name="stock_quantity" type="number" placeholder="Stock Quantity" value={productForm.stock_quantity} onChange={handleInputChange} required />
          <Input name="unit" placeholder="Unit (e.g., bag, piece)" value={productForm.unit} onChange={handleInputChange} required />
          <div className="flex justify-end space-x-2 pt-4">
            <Button type="button" variant="secondary" onClick={closeModal}>Cancel</Button>
            <Button type="submit">{editingProduct ? 'Save Changes' : 'Add Product'}</Button>
          </div>
        </form>
      </Modal>

      {deletingProduct && (
        <ConfirmDeleteModal
          isOpen={!!deletingProduct}
          onClose={() => setDeletingProduct(null)}
          onConfirm={handleDeleteProduct}
          itemName={deletingProduct.name}
          loading={deleteLoading}
          title="Confirm Deletion"
          message={`Are you sure you want to delete ${deletingProduct.name}?`}
          confirmText="Delete"
        />
      )}
    </div>
  );
}

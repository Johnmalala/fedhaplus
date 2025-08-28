import React from 'react';
import { faker } from '@faker-js/faker';
import PageHeader from '../components/PageHeader';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { Table, TableHeader, TableHead, TableBody, TableRow, TableCell } from '../components/ui/Table';
import { Badge } from '../components/ui/Badge';
import { PlusIcon, SearchIcon, MoreVertical } from 'lucide-react';

const mockProducts = Array.from({ length: 15 }, () => ({
  id: faker.string.uuid(),
  name: faker.commerce.productName(),
  category: faker.commerce.department(),
  price: parseFloat(faker.commerce.price()),
  stock: faker.number.int({ min: 0, max: 200 }),
  status: faker.helpers.arrayElement(['In Stock', 'Low Stock', 'Out of Stock']),
}));

export default function Products() {
  return (
    <div>
      <PageHeader
        title="Products"
        subtitle="Manage all products in your inventory."
        actions={
          <Button icon={<PlusIcon />}>
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
          <Table>
            <TableHeader>
              <TableHead>Product Name</TableHead>
              <TableHead>Category</TableHead>
              <TableHead>Price</TableHead>
              <TableHead>Stock</TableHead>
              <TableHead>Status</TableHead>
              <TableHead><span className="sr-only">Actions</span></TableHead>
            </TableHeader>
            <TableBody>
              {mockProducts.map((product) => (
                <TableRow key={product.id}>
                  <TableCell>
                    <div className="font-medium">{product.name}</div>
                  </TableCell>
                  <TableCell>{product.category}</TableCell>
                  <TableCell>KSh {product.price.toLocaleString()}</TableCell>
                  <TableCell>{product.stock}</TableCell>
                  <TableCell>
                    <Badge variant={product.status === 'In Stock' ? 'success' : product.status === 'Low Stock' ? 'warning' : 'danger'}>
                      {product.status}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-right">
                    <Button variant="ghost" size="sm" icon={<MoreVertical />} />
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}

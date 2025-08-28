import React from 'react';
import { faker } from '@faker-js/faker';
import PageHeader from '../components/PageHeader';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Table, TableHeader, TableHead, TableBody, TableRow, TableCell } from '../components/ui/Table';
import { Badge } from '../components/ui/Badge';
import { PlusIcon, MoreVertical } from 'lucide-react';
import { format } from 'date-fns';

const mockSales = Array.from({ length: 20 }, () => ({
  id: faker.string.uuid(),
  receiptNumber: `REC-${faker.string.alphanumeric(8).toUpperCase()}`,
  date: faker.date.recent({ days: 30 }),
  customer: faker.person.fullName(),
  total: parseFloat(faker.commerce.price({ min: 500, max: 15000 })),
  paymentMethod: faker.helpers.arrayElement(['M-Pesa', 'Cash', 'Card']),
}));

export default function Sales() {
  return (
    <div>
      <PageHeader
        title="Sales"
        subtitle="View and manage all sales transactions."
        actions={
          <Button icon={<PlusIcon />}>
            New Sale
          </Button>
        }
      />
      <Card>
        <CardContent>
          <Table>
            <TableHeader>
              <TableHead>Receipt No.</TableHead>
              <TableHead>Date</TableHead>
              <TableHead>Customer</TableHead>
              <TableHead>Payment</TableHead>
              <TableHead>Total</TableHead>
              <TableHead><span className="sr-only">Actions</span></TableHead>
            </TableHeader>
            <TableBody>
              {mockSales.map((sale) => (
                <TableRow key={sale.id}>
                  <TableCell>
                    <div className="font-medium text-primary-600 dark:text-primary-400">{sale.receiptNumber}</div>
                  </TableCell>
                  <TableCell>{format(sale.date, 'MMM dd, yyyy')}</TableCell>
                  <TableCell>{sale.customer}</TableCell>
                  <TableCell><Badge>{sale.paymentMethod}</Badge></TableCell>
                  <TableCell>KSh {sale.total.toLocaleString()}</TableCell>
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

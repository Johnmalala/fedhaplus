import React from 'react';
import { faker } from '@faker-js/faker';
import PageHeader from '../components/PageHeader';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Table, TableHeader, TableHead, TableBody, TableRow, TableCell } from '../components/ui/Table';
import { Badge } from '../components/ui/Badge';
import { PlusIcon, MoreVertical } from 'lucide-react';
import { format } from 'date-fns';

const mockPayments = Array.from({ length: 15 }, () => ({
  id: faker.string.uuid(),
  tenantName: faker.person.fullName(),
  unitNumber: `A-${faker.number.int({ min: 1, max: 5 })}${faker.number.int({ min: 1, max: 9 })}`,
  date: faker.date.recent({ days: 30 }),
  amount: parseFloat(faker.commerce.price({ min: 15000, max: 45000 })),
  status: faker.helpers.arrayElement(['Paid', 'Pending']),
}));

export default function RentPayments() {
  return (
    <div>
      <PageHeader
        title="Rent Payments"
        subtitle="Track and manage tenant rent payments."
        actions={
          <Button icon={<PlusIcon />}>
            Record Payment
          </Button>
        }
      />
      <Card>
        <CardContent>
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
              {mockPayments.map((payment) => (
                <TableRow key={payment.id}>
                  <TableCell><div className="font-medium">{payment.tenantName}</div></TableCell>
                  <TableCell>{payment.unitNumber}</TableCell>
                  <TableCell>{format(payment.date, 'MMM dd, yyyy')}</TableCell>
                  <TableCell>KSh {payment.amount.toLocaleString()}</TableCell>
                  <TableCell>
                    <Badge variant={payment.status === 'Paid' ? 'success' : 'warning'}>
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
        </CardContent>
      </Card>
    </div>
  );
}

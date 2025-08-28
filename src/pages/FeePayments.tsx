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
  studentName: faker.person.fullName(),
  admissionNumber: `ADM-${faker.number.int({ min: 1000, max: 9999 })}`,
  date: faker.date.recent({ days: 30 }),
  amount: parseFloat(faker.commerce.price({ min: 10000, max: 50000 })),
  status: faker.helpers.arrayElement(['Paid', 'Pending']),
}));

export default function FeePayments() {
  return (
    <div>
      <PageHeader
        title="Fee Payments"
        subtitle="Track and manage student fee payments."
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
              <TableHead>Student Name</TableHead>
              <TableHead>Admission No.</TableHead>
              <TableHead>Date</TableHead>
              <TableHead>Amount</TableHead>
              <TableHead>Status</TableHead>
              <TableHead><span className="sr-only">Actions</span></TableHead>
            </TableHeader>
            <TableBody>
              {mockPayments.map((payment) => (
                <TableRow key={payment.id}>
                  <TableCell><div className="font-medium">{payment.studentName}</div></TableCell>
                  <TableCell>{payment.admissionNumber}</TableCell>
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

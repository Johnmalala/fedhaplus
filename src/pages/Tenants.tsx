import React from 'react';
import { faker } from '@faker-js/faker';
import PageHeader from '../components/PageHeader';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Table, TableHeader, TableHead, TableBody, TableRow, TableCell } from '../components/ui/Table';
import { Badge } from '../components/ui/Badge';
import { PlusIcon, MoreVertical } from 'lucide-react';

const mockTenants = Array.from({ length: 10 }, () => ({
  id: faker.string.uuid(),
  name: faker.person.fullName(),
  unitNumber: `A-${faker.number.int({ min: 1, max: 5 })}${faker.number.int({ min: 1, max: 9 })}`,
  rent: parseFloat(faker.commerce.price({ min: 15000, max: 45000 })),
  rentStatus: faker.helpers.arrayElement(['Paid', 'Due', 'Overdue']),
  phone: faker.phone.number(),
}));

export default function Tenants() {
  return (
    <div>
      <PageHeader
        title="Tenants"
        subtitle="Manage all your tenants and properties."
        actions={
          <Button icon={<PlusIcon />}>
            Add Tenant
          </Button>
        }
      />
      <Card>
        <CardContent>
          <Table>
            <TableHeader>
              <TableHead>Tenant Name</TableHead>
              <TableHead>Unit No.</TableHead>
              <TableHead>Phone</TableHead>
              <TableHead>Rent Amount</TableHead>
              <TableHead>Rent Status</TableHead>
              <TableHead><span className="sr-only">Actions</span></TableHead>
            </TableHeader>
            <TableBody>
              {mockTenants.map((tenant) => (
                <TableRow key={tenant.id}>
                  <TableCell><div className="font-medium">{tenant.name}</div></TableCell>
                  <TableCell>{tenant.unitNumber}</TableCell>
                  <TableCell>{tenant.phone}</TableCell>
                  <TableCell>KSh {tenant.rent.toLocaleString()}</TableCell>
                  <TableCell>
                    <Badge variant={tenant.rentStatus === 'Paid' ? 'success' : tenant.rentStatus === 'Due' ? 'warning' : 'danger'}>
                      {tenant.rentStatus}
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

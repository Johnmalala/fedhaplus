import React from 'react';
import { faker } from '@faker-js/faker';
import PageHeader from '../components/PageHeader';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Badge } from '../components/ui/Badge';
import { PlusIcon, UserCircle, MoreVertical } from 'lucide-react';

const mockStaff = Array.from({ length: 8 }, () => ({
  id: faker.string.uuid(),
  name: faker.person.fullName(),
  role: faker.helpers.arrayElement(['Manager', 'Cashier', 'Accountant', 'Teacher']),
  email: faker.internet.email(),
  status: faker.helpers.arrayElement(['Active', 'Invited']),
}));

export default function Staff() {
  return (
    <div>
      <PageHeader
        title="Staff Management"
        subtitle="Invite and manage staff members for your business."
        actions={
          <Button icon={<PlusIcon />}>
            Invite Staff
          </Button>
        }
      />
      <Card>
        <CardContent>
          <ul className="divide-y divide-gray-200 dark:divide-gray-700">
            {mockStaff.map((staff) => (
              <li key={staff.id} className="py-4 flex items-center justify-between">
                <div className="flex items-center">
                  <UserCircle className="h-10 w-10 text-gray-400" />
                  <div className="ml-3">
                    <p className="text-sm font-medium text-gray-900 dark:text-white">{staff.name}</p>
                    <p className="text-sm text-gray-500 dark:text-gray-400">{staff.email}</p>
                  </div>
                </div>
                <div className="flex items-center space-x-4">
                  <Badge>{staff.role}</Badge>
                  <Badge variant={staff.status === 'Active' ? 'success' : 'warning'}>{staff.status}</Badge>
                  <Button variant="ghost" size="sm" icon={<MoreVertical />} />
                </div>
              </li>
            ))}
          </ul>
        </CardContent>
      </Card>
    </div>
  );
}

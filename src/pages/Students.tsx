import React from 'react';
import { faker } from '@faker-js/faker';
import PageHeader from '../components/PageHeader';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Table, TableHeader, TableHead, TableBody, TableRow, TableCell } from '../components/ui/Table';
import { Badge } from '../components/ui/Badge';
import { PlusIcon, MoreVertical } from 'lucide-react';

const mockStudents = Array.from({ length: 15 }, () => ({
  id: faker.string.uuid(),
  name: faker.person.fullName(),
  admissionNumber: `ADM-${faker.number.int({ min: 1000, max: 9999 })}`,
  class: `Form ${faker.number.int({ min: 1, max: 4 })}`,
  feeStatus: faker.helpers.arrayElement(['Paid', 'Partial', 'Unpaid']),
  parentPhone: faker.phone.number(),
}));

export default function Students() {
  return (
    <div>
      <PageHeader
        title="Students"
        subtitle="Manage all student records and information."
        actions={
          <Button icon={<PlusIcon />}>
            Add Student
          </Button>
        }
      />
      <Card>
        <CardContent>
          <Table>
            <TableHeader>
              <TableHead>Student Name</TableHead>
              <TableHead>Admission No.</TableHead>
              <TableHead>Class</TableHead>
              <TableHead>Parent Phone</TableHead>
              <TableHead>Fee Status</TableHead>
              <TableHead><span className="sr-only">Actions</span></TableHead>
            </TableHeader>
            <TableBody>
              {mockStudents.map((student) => (
                <TableRow key={student.id}>
                  <TableCell><div className="font-medium">{student.name}</div></TableCell>
                  <TableCell>{student.admissionNumber}</TableCell>
                  <TableCell>{student.class}</TableCell>
                  <TableCell>{student.parentPhone}</TableCell>
                  <TableCell>
                    <Badge variant={student.feeStatus === 'Paid' ? 'success' : student.feeStatus === 'Partial' ? 'warning' : 'danger'}>
                      {student.feeStatus}
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

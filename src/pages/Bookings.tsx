import React from 'react';
import { faker } from '@faker-js/faker';
import PageHeader from '../components/PageHeader';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Table, TableHeader, TableHead, TableBody, TableRow, TableCell } from '../components/ui/Table';
import { Badge } from '../components/ui/Badge';
import { PlusIcon, MoreVertical } from 'lucide-react';
import { format } from 'date-fns';

const mockBookings = Array.from({ length: 15 }, () => ({
  id: faker.string.uuid(),
  guestName: faker.person.fullName(),
  checkIn: faker.date.soon({ days: 10 }),
  checkOut: faker.date.soon({ days: 15, refDate: new Date() }),
  roomNumber: `${faker.number.int({ min: 1, max: 5 })}${faker.number.int({ min: 0, max: 9 })}${faker.number.int({ min: 1, max: 9 })}`,
  status: faker.helpers.arrayElement(['Confirmed', 'Checked-in', 'Checked-out', 'Cancelled']),
}));

export default function Bookings() {
  return (
    <div>
      <PageHeader
        title="Bookings"
        subtitle="Manage all guest bookings and reservations."
        actions={
          <Button icon={<PlusIcon />}>
            New Booking
          </Button>
        }
      />
      <Card>
        <CardContent>
          <Table>
            <TableHeader>
              <TableHead>Guest Name</TableHead>
              <TableHead>Check-in</TableHead>
              <TableHead>Check-out</TableHead>
              <TableHead>Room</TableHead>
              <TableHead>Status</TableHead>
              <TableHead><span className="sr-only">Actions</span></TableHead>
            </TableHeader>
            <TableBody>
              {mockBookings.map((booking) => (
                <TableRow key={booking.id}>
                  <TableCell><div className="font-medium">{booking.guestName}</div></TableCell>
                  <TableCell>{format(booking.checkIn, 'MMM dd, yyyy')}</TableCell>
                  <TableCell>{format(booking.checkOut, 'MMM dd, yyyy')}</TableCell>
                  <TableCell>{booking.roomNumber}</TableCell>
                  <TableCell>
                    <Badge variant={booking.status === 'Confirmed' ? 'default' : booking.status === 'Checked-in' ? 'success' : booking.status === 'Cancelled' ? 'danger' : 'default'}>
                      {booking.status}
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

import React from 'react';
import { faker } from '@faker-js/faker';
import PageHeader from '../components/PageHeader';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Badge } from '../components/ui/Badge';
import { PlusIcon } from 'lucide-react';

const mockRooms = Array.from({ length: 12 }, () => ({
  id: faker.string.uuid(),
  number: `${faker.number.int({ min: 1, max: 5 })}${faker.number.int({ min: 0, max: 9 })}${faker.number.int({ min: 1, max: 9 })}`,
  type: faker.helpers.arrayElement(['Single', 'Double', 'Suite']),
  status: faker.helpers.arrayElement(['Available', 'Occupied', 'Cleaning']),
  rate: parseFloat(faker.commerce.price({ min: 3000, max: 12000 })),
}));

export default function Rooms() {
  return (
    <div>
      <PageHeader
        title="Rooms"
        subtitle="Manage all hotel rooms and their status."
        actions={
          <Button icon={<PlusIcon />}>
            Add Room
          </Button>
        }
      />
      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
        {mockRooms.map((room) => (
          <Card key={room.id} className="flex flex-col">
            <CardContent className="flex-grow">
              <div className="flex justify-between items-start">
                <div>
                  <p className="text-sm text-gray-500 dark:text-gray-400">{room.type}</p>
                  <h3 className="text-xl font-bold text-gray-900 dark:text-white">Room {room.number}</h3>
                </div>
                <Badge variant={room.status === 'Available' ? 'success' : room.status === 'Occupied' ? 'danger' : 'warning'}>
                  {room.status}
                </Badge>
              </div>
            </CardContent>
            <div className="p-4 border-t border-gray-200 dark:border-gray-700 flex justify-between items-center">
              <p className="font-semibold text-gray-800 dark:text-gray-200">KSh {room.rate.toLocaleString()}</p>
              <Button size="sm" variant="secondary">Manage</Button>
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}

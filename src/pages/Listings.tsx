import React from 'react';
import { faker } from '@faker-js/faker';
import PageHeader from '../components/PageHeader';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Badge } from '../components/ui/Badge';
import { PlusIcon, Star, MapPin } from 'lucide-react';

const mockListings = Array.from({ length: 8 }, () => ({
  id: faker.string.uuid(),
  name: `Cozy ${faker.helpers.arrayElement(['Apartment', 'Studio', 'Villa'])} in ${faker.location.city()}`,
  location: faker.location.streetAddress(),
  status: faker.helpers.arrayElement(['Listed', 'Booked', 'Maintenance']),
  rate: parseFloat(faker.commerce.price({ min: 4000, max: 15000 })),
  rating: faker.number.float({ min: 3.5, max: 5, precision: 0.1 }),
  imageUrl: faker.image.urlLoremFlickr({ category: 'apartment' }),
}));

export default function Listings() {
  return (
    <div>
      <PageHeader
        title="Airbnb Listings"
        subtitle="Manage all your short-term rental listings."
        actions={
          <Button icon={<PlusIcon />}>
            New Listing
          </Button>
        }
      />
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        {mockListings.map((listing) => (
          <Card key={listing.id}>
            <img src={listing.imageUrl} alt={listing.name} className="h-48 w-full object-cover rounded-t-xl" />
            <CardContent>
              <div className="flex justify-between items-start mb-2">
                <h3 className="font-bold text-lg text-gray-900 dark:text-white leading-tight">{listing.name}</h3>
                <Badge variant={listing.status === 'Listed' ? 'success' : listing.status === 'Booked' ? 'warning' : 'danger'}>
                  {listing.status}
                </Badge>
              </div>
              <div className="flex items-center text-sm text-gray-500 dark:text-gray-400 mb-2">
                <MapPin className="h-4 w-4 mr-1" />
                {listing.location}
              </div>
              <div className="flex justify-between items-center">
                <p className="font-semibold text-gray-800 dark:text-gray-200">KSh {listing.rate.toLocaleString()} / night</p>
                <div className="flex items-center">
                  <Star className="h-4 w-4 text-yellow-400 mr-1" />
                  <span className="font-medium text-gray-700 dark:text-gray-300">{listing.rating}</span>
                </div>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}

import React from 'react';
import PageHeader from '../components/PageHeader';
import { Card, CardHeader, CardContent, CardFooter } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';

export default function Settings() {
  return (
    <div>
      <PageHeader
        title="Settings"
        subtitle="Manage your business and account settings."
      />
      <div className="space-y-8">
        <Card>
          <CardHeader>
            <h3 className="text-lg font-semibold text-gray-900 dark:text-white">Business Profile</h3>
            <p className="text-sm text-gray-500 dark:text-gray-400">Update your business'"'"'s public information.</p>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Business Name</label>
              <Input defaultValue="My Hardware Shop" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Contact Phone</label>
              <Input defaultValue="+254 712 345 678" />
            </div>
          </CardContent>
          <CardFooter>
            <Button>Save Changes</Button>
          </CardFooter>
        </Card>

        <Card>
          <CardHeader>
            <h3 className="text-lg font-semibold text-gray-900 dark:text-white">Account Settings</h3>
            <p className="text-sm text-gray-500 dark:text-gray-400">Manage your login and personal details.</p>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Full Name</label>
              <Input defaultValue="John Doe" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Email Address</label>
              <Input type="email" defaultValue="john.doe@example.com" />
            </div>
          </CardContent>
          <CardFooter>
            <Button>Save Changes</Button>
          </CardFooter>
        </Card>
      </div>
    </div>
  );
}

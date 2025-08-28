import React from 'react';
import { UserGroupIcon, ShieldCheckIcon, KeyIcon } from '@heroicons/react/24/outline';

export default function AccessControl() {
  const roles = [
    {
      title: 'Owner',
      description: 'Full access to all features, billing, and team management',
      permissions: ['All Features', 'Billing', 'Team Management', 'Settings'],
      color: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200',
    },
    {
      title: 'Manager',
      description: 'Full access except billing and critical settings',
      permissions: ['Sales & Reports', 'Staff Management', 'Inventory', 'Customer Management'],
      color: 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200',
    },
    {
      title: 'Cashier',
      description: 'Record sales and basic customer interactions only',
      permissions: ['Record Sales', 'View Products', 'Basic Customer Info'],
      color: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200',
    },
    {
      title: 'Teacher',
      description: 'View students in their class and mark fee payments',
      permissions: ['View Students', 'Mark Attendance', 'Fee Payments', 'Class Reports'],
      color: 'bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200',
    },
    {
      title: 'Accountant',
      description: 'View financial reports and record expenses',
      permissions: ['Financial Reports', 'Record Expenses', 'Tax Reports'],
      color: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200',
    },
    {
      title: 'Front Desk',
      description: 'Handle check-ins, bookings, and room assignments',
      permissions: ['Check-in/out', 'View Bookings', 'Room Assignment', 'Guest Services'],
      color: 'bg-indigo-100 text-indigo-800 dark:bg-indigo-900 dark:text-indigo-200',
    },
  ];

  return (
    <div className="py-24 bg-gray-50 dark:bg-gray-800">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-primary-100 dark:bg-primary-900 rounded-2xl mb-6">
            <ShieldCheckIcon className="h-8 w-8 text-primary-600 dark:text-primary-400" />
          </div>
          
          <h2 className="text-3xl sm:text-4xl font-bold text-gray-900 dark:text-white mb-4">
            Fine-Grained Access Control
          </h2>
          
          <p className="text-xl text-gray-600 dark:text-gray-300 max-w-3xl mx-auto">
            Securely delegate tasks with role-based permissions. Invite staff via SMS and control exactly what they can see and do.
          </p>
        </div>

        {/* Key Features */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mb-16">
          <div className="text-center p-6">
            <UserGroupIcon className="h-12 w-12 text-primary-500 mx-auto mb-4" />
            <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-2">
              SMS Invitations
            </h3>
            <p className="text-gray-600 dark:text-gray-300">
              Invite staff via SMS with automatic account setup
            </p>
          </div>
          
          <div className="text-center p-6">
            <KeyIcon className="h-12 w-12 text-primary-500 mx-auto mb-4" />
            <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-2">
              PIN Login
            </h3>
            <p className="text-gray-600 dark:text-gray-300">
              Simple 4-digit PIN login for quick access
            </p>
          </div>
          
          <div className="text-center p-6">
            <ShieldCheckIcon className="h-12 w-12 text-primary-500 mx-auto mb-4" />
            <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-2">
              Row-Level Security
            </h3>
            <p className="text-gray-600 dark:text-gray-300">
              Staff only see data for their assigned business
            </p>
          </div>
        </div>

        {/* Roles Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {roles.map((role, index) => (
            <div
              key={index}
              className="bg-white dark:bg-gray-900 rounded-xl p-6 shadow-sm hover:shadow-lg transition-all duration-300"
            >
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
                  {role.title}
                </h3>
                <span className={`px-2 py-1 rounded-full text-xs font-medium ${role.color}`}>
                  Role
                </span>
              </div>
              
              <p className="text-gray-600 dark:text-gray-300 text-sm mb-4">
                {role.description}
              </p>
              
              <div className="space-y-2">
                <p className="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide">
                  Permissions
                </p>
                <div className="flex flex-wrap gap-1">
                  {role.permissions.map((permission, permIndex) => (
                    <span
                      key={permIndex}
                      className="inline-block px-2 py-1 bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 rounded text-xs"
                    >
                      {permission}
                    </span>
                  ))}
                </div>
              </div>
            </div>
          ))}
        </div>

        <div className="text-center mt-12">
          <p className="text-gray-600 dark:text-gray-400">
            Owners can suspend, modify roles, or remove staff access anytime from the dashboard
          </p>
        </div>
      </div>
    </div>
  );
}

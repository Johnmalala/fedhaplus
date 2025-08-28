import React from 'react';
import { NavLink } from 'react-router-dom';
import {
  HomeIcon,
  ShoppingCartIcon,
  CubeIcon,
  UsersIcon,
  DocumentTextIcon,
  CogIcon,
  ChartBarIcon,
  BuildingStorefrontIcon,
  AcademicCapIcon,
  BuildingOfficeIcon,
  CreditCardIcon,
} from '@heroicons/react/24/outline';
import { type Business, type BusinessType } from '../../lib/supabase';
import BusinessSelector from './BusinessSelector';

interface SidebarProps {
  selectedBusiness: Business | null;
  onBusinessSelect: (business: Business) => void;
}

const navigationMap: Record<BusinessType, Array<{ name: string; href: string; icon: any }>> = {
  hardware: [
    { name: 'Dashboard', href: '/dashboard', icon: HomeIcon },
    { name: 'Products', href: '/dashboard/products', icon: CubeIcon },
    { name: 'Sales', href: '/dashboard/sales', icon: ShoppingCartIcon },
    { name: 'Reports', href: '/dashboard/reports', icon: ChartBarIcon },
    { name: 'Settings', href: '/dashboard/settings', icon: CogIcon },
  ],
  supermarket: [
    { name: 'Dashboard', href: '/dashboard', icon: HomeIcon },
    { name: 'Products', href: '/dashboard/products', icon: CubeIcon },
    { name: 'Sales', href: '/dashboard/sales', icon: ShoppingCartIcon },
    { name: 'Staff', href: '/dashboard/staff', icon: UsersIcon },
    { name: 'Reports', href: '/dashboard/reports', icon: ChartBarIcon },
    { name: 'Settings', href: '/dashboard/settings', icon: CogIcon },
  ],
  rentals: [
    { name: 'Dashboard', href: '/dashboard', icon: HomeIcon },
    { name: 'Tenants', href: '/dashboard/tenants', icon: UsersIcon },
    { name: 'Rent Payments', href: '/dashboard/rent-payments', icon: CreditCardIcon },
    { name: 'Reports', href: '/dashboard/reports', icon: ChartBarIcon },
    { name: 'Settings', href: '/dashboard/settings', icon: CogIcon },
  ],
  airbnb: [
    { name: 'Dashboard', href: '/dashboard', icon: HomeIcon },
    { name: 'Listings', href: '/dashboard/listings', icon: BuildingOfficeIcon },
    { name: 'Bookings', href: '/dashboard/bookings', icon: DocumentTextIcon },
    { name: 'Reports', href: '/dashboard/reports', icon: ChartBarIcon },
    { name: 'Settings', href: '/dashboard/settings', icon: CogIcon },
  ],
  hotel: [
    { name: 'Dashboard', href: '/dashboard', icon: HomeIcon },
    { name: 'Rooms', href: '/dashboard/rooms', icon: BuildingStorefrontIcon },
    { name: 'Bookings', href: '/dashboard/bookings', icon: DocumentTextIcon },
    { name: 'Reports', href: '/dashboard/reports', icon: ChartBarIcon },
    { name: 'Settings', href: '/dashboard/settings', icon: CogIcon },
  ],
  school: [
    { name: 'Dashboard', href: '/dashboard', icon: HomeIcon },
    { name: 'Students', href: '/dashboard/students', icon: AcademicCapIcon },
    { name: 'Fee Payments', href: '/dashboard/fee-payments', icon: CreditCardIcon },
    { name: 'Staff', href: '/dashboard/staff', icon: UsersIcon },
    { name: 'Reports', href: '/dashboard/reports', icon: ChartBarIcon },
    { name: 'Settings', href: '/dashboard/settings', icon: CogIcon },
  ],
};

export default function Sidebar({ selectedBusiness, onBusinessSelect }: SidebarProps) {
  const navigation = selectedBusiness ? navigationMap[selectedBusiness.business_type] || [] : [];

  return (
    <div className="flex flex-col h-full">
      {/* Logo */}
      <div className="flex items-center px-6 py-4 border-b border-gray-200 dark:border-gray-700">
        <div className="w-8 h-8 bg-gradient-to-r from-primary-500 to-secondary-500 rounded-lg flex items-center justify-center">
          <span className="text-white font-bold text-sm">F+</span>
        </div>
        <span className="ml-2 text-xl font-bold text-gray-900 dark:text-white">
          Fedha Plus
        </span>
      </div>

      {/* Business Selector */}
      <BusinessSelector
        selectedBusiness={selectedBusiness}
        onBusinessSelect={onBusinessSelect}
      />

      {/* Navigation */}
      {selectedBusiness && (
        <nav className="flex-1 px-4 py-4 space-y-1">
          {navigation.map((item) => (
            <NavLink
              key={item.name}
              to={item.href}
              className={({ isActive }) =>
                `group flex items-center px-3 py-2 text-sm font-medium rounded-lg transition-colors ${
                  isActive
                    ? 'bg-primary-100 text-primary-700 dark:bg-primary-900 dark:text-primary-300'
                    : 'text-gray-700 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-700'
                }`
              }
            >
              <item.icon className="mr-3 h-5 w-5 flex-shrink-0" />
              {item.name}
            </NavLink>
          ))}
        </nav>
      )}

      {/* Footer */}
      <div className="p-4 border-t border-gray-200 dark:border-gray-700">
        <div className="text-xs text-gray-500 dark:text-gray-400">
          © 2025 Fedha Plus
        </div>
      </div>
    </div>
  );
}

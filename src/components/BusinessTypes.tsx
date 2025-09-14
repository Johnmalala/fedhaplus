import React from 'react';
import { 
  WrenchScrewdriverIcon,
  BuildingStorefrontIcon,
  HomeIcon,
  BuildingOfficeIcon,
  BuildingLibraryIcon,
  AcademicCapIcon
} from '@heroicons/react/24/outline';
import { useLanguage } from '../contexts/LanguageContext';
import { BusinessType } from '../lib/supabase';

export default function BusinessTypes() {
  const { t } = useLanguage();

  const businessTypes: { type: BusinessType, icon: any, title: string, price: string, description: string, popular: boolean }[] = [
    {
      type: 'hardware',
      icon: WrenchScrewdriverIcon,
      title: t('business.hardware.title'),
      price: t('business.hardware.price'),
      description: t('business.hardware.description'),
      popular: false,
    },
    {
      type: 'supermarket',
      icon: BuildingStorefrontIcon,
      title: t('business.supermarket.title'),
      price: t('business.supermarket.price'),
      description: t('business.supermarket.description'),
      popular: false,
    },
    {
      type: 'rentals',
      icon: HomeIcon,
      title: t('business.rentals.title'),
      price: t('business.rentals.price'),
      description: t('business.rentals.description'),
      popular: false,
    },
    {
      type: 'airbnb',
      icon: BuildingOfficeIcon,
      title: t('business.airbnb.title'),
      price: t('business.airbnb.price'),
      description: t('business.airbnb.description'),
      popular: false,
    },
    {
      type: 'hotel',
      icon: BuildingLibraryIcon,
      title: t('business.hotel.title'),
      price: t('business.hotel.price'),
      description: t('business.hotel.description'),
      popular: false,
    },
    {
      type: 'school',
      icon: AcademicCapIcon,
      title: t('business.school.title'),
      price: t('business.school.price'),
      description: t('business.school.description'),
      popular: true,
    },
  ];

  return (
    <div id="pricing" className="py-24 bg-gray-50 dark:bg-gray-800">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <h2 className="text-3xl sm:text-4xl font-bold text-gray-900 dark:text-white mb-4">
            Choose Your Business Type
          </h2>
          <p className="text-xl text-gray-600 dark:text-gray-300 max-w-3xl mx-auto">
            Each plan includes 30-day free trial, M-Pesa integration, daily reports, and staff access control
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          {businessTypes.map((business, index) => (
            <div
              key={index}
              className={`relative bg-white dark:bg-gray-900 rounded-2xl shadow-lg p-8 ${
                business.popular ? 'ring-2 ring-primary-500' : ''
              }`}
            >
              {business.popular && (
                <div className="absolute -top-4 left-1/2 transform -translate-x-1/2">
                  <span className="bg-primary-500 text-white px-4 py-1 rounded-full text-sm font-medium">
                    New & Popular
                  </span>
                </div>
              )}

              <div className="text-center">
                <div className="inline-flex items-center justify-center w-16 h-16 bg-primary-100 dark:bg-primary-900 rounded-2xl mb-6">
                  <business.icon className="h-8 w-8 text-primary-600 dark:text-primary-400" />
                </div>

                <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-2">
                  {business.title}
                </h3>

                <div className="text-3xl font-bold text-primary-600 dark:text-primary-400 mb-4">
                  {business.price}
                </div>

                <p className="text-gray-600 dark:text-gray-300 mb-8">
                  {business.description}
                </p>

                <div 
                  className={`w-full py-3 px-6 rounded-xl font-semibold text-center cursor-default ${
                  business.popular
                    ? 'bg-primary-600 text-white shadow-lg'
                    : 'bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white'
                }`}>
                  Included in All Plans
                </div>
              </div>
            </div>
          ))}
        </div>

        <div className="text-center mt-12">
          <p className="text-gray-600 dark:text-gray-400">
            All plans include: Mobile app, Cloud backup, 24/7 support, and Supabase integration
          </p>
        </div>
      </div>
    </div>
  );
}

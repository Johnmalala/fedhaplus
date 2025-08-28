import React from 'react';
import { 
  CreditCardIcon,
  DocumentChartBarIcon,
  ShieldCheckIcon,
  DevicePhoneMobileIcon,
  GlobeAltIcon,
  ClockIcon
} from '@heroicons/react/24/outline';
import { useLanguage } from '../contexts/LanguageContext';

export default function Features() {
  const { t } = useLanguage();

  const features = [
    {
      icon: CreditCardIcon,
      title: t('features.mpesa'),
      description: t('features.mpesa.desc'),
    },
    {
      icon: DocumentChartBarIcon,
      title: t('features.reports'),
      description: t('features.reports.desc'),
    },
    {
      icon: ShieldCheckIcon,
      title: t('features.access'),
      description: t('features.access.desc'),
    },
    {
      icon: DevicePhoneMobileIcon,
      title: t('features.mobile'),
      description: t('features.mobile.desc'),
    },
    {
      icon: GlobeAltIcon,
      title: t('features.bilingual'),
      description: t('features.bilingual.desc'),
    },
    {
      icon: ClockIcon,
      title: t('features.trial'),
      description: t('features.trial.desc'),
    },
  ];

  return (
    <div id="features" className="py-24 bg-white dark:bg-gray-900">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <h2 className="text-3xl sm:text-4xl font-bold text-gray-900 dark:text-white mb-4">
            {t('features.title')}
          </h2>
          <p className="text-xl text-gray-600 dark:text-gray-300 max-w-3xl mx-auto">
            Built specifically for Kenyan businesses with local payment integration and multi-language support
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          {features.map((feature, index) => (
            <div
              key={index}
              className="group p-8 bg-gray-50 dark:bg-gray-800 rounded-2xl hover:bg-primary-50 dark:hover:bg-gray-700 transition-all duration-300"
            >
              <div className="inline-flex items-center justify-center w-12 h-12 bg-primary-100 dark:bg-primary-900 group-hover:bg-primary-500 rounded-xl mb-6 transition-all duration-300">
                <feature.icon className="h-6 w-6 text-primary-600 dark:text-primary-400 group-hover:text-white" />
              </div>

              <h3 className="text-xl font-semibold text-gray-900 dark:text-white mb-4">
                {feature.title}
              </h3>

              <p className="text-gray-600 dark:text-gray-300">
                {feature.description}
              </p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

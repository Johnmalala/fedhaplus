import React from 'react';
import { CheckIcon } from '@heroicons/react/20/solid';
import { useLanguage } from '../contexts/LanguageContext';

interface HeroProps {
  onGetStarted: () => void;
}

export default function Hero({ onGetStarted }: HeroProps) {
  const { t } = useLanguage();

  const features = [
    t('hero.features').split(' • ')[0],
    t('hero.features').split(' • ')[1],
    t('hero.features').split(' • ')[2],
  ];

  return (
    <div className="relative bg-white dark:bg-gray-900">
      <div className="absolute inset-0 bg-gradient-to-r from-primary-50 to-secondary-50 dark:from-gray-900 dark:to-gray-800"></div>
      <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-24">
        <div className="text-center">
          {/* Badge */}
          <div className="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-primary-100 dark:bg-primary-900 text-primary-800 dark:text-primary-200 mb-8">
            <span className="mr-2">🇰🇪</span>
            Made for Kenyan Businesses
          </div>

          {/* Title */}
          <h1 className="text-4xl sm:text-5xl lg:text-6xl font-bold text-gray-900 dark:text-white mb-6">
            <span className="block">{t('hero.title')}</span>
            <span className="block text-primary-600 dark:text-primary-400 mt-2">
              {t('hero.subtitle')}
            </span>
          </h1>

          {/* Description */}
          <p className="max-w-3xl mx-auto text-xl text-gray-600 dark:text-gray-300 mb-8">
            {t('hero.description')}
          </p>

          {/* CTA Button */}
          <div className="mb-12">
            <button 
              onClick={onGetStarted}
              className="bg-primary-600 hover:bg-primary-700 text-white px-8 py-4 rounded-xl text-lg font-semibold shadow-lg hover:shadow-xl transform hover:scale-105 transition-all duration-200"
            >
              {t('hero.cta')}
            </button>
          </div>

          {/* Features */}
          <div className="flex flex-wrap justify-center items-center gap-6 text-sm text-gray-600 dark:text-gray-400">
            {features.map((feature, index) => (
              <div key={index} className="flex items-center">
                <CheckIcon className="h-4 w-4 text-primary-600 dark:text-primary-400 mr-2" />
                <span>{feature}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

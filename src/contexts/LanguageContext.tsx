import React, { createContext, useContext, useState, useEffect } from 'react';

type Language = 'en' | 'sw';

interface LanguageContextType {
  language: Language;
  setLanguage: (lang: Language) => void;
  t: (key: string) => string;
}

const LanguageContext = createContext<LanguageContextType | undefined>(undefined);

const translations = {
  en: {
    // Navigation
    'nav.home': 'Home',
    'nav.features': 'Features',
    'nav.pricing': 'Pricing',
    'nav.contact': 'Contact',
    'nav.login': 'Login',
    'nav.signup': 'Get Started',
    
    // Hero Section
    'hero.title': 'Your Wealth, Amplified',
    'hero.subtitle': 'All-in-One Business & School Management SaaS for Kenya',
    'hero.description': 'Manage hardware shops, supermarkets, rentals, hotels, and schools with M-Pesa integration, staff access control, and automated reporting.',
    'hero.cta': 'Start 30-Day Free Trial',
    'hero.features': 'No Credit Card Required • M-Pesa Integration • Swahili Support',
    
    // Business Types
    'business.hardware.title': 'Hardware & Small Shops',
    'business.hardware.price': 'KSh 1,500/month',
    'business.hardware.description': 'Perfect for general stores, electronics shops, and small retail businesses',
    
    'business.supermarket.title': 'Supermarket',
    'business.supermarket.price': 'KSh 7,000/month',
    'business.supermarket.description': 'Advanced features for grocery stores and inventory-heavy businesses',
    
    'business.rentals.title': 'Apartment Rentals',
    'business.rentals.price': 'KSh 3,000/month',
    'business.rentals.description': 'Comprehensive solution for landlords and estate managers',
    
    'business.airbnb.title': 'Airbnb Management',
    'business.airbnb.price': 'KSh 3,000/month',
    'business.airbnb.description': 'Streamline short-term rentals and guest house operations',
    
    'business.hotel.title': 'Hotel Management',
    'business.hotel.price': 'KSh 5,000/month',
    'business.hotel.description': 'Complete hotel operations from front desk to housekeeping',
    
    'business.school.title': 'School Management',
    'business.school.price': 'KSh 4,000/month',
    'business.school.description': 'Manage private schools, academies, and training centers',
    
    // Features
    'features.title': 'Everything You Need to Grow Your Business',
    'features.mpesa': 'M-Pesa Integration',
    'features.mpesa.desc': 'Automated payments and renewals',
    'features.reports': 'Daily Reports',
    'features.reports.desc': 'Email & SMS summaries at 8 PM',
    'features.access': 'Staff Access Control',
    'features.access.desc': 'Fine-grained role-based permissions',
    'features.mobile': 'Mobile-First',
    'features.mobile.desc': 'Works perfectly on all devices',
    'features.bilingual': 'Swahili + English',
    'features.bilingual.desc': 'Full language support',
    'features.trial': '30-Day Free Trial',
    'features.trial.desc': 'No credit card required',
    
    // Common
    'common.loading': 'Loading...',
    'common.save': 'Save',
    'common.cancel': 'Cancel',
    'common.delete': 'Delete',
    'common.edit': 'Edit',
    'common.view': 'View',
    'common.add': 'Add',
    'common.search': 'Search',
    'common.filter': 'Filter',
    'common.export': 'Export',
    'common.print': 'Print',
  },
  sw: {
    // Navigation
    'nav.home': 'Nyumbani',
    'nav.features': 'Huduma',
    'nav.pricing': 'Bei',
    'nav.contact': 'Mawasiliano',
    'nav.login': 'Ingia',
    'nav.signup': 'Anza Sasa',
    
    // Hero Section
    'hero.title': 'Fedha Yako, Ingeuka Plus',
    'hero.subtitle': 'Mfumo wa Kusimamia Biashara na Shule - Kenya',
    'hero.description': 'Simamia maduka, supermarket, nyumba za kupanga, hoteli, na shule kwa kutumia M-Pesa na ripoti za kila siku.',
    'hero.cta': 'Anza Jaribio la Siku 30',
    'hero.features': 'Hakuna Kadi ya Mkopo • M-Pesa • Lugha ya Kiswahili',
    
    // Business Types
    'business.hardware.title': 'Maduka ya Hardware',
    'business.hardware.price': 'KSh 1,500/mwezi',
    'business.hardware.description': 'Bora kwa maduka ya jumla, elektroniki, na biashara ndogo',
    
    'business.supermarket.title': 'Supermarket',
    'business.supermarket.price': 'KSh 7,000/mwezi',
    'business.supermarket.description': 'Huduma za kina kwa maduka ya vyakula na biashara kubwa',
    
    'business.rentals.title': 'Nyumba za Kupanga',
    'business.rentals.price': 'KSh 3,000/mwezi',
    'business.rentals.description': 'Suluhisho kamili kwa wamiliki wa nyumba',
    
    'business.airbnb.title': 'Usimamizi wa Airbnb',
    'business.airbnb.price': 'KSh 3,000/mwezi',
    'business.airbnb.description': 'Rahisisha nyumba za kukodisha na nyumba za wageni',
    
    'business.hotel.title': 'Usimamizi wa Hoteli',
    'business.hotel.price': 'KSh 5,000/mwezi',
    'business.hotel.description': 'Usimamizi kamili wa hoteli kutoka reception',
    
    'business.school.title': 'Usimamizi wa Shule',
    'business.school.price': 'KSh 4,000/mwezi',
    'business.school.description': 'Simamia shule za kibinafsi na vyuo vya ufundi',
    
    // Features
    'features.title': 'Kila Kitu Unachohitaji Kukuza Biashara Yako',
    'features.mpesa': 'Uunganisho wa M-Pesa',
    'features.mpesa.desc': 'Malipo ya kiotomatiki',
    'features.reports': 'Ripoti za Kila Siku',
    'features.reports.desc': 'Barua pepe na SMS saa 8 jioni',
    'features.access': 'Udhibiti wa Wafanyakazi',
    'features.access.desc': 'Ruhusa za kina za majukumu',
    'features.mobile': 'Simu-Kwanza',
    'features.mobile.desc': 'Inafanya kazi vizuri kila mahali',
    'features.bilingual': 'Kiswahili + Kiingereza',
    'features.bilingual.desc': 'Msaada kamili wa lugha',
    'features.trial': 'Jaribio la Siku 30',
    'features.trial.desc': 'Hakuna kadi ya mkopo',
    
    // Common
    'common.loading': 'Inapakia...',
    'common.save': 'Hifadhi',
    'common.cancel': 'Ghairi',
    'common.delete': 'Futa',
    'common.edit': 'Hariri',
    'common.view': 'Ona',
    'common.add': 'Ongeza',
    'common.search': 'Tafuta',
    'common.filter': 'Chuja',
    'common.export': 'Hamisha',
    'common.print': 'Chapisha',
  }
};

export function LanguageProvider({ children }: { children: React.ReactNode }) {
  const [language, setLanguage] = useState<Language>(() => {
    const saved = localStorage.getItem('fedha-plus-language');
    return (saved as Language) || 'en';
  });

  useEffect(() => {
    localStorage.setItem('fedha-plus-language', language);
  }, [language]);

  const t = (key: string): string => {
    return translations[language][key as keyof typeof translations['en']] || key;
  };

  return (
    <LanguageContext.Provider value={{ language, setLanguage, t }}>
      {children}
    </LanguageContext.Provider>
  );
}

export function useLanguage() {
  const context = useContext(LanguageContext);
  if (context === undefined) {
    throw new Error('useLanguage must be used within a LanguageProvider');
  }
  return context;
}

import React from 'react';
import { useLanguage } from '../contexts/LanguageContext';

export default function Footer() {
  const { t } = useLanguage();

  return (
    <footer className="bg-gray-900 text-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
          {/* Logo & Description */}
          <div className="col-span-1 md:col-span-2">
            <div className="flex items-center mb-4">
              <div className="w-8 h-8 bg-gradient-to-r from-primary-500 to-secondary-500 rounded-lg flex items-center justify-center">
                <span className="text-white font-bold text-sm">F+</span>
              </div>
              <span className="ml-2 text-xl font-bold">Fedha Plus</span>
            </div>
            <p className="text-gray-400 mb-6 max-w-md">
              Empowering Kenyan businesses and schools with comprehensive management solutions, 
              M-Pesa integration, and intelligent access control.
            </p>
            <div className="text-sm text-gray-400">
              <p className="mb-1">📧 support@fedhaplus.com</p>
              <p className="mb-1">📱 +254 700 000 000</p>
              <p>🌍 Nairobi, Kenya</p>
            </div>
          </div>

          {/* Business Types */}
          <div>
            <h3 className="text-lg font-semibold mb-4">Business Types</h3>
            <ul className="space-y-2 text-gray-400">
              <li><a href="#" className="hover:text-white transition-colors">Hardware Shops</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Supermarkets</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Rentals</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Hotels</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Schools</a></li>
            </ul>
          </div>

          {/* Support */}
          <div>
            <h3 className="text-lg font-semibold mb-4">Support</h3>
            <ul className="space-y-2 text-gray-400">
              <li><a href="#" className="hover:text-white transition-colors">Help Center</a></li>
              <li><a href="#" className="hover:text-white transition-colors">API Docs</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Training</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Community</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Status</a></li>
            </ul>
          </div>
        </div>

        <div className="border-t border-gray-700 mt-12 pt-8 flex flex-col md:flex-row justify-between items-center">
          <p className="text-gray-400 text-sm">
            © 2025 Fedha Plus. All rights reserved.
          </p>
          <div className="flex space-x-6 mt-4 md:mt-0">
            <a href="#" className="text-gray-400 hover:text-white text-sm transition-colors">Privacy</a>
            <a href="#" className="text-gray-400 hover:text-white text-sm transition-colors">Terms</a>
            <a href="#" className="text-gray-400 hover:text-white text-sm transition-colors">Security</a>
          </div>
        </div>
      </div>
    </footer>
  );
}

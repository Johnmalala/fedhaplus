import React, { useState } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { useLanguage } from '../../contexts/LanguageContext';
import { useTheme } from '../../contexts/ThemeContext';
import {
  Bars3Icon,
  BellIcon,
  UserCircleIcon,
  SunIcon,
  MoonIcon,
  GlobeAltIcon,
  ArrowRightOnRectangleIcon,
} from '@heroicons/react/24/outline';
import { Menu, Transition } from '@headlessui/react';

interface DashboardLayoutProps {
  children: React.ReactNode;
  sidebar: React.ReactNode;
}

export default function DashboardLayout({ children, sidebar }: DashboardLayoutProps) {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const { user, profile, signOut } = useAuth();
  const { theme, toggleTheme } = useTheme();
  const { language, setLanguage, t } = useLanguage();

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900">
      {/* Mobile sidebar overlay */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 z-40 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        >
          <div className="absolute inset-0 bg-gray-600 opacity-75"></div>
        </div>
      )}

      {/* Sidebar */}
      <div className={`fixed inset-y-0 left-0 z-50 w-64 bg-white dark:bg-gray-800 shadow-lg transform transition-transform duration-300 ease-in-out lg:translate-x-0 lg:static lg:inset-0 ${
        sidebarOpen ? 'translate-x-0' : '-translate-x-full'
      }`}>
        {sidebar}
      </div>

      {/* Main content */}
      <div className="lg:pl-64">
        {/* Top header */}
        <header className="bg-white dark:bg-gray-800 shadow-sm border-b border-gray-200 dark:border-gray-700">
          <div className="px-4 sm:px-6 lg:px-8">
            <div className="flex justify-between items-center h-16">
              <div className="flex items-center">
                <button
                  onClick={() => setSidebarOpen(!sidebarOpen)}
                  className="lg:hidden p-2 rounded-md text-gray-400 hover:text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-700"
                >
                  <Bars3Icon className="h-6 w-6" />
                </button>
              </div>

              <div className="flex items-center space-x-4">
                {/* Language Toggle */}
                <button
                  onClick={() => setLanguage(language === 'en' ? 'sw' : 'en')}
                  className="p-2 text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700"
                >
                  <GlobeAltIcon className="h-5 w-5" />
                  <span className="ml-1 text-xs font-medium">
                    {language.toUpperCase()}
                  </span>
                </button>

                {/* Theme Toggle */}
                <button
                  onClick={toggleTheme}
                  className="p-2 text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700"
                >
                  {theme === 'light' ? (
                    <MoonIcon className="h-5 w-5" />
                  ) : (
                    <SunIcon className="h-5 w-5" />
                  )}
                </button>

                {/* Notifications */}
                <button className="p-2 text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700">
                  <BellIcon className="h-5 w-5" />
                </button>

                {/* User menu */}
                <Menu as="div" className="relative">
                  <Menu.Button className="flex items-center space-x-2 p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700">
                    <UserCircleIcon className="h-6 w-6 text-gray-500 dark:text-gray-400" />
                    <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
                      {profile?.full_name || user?.email}
                    </span>
                  </Menu.Button>

                  <Transition
                    enter="transition ease-out duration-100"
                    enterFrom="transform opacity-0 scale-95"
                    enterTo="transform opacity-100 scale-100"
                    leave="transition ease-in duration-75"
                    leaveFrom="transform opacity-100 scale-100"
                    leaveTo="transform opacity-0 scale-95"
                  >
                    <Menu.Items className="absolute right-0 mt-2 w-48 bg-white dark:bg-gray-800 rounded-md shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none">
                      <div className="py-1">
                        <Menu.Item>
                          {({ active }) => (
                            <button
                              onClick={signOut}
                              className={`${
                                active ? 'bg-gray-100 dark:bg-gray-700' : ''
                              } flex items-center w-full px-4 py-2 text-sm text-gray-700 dark:text-gray-300`}
                            >
                              <ArrowRightOnRectangleIcon className="h-4 w-4 mr-2" />
                              Sign out
                            </button>
                          )}
                        </Menu.Item>
                      </div>
                    </Menu.Items>
                  </Transition>
                </Menu>
              </div>
            </div>
          </div>
        </header>

        {/* Page content */}
        <main className="py-6">
          <div className="px-4 sm:px-6 lg:px-8">
            {children}
          </div>
        </main>
      </div>
    </div>
  );
}

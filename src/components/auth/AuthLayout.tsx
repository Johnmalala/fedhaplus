import React from 'react';
import { Link } from 'react-router-dom';

interface AuthLayoutProps {
  children: React.ReactNode;
  title: string;
  subtitle: string;
  footerContent: React.ReactNode;
}

export default function AuthLayout({ children, title, subtitle, footerContent }: AuthLayoutProps) {
  return (
    <div className="min-h-screen w-full lg:grid lg:grid-cols-2">
      <div className="flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
        <div className="mx-auto grid w-[350px] gap-6">
          <div className="grid gap-2 text-center">
            <Link to="/" className="flex items-center justify-center mb-4">
               <div className="w-12 h-12 bg-gradient-to-r from-primary-500 to-secondary-500 rounded-lg flex items-center justify-center">
                <span className="text-white font-bold text-xl">F+</span>
              </div>
            </Link>
            <h1 className="text-3xl font-bold text-gray-900 dark:text-white">{title}</h1>
            <p className="text-balance text-gray-600 dark:text-gray-400">
              {subtitle}
            </p>
          </div>
          <div className="grid gap-4">
            {children}
          </div>
          <div className="mt-4 text-center text-sm text-gray-600 dark:text-gray-400">
            {footerContent}
          </div>
        </div>
      </div>
      <div className="hidden bg-gray-100 lg:flex items-center justify-center dark:bg-gray-800/50">
        <div className="text-center p-12">
            <h2 className="text-3xl font-bold text-gray-900 dark:text-white">Empowering Kenyan Businesses</h2>
            <p className="mt-4 text-lg text-gray-600 dark:text-gray-300 max-w-md mx-auto">
                From hardware shops to schools, Fedha Plus provides the tools you need to succeed.
            </p>
            <img
                src="https://img-wrapper.vercel.app/image?url=https://img-wrapper.vercel.app/image?url=https://placehold.co/600x400/16a34a/ffffff?text=Fedha+Plus"
                alt="Fedha Plus Illustration"
                className="mt-8 rounded-lg shadow-xl"
            />
        </div>
      </div>
    </div>
  );
}

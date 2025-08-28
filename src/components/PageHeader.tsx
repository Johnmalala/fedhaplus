import React from 'react';

interface PageHeaderProps {
  title: string;
  subtitle: string;
  actions?: React.ReactNode;
}

export default function PageHeader({ title, subtitle, actions }: PageHeaderProps) {
  return (
    <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-8">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">{title}</h1>
        <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">{subtitle}</p>
      </div>
      {actions && <div className="mt-4 sm:mt-0">{actions}</div>}
    </div>
  );
}

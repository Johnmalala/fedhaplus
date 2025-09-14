import React from 'react';
import { clsx } from 'clsx';

export function Table({ children }: { children: React.ReactNode }) {
  return (
    <div className="overflow-x-auto -mx-4 sm:-mx-6">
      <div className="inline-block min-w-full py-2 align-middle px-4 sm:px-6">
        <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
          {children}
        </table>
      </div>
    </div>
  );
}

export function TableHeader({ children }: { children: React.ReactNode }) {
  return (
    <thead className="bg-gray-50 dark:bg-gray-700/50">
      <tr>{children}</tr>
    </thead>
  );
}

export function TableHead({ children }: { children: React.ReactNode }) {
  return (
    <th scope="col" className="px-4 py-3 sm:px-6 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
      {children}
    </th>
  );
}

export function TableBody({ children }: { children: React.ReactNode }) {
  return <tbody className="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">{children}</tbody>;
}

export function TableRow({ children }: { children: React.ReactNode }) {
  return <tr>{children}</tr>;
}

export function TableCell({ children, className }: { children: React.ReactNode, className?: string }) {
  return <td className={clsx('px-4 py-4 sm:px-6 whitespace-nowrap text-sm text-gray-900 dark:text-gray-200', className)}>{children}</td>;
}

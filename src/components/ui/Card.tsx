import React from 'react';
import { clsx } from 'clsx';

interface CardProps {
  children: React.ReactNode;
  className?: string;
}

export function Card({ children, className }: CardProps) {
  return (
    <div className={clsx('bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700', className)}>
      {children}
    </div>
  );
}

export function CardHeader({ children, className }: CardProps) {
  return <div className={clsx('p-4 sm:p-6 border-b border-gray-200 dark:border-gray-700', className)}>{children}</div>;
}

export function CardContent({ children, className }: CardProps) {
  return <div className={clsx('p-4 sm:p-6', className)}>{children}</div>;
}

export function CardFooter({ children, className }: CardProps) {
  return <div className={clsx('p-4 sm:p-6 border-t border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800/50 rounded-b-xl', className)}>{children}</div>;
}

import React from 'react';
import { clsx } from 'clsx';

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  children: React.ReactNode;
  variant?: 'primary' | 'secondary' | 'danger' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  icon?: React.ReactElement;
}

export function Button({ children, variant = 'primary', size = 'md', icon, className, ...props }: ButtonProps) {
  const baseClasses = 'inline-flex items-center justify-center font-semibold rounded-lg transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 dark:focus:ring-offset-gray-900 disabled:opacity-50 disabled:pointer-events-none';

  const variantClasses = {
    primary: 'bg-primary-600 text-white hover:bg-primary-700 focus:ring-primary-500',
    secondary: 'bg-gray-100 text-gray-800 hover:bg-gray-200 dark:bg-gray-700 dark:text-gray-200 dark:hover:bg-gray-600 focus:ring-gray-500',
    danger: 'bg-red-600 text-white hover:bg-red-700 focus:ring-red-500',
    ghost: 'bg-transparent text-gray-800 hover:bg-gray-100 dark:text-gray-200 dark:hover:bg-gray-700 focus:ring-gray-500',
  };

  const sizeClasses = {
    sm: 'px-3 py-1.5 text-sm',
    md: 'px-4 py-2 text-sm',
    lg: 'px-6 py-3 text-base',
  };

  const iconOnlySizeClasses = {
    sm: 'p-1.5',
    md: 'p-2',
    lg: 'p-3',
  }

  const iconSpacing = children ? 'mr-2' : '';

  return (
    <button
      className={clsx(
        baseClasses,
        variantClasses[variant],
        children ? sizeClasses[size] : iconOnlySizeClasses[size],
        className
      )}
      {...props}
    >
      {icon && React.cloneElement(icon, { className: `h-5 w-5 ${iconSpacing}` })}
      {children}
    </button>
  );
}

import React from 'react';
import { clsx } from 'clsx';

interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  icon?: React.ReactElement;
}

export function Input({ icon, className, ...props }: InputProps) {
  const baseClasses = 'w-full border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent dark:bg-gray-800 dark:text-white transition-colors';
  const withIconClasses = 'pl-10';
  const withoutIconClasses = 'px-3';

  return (
    <div className="relative">
      {icon && <div className="absolute inset-y-0 left-0 flex items-center pl-3 pointer-events-none">{React.cloneElement(icon, { className: 'h-5 w-5 text-gray-400' })}</div>}
      <input
        className={clsx(baseClasses, 'py-2', icon ? withIconClasses : withoutIconClasses, className)}
        {...props}
      />
    </div>
  );
}

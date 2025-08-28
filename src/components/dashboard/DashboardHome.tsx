import React, { useState, useEffect } from 'react';
import {
  CurrencyDollarIcon,
  ShoppingCartIcon,
  UsersIcon,
  TrendingUpIcon,
} from '@heroicons/react/24/outline';
import { supabase, type Business } from '../../lib/supabase';
import { useLanguage } from '../../contexts/LanguageContext';
import { format, startOfMonth, endOfMonth, subMonths } from 'date-fns';

interface DashboardHomeProps {
  business: Business;
}

interface DashboardStats {
  totalRevenue: number;
  monthlyRevenue: number;
  totalTransactions: number;
  monthlyTransactions: number;
  totalCustomers: number;
  revenueGrowth: number;
}

export default function DashboardHome({ business }: DashboardHomeProps) {
  const [stats, setStats] = useState<DashboardStats>({
    totalRevenue: 0,
    monthlyRevenue: 0,
    totalTransactions: 0,
    monthlyTransactions: 0,
    totalCustomers: 0,
    revenueGrowth: 0,
  });
  const [loading, setLoading] = useState(true);
  const { t } = useLanguage();

  useEffect(() => {
    fetchDashboardStats();
  }, [business.id]);

  const fetchDashboardStats = async () => {
    try {
      const now = new Date();
      const startOfCurrentMonth = startOfMonth(now);
      const endOfCurrentMonth = endOfMonth(now);
      const startOfLastMonth = startOfMonth(subMonths(now, 1));
      const endOfLastMonth = endOfMonth(subMonths(now, 1));

      // Get revenue stats based on business type
      let revenueQuery;
      let customerCountQuery;

      switch (business.business_type) {
        case 'hardware':
        case 'supermarket':
          // Sales-based revenue
          revenueQuery = supabase
            .from('sales')
            .select('total_amount, created_at')
            .eq('business_id', business.id);
          
          customerCountQuery = supabase
            .from('sales')
            .select('customer_phone')
            .eq('business_id', business.id)
            .not('customer_phone', 'is', null);
          break;

        case 'rentals':
          // Rent payments
          revenueQuery = supabase
            .from('rent_payments')
            .select('amount, created_at')
            .eq('tenant_id', 'in', `(SELECT id FROM tenants WHERE business_id = '${business.id}')`)
            .eq('status', 'paid');
          
          customerCountQuery = supabase
            .from('tenants')
            .select('id')
            .eq('business_id', business.id)
            .eq('is_active', true);
          break;

        case 'school':
          // Fee payments
          revenueQuery = supabase
            .from('fee_payments')
            .select('amount, created_at')
            .eq('student_id', 'in', `(SELECT id FROM students WHERE business_id = '${business.id}')`)
            .eq('status', 'paid');
          
          customerCountQuery = supabase
            .from('students')
            .select('id')
            .eq('business_id', business.id)
            .eq('is_active', true);
          break;

        case 'hotel':
        case 'airbnb':
          // Booking payments
          revenueQuery = supabase
            .from('bookings')
            .select('paid_amount, created_at')
            .eq('business_id', business.id);
          
          customerCountQuery = supabase
            .from('bookings')
            .select('guest_phone')
            .eq('business_id', business.id)
            .not('guest_phone', 'is', null);
          break;

        default:
          revenueQuery = supabase
            .from('sales')
            .select('total_amount, created_at')
            .eq('business_id', business.id);
          
          customerCountQuery = supabase
            .from('sales')
            .select('customer_phone')
            .eq('business_id', business.id);
      }

      // Execute queries
      const [revenueData, customerData] = await Promise.all([
        revenueQuery,
        customerCountQuery,
      ]);

      if (revenueData.error) throw revenueData.error;
      if (customerData.error) throw customerData.error;

      // Calculate stats
      const allRevenue = revenueData.data || [];
      const totalRevenue = allRevenue.reduce((sum, item) => {
        const amount = item.total_amount || item.amount || item.paid_amount || 0;
        return sum + amount;
      }, 0);

      const currentMonthRevenue = allRevenue
        .filter(item => {
          const date = new Date(item.created_at);
          return date >= startOfCurrentMonth && date <= endOfCurrentMonth;
        })
        .reduce((sum, item) => {
          const amount = item.total_amount || item.amount || item.paid_amount || 0;
          return sum + amount;
        }, 0);

      const lastMonthRevenue = allRevenue
        .filter(item => {
          const date = new Date(item.created_at);
          return date >= startOfLastMonth && date <= endOfLastMonth;
        })
        .reduce((sum, item) => {
          const amount = item.total_amount || item.amount || item.paid_amount || 0;
          return sum + amount;
        }, 0);

      const revenueGrowth = lastMonthRevenue > 0 
        ? ((currentMonthRevenue - lastMonthRevenue) / lastMonthRevenue) * 100 
        : 0;

      // Count unique customers
      const uniqueCustomers = new Set(
        customerData.data
          ?.map(item => item.customer_phone || item.guest_phone)
          .filter(Boolean)
      ).size;

      setStats({
        totalRevenue,
        monthlyRevenue: currentMonthRevenue,
        totalTransactions: allRevenue.length,
        monthlyTransactions: allRevenue.filter(item => {
          const date = new Date(item.created_at);
          return date >= startOfCurrentMonth && date <= endOfCurrentMonth;
        }).length,
        totalCustomers: customerData.data?.length || uniqueCustomers,
        revenueGrowth,
      });

    } catch (error) {
      console.error('Error fetching dashboard stats:', error);
    } finally {
      setLoading(false);
    }
  };

  const statCards = [
    {
      title: 'Monthly Revenue',
      value: `KSh ${stats.monthlyRevenue.toLocaleString()}`,
      change: `${stats.revenueGrowth > 0 ? '+' : ''}${stats.revenueGrowth.toFixed(1)}%`,
      changeType: stats.revenueGrowth >= 0 ? 'positive' : 'negative',
      icon: CurrencyDollarIcon,
    },
    {
      title: 'Total Revenue',
      value: `KSh ${stats.totalRevenue.toLocaleString()}`,
      change: 'All time',
      changeType: 'neutral',
      icon: TrendingUpIcon,
    },
    {
      title: 'Monthly Transactions',
      value: stats.monthlyTransactions.toString(),
      change: `${stats.totalTransactions} total`,
      changeType: 'neutral',
      icon: ShoppingCartIcon,
    },
    {
      title: business.business_type === 'school' ? 'Students' : 
             business.business_type === 'rentals' ? 'Tenants' : 'Customers',
      value: stats.totalCustomers.toString(),
      change: 'Active',
      changeType: 'neutral',
      icon: UsersIcon,
    },
  ];

  return (
    <div>
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">
          Welcome back!
        </h1>
        <p className="text-gray-600 dark:text-gray-400">
          Here'"'"'s what'"'"'s happening with {business.name} today.
        </p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        {statCards.map((stat, index) => (
          <div
            key={index}
            className="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 p-6"
          >
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-600 dark:text-gray-400">
                  {stat.title}
                </p>
                <p className="text-2xl font-bold text-gray-900 dark:text-white mt-1">
                  {loading ? '...' : stat.value}
                </p>
              </div>
              <div className={`p-3 rounded-lg ${
                stat.changeType === 'positive' ? 'bg-green-100 dark:bg-green-900/20' :
                stat.changeType === 'negative' ? 'bg-red-100 dark:bg-red-900/20' :
                'bg-gray-100 dark:bg-gray-700'
              }`}>
                <stat.icon className={`h-6 w-6 ${
                  stat.changeType === 'positive' ? 'text-green-600 dark:text-green-400' :
                  stat.changeType === 'negative' ? 'text-red-600 dark:text-red-400' :
                  'text-gray-600 dark:text-gray-400'
                }`} />
              </div>
            </div>
            <div className="mt-4">
              <span className={`text-sm ${
                stat.changeType === 'positive' ? 'text-green-600 dark:text-green-400' :
                stat.changeType === 'negative' ? 'text-red-600 dark:text-red-400' :
                'text-gray-600 dark:text-gray-400'
              }`}>
                {stat.change}
              </span>
            </div>
          </div>
        ))}
      </div>

      {/* Business Type Specific Content */}
      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 p-6">
        <h2 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">
          Quick Actions
        </h2>
        
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {business.business_type === 'hardware' && (
            <>
              <QuickActionCard title="Record Sale" href="/dashboard/sales/new" />
              <QuickActionCard title="Add Product" href="/dashboard/products/new" />
              <QuickActionCard title="View Reports" href="/dashboard/reports" />
            </>
          )}
          
          {business.business_type === 'supermarket' && (
            <>
              <QuickActionCard title="Record Sale" href="/dashboard/sales/new" />
              <QuickActionCard title="Manage Inventory" href="/dashboard/products" />
              <QuickActionCard title="Staff Management" href="/dashboard/staff" />
            </>
          )}
          
          {business.business_type === 'rentals' && (
            <>
              <QuickActionCard title="Add Tenant" href="/dashboard/tenants/new" />
              <QuickActionCard title="Record Payment" href="/dashboard/rent-payments/new" />
              <QuickActionCard title="Send Reminders" href="/dashboard/rent-payments" />
            </>
          )}
          
          {business.business_type === 'school' && (
            <>
              <QuickActionCard title="Add Student" href="/dashboard/students/new" />
              <QuickActionCard title="Record Fee Payment" href="/dashboard/fee-payments/new" />
              <QuickActionCard title="Send Fee Reminders" href="/dashboard/fee-payments" />
            </>
          )}
          
          {(business.business_type === 'hotel' || business.business_type === 'airbnb') && (
            <>
              <QuickActionCard title="New Booking" href="/dashboard/bookings/new" />
              <QuickActionCard title="Check-in Guest" href="/dashboard/bookings" />
              <QuickActionCard title="Manage Rooms" href="/dashboard/rooms" />
            </>
          )}
        </div>
      </div>
    </div>
  );
}

function QuickActionCard({ title, href }: { title: string; href: string }) {
  return (
    <a
      href={href}
      className="block p-4 bg-gray-50 dark:bg-gray-700 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-600 transition-colors"
    >
      <h3 className="font-medium text-gray-900 dark:text-white">{title}</h3>
    </a>
  );
}

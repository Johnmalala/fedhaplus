import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import {
  CurrencyDollarIcon,
  ShoppingCartIcon,
  UsersIcon,
  ArrowTrendingUpIcon,
} from '@heroicons/react/24/outline';
import { supabase, type Business } from '../../lib/supabase';
import { useAuth } from '../../contexts/AuthContext';
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
  const { profile } = useAuth();
  const [stats, setStats] = useState<DashboardStats>({
    totalRevenue: 0,
    monthlyRevenue: 0,
    totalTransactions: 0,
    monthlyTransactions: 0,
    totalCustomers: 0,
    revenueGrowth: 0,
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (business?.id) {
      fetchDashboardStats();
    }
  }, [business?.id]);

  const fetchDashboardStats = async () => {
    setLoading(true);
    try {
      const now = new Date();
      const startOfCurrentMonth = startOfMonth(now);
      const endOfCurrentMonth = endOfMonth(now);
      const startOfLastMonth = startOfMonth(subMonths(now, 1));
      const endOfLastMonth = endOfMonth(subMonths(now, 1));

      // This logic can be moved to a Supabase function for efficiency
      const { data, error } = await supabase.rpc('get_dashboard_stats', {
        p_business_id: business.id
      });
      
      if (error) throw error;

      const allRevenue = data.revenue_data || [];

      const totalRevenue = allRevenue.reduce((sum: number, item: any) => sum + (item.amount || 0), 0);
      
      const currentMonthRevenue = allRevenue
        .filter((item: any) => {
          const date = new Date(item.created_at);
          return date >= startOfCurrentMonth && date <= endOfCurrentMonth;
        })
        .reduce((sum: number, item: any) => sum + (item.amount || 0), 0);

      const lastMonthRevenue = allRevenue
        .filter((item: any) => {
          const date = new Date(item.created_at);
          return date >= startOfLastMonth && date <= endOfLastMonth;
        })
        .reduce((sum: number, item: any) => sum + (item.amount || 0), 0);

      const revenueGrowth = lastMonthRevenue > 0 
        ? ((currentMonthRevenue - lastMonthRevenue) / lastMonthRevenue) * 100 
        : currentMonthRevenue > 0 ? 100 : 0;

      setStats({
        totalRevenue,
        monthlyRevenue: currentMonthRevenue,
        totalTransactions: allRevenue.length,
        monthlyTransactions: allRevenue.filter((item: any) => {
          const date = new Date(item.created_at);
          return date >= startOfCurrentMonth && date <= endOfCurrentMonth;
        }).length,
        totalCustomers: data.customer_count || 0,
        revenueGrowth,
      });

    } catch (error) {
      console.error('Error fetching dashboard stats:', error);
      // Fallback to zeroed stats on error
      setStats({ totalRevenue: 0, monthlyRevenue: 0, totalTransactions: 0, monthlyTransactions: 0, totalCustomers: 0, revenueGrowth: 0 });
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
      icon: ArrowTrendingUpIcon,
    },
    {
      title: 'Monthly Transactions',
      value: stats.monthlyTransactions.toLocaleString(),
      change: `${stats.totalTransactions.toLocaleString()} total`,
      changeType: 'neutral',
      icon: ShoppingCartIcon,
    },
    {
      title: business.business_type === 'school' ? 'Students' : 
             business.business_type === 'rentals' ? 'Tenants' : 'Customers',
      value: stats.totalCustomers.toLocaleString(),
      change: 'Active',
      changeType: 'neutral',
      icon: UsersIcon,
    },
  ];

  if (loading) {
    return (
      <div className="text-center py-12">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600 mx-auto mb-4"></div>
        <p className="text-gray-600 dark:text-gray-400">Loading Dashboard...</p>
      </div>
    );
  }

  return (
    <div>
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">
          Karibu, {profile?.full_name || 'User'}!
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
                  {stat.value}
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
              <span className={`text-sm font-medium ${
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
              <QuickActionCard title="Record Sale" to="sales" />
              <QuickActionCard title="Add Product" to="products" />
              <QuickActionCard title="View Reports" to="reports" />
            </>
          )}
          
          {business.business_type === 'supermarket' && (
            <>
              <QuickActionCard title="Record Sale" to="sales" />
              <QuickActionCard title="Manage Inventory" to="products" />
              <QuickActionCard title="Staff Management" to="staff" />
            </>
          )}
          
          {business.business_type === 'rentals' && (
            <>
              <QuickActionCard title="Add Tenant" to="tenants" />
              <QuickActionCard title="Record Payment" to="rent-payments" />
              <QuickActionCard title="Send Reminders" to="rent-payments" />
            </>
          )}
          
          {business.business_type === 'school' && (
            <>
              <QuickActionCard title="Add Student" to="students" />
              <QuickActionCard title="Record Fee Payment" to="fee-payments" />
              <QuickActionCard title="Send Fee Reminders" to="fee-payments" />
            </>
          )}
          
          {(business.business_type === 'hotel' || business.business_type === 'airbnb') && (
            <>
              <QuickActionCard title="New Booking" to="bookings" />
              <QuickActionCard title="Check-in Guest" to="bookings" />
              <QuickActionCard title="Manage Rooms" to="rooms" />
            </>
          )}
        </div>
      </div>
    </div>
  );
}

function QuickActionCard({ title, to }: { title: string; to: string }) {
  return (
    <Link
      to={to}
      className="block p-4 bg-gray-50 dark:bg-gray-700/50 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
    >
      <h3 className="font-medium text-gray-900 dark:text-white">{title}</h3>
    </Link>
  );
}

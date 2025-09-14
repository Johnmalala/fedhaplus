import React, { useState, useEffect } from 'react';
import PageHeader from '../components/PageHeader';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { BarChart2, TrendingUp, Users, FileText, ArrowLeft } from 'lucide-react';
import SalesReport from '../components/dashboard/reports/SalesReport';
import FeeReport from '../components/dashboard/reports/FeeReport';
import { supabase, type Business } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

interface ReportsPageProps {
  businessId: string;
}

type ReportType = 'sales' | 'revenue' | 'customers' | 'inventory' | 'fees' | 'rent';

const allReportTypes: { id: ReportType, title: string; icon: React.ElementType; description: string; business_types: Business['business_type'][] }[] = [
  { id: 'sales', title: 'Sales Report', icon: BarChart2, description: 'Daily, weekly, and monthly sales performance.', business_types: ['hardware', 'supermarket'] },
  { id: 'fees', title: 'Fee Collection Report', icon: BarChart2, description: 'Track student fee payments.', business_types: ['school'] },
  { id: 'rent', title: 'Rent Roll', icon: FileText, description: 'Summary of all tenant rent payments.', business_types: ['rentals'] },
  { id: 'revenue', title: 'Revenue Growth', icon: TrendingUp, description: 'Track revenue trends over time.', business_types: ['hardware', 'supermarket', 'rentals', 'airbnb', 'hotel', 'school'] },
  { id: 'customers', title: 'Customer Demographics', icon: Users, description: 'Understand your customer base.', business_types: ['hardware', 'supermarket'] },
  { id: 'inventory', title: 'Inventory Summary', icon: FileText, description: 'Stock levels and product performance.', business_types: ['hardware', 'supermarket'] },
];

export default function Reports({ businessId }: ReportsPageProps) {
  const [activeReport, setActiveReport] = useState<ReportType | null>(null);
  const [business, setBusiness] = useState<Business | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchBusiness = async () => {
      setLoading(true);
      const { data, error } = await supabase
        .from('businesses')
        .select('*')
        .eq('id', businessId)
        .single();
      
      if (error) console.error("Error fetching business:", error);
      else setBusiness(data);
      setLoading(false);
    }
    fetchBusiness();
  }, [businessId]);

  const availableReports = business 
    ? allReportTypes.filter(report => report.business_types.includes(business.business_type))
    : [];

  // Currently enabled reports
  const enabledReports: ReportType[] = ['sales', 'fees'];

  if (loading) {
    return <div className="text-center py-12">Loading reports...</div>;
  }

  if (activeReport) {
    return (
      <div>
        <Button variant="ghost" onClick={() => setActiveReport(null)} className="mb-4">
          <ArrowLeft className="h-4 w-4 mr-2" />
          Back to Reports
        </Button>
        {activeReport === 'sales' && <SalesReport businessId={businessId} />}
        {activeReport === 'fees' && <FeeReport businessId={businessId} />}
      </div>
    );
  }

  return (
    <div>
      <PageHeader
        title="Reports"
        subtitle="Generate and view detailed reports for your business."
      />
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {availableReports.map((report) => {
          const isEnabled = enabledReports.includes(report.id);
          return (
            <Card key={report.id}>
              <CardContent className="flex flex-col items-start pt-6">
                <div className={`p-3 rounded-lg mb-4 ${isEnabled ? 'bg-primary-100 dark:bg-primary-900/50' : 'bg-gray-100 dark:bg-gray-700/50'}`}>
                  <report.icon className={`h-6 w-6 ${isEnabled ? 'text-primary-600 dark:text-primary-400' : 'text-gray-400 dark:text-gray-500'}`} />
                </div>
                <h3 className="text-lg font-semibold text-gray-900 dark:text-white">{report.title}</h3>
                <p className="text-sm text-gray-500 dark:text-gray-400 mt-1 mb-4 flex-grow">{report.description}</p>
                <Button 
                  variant={isEnabled ? "secondary" : "ghost"} 
                  size="sm" 
                  onClick={() => isEnabled && setActiveReport(report.id)}
                  disabled={!isEnabled}
                >
                  {isEnabled ? 'Generate' : 'Coming Soon'}
                </Button>
              </CardContent>
            </Card>
          );
        })}
      </div>
    </div>
  );
}

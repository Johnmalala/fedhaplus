import React from 'react';
import PageHeader from '../components/PageHeader';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { BarChart2, TrendingUp, Users, FileText } from 'lucide-react';

const reportTypes = [
  { title: 'Sales Report', icon: BarChart2, description: 'Daily, weekly, and monthly sales performance.' },
  { title: 'Revenue Growth', icon: TrendingUp, description: 'Track revenue trends over time.' },
  { title: 'Customer Demographics', icon: Users, description: 'Understand your customer base.' },
  { title: 'Inventory Summary', icon: FileText, description: 'Stock levels and product performance.' },
  { title: 'Fee Collection Report', icon: BarChart2, description: 'Track student fee payments.' },
  { title: 'Rent Roll', icon: FileText, description: 'Summary of all tenant rent payments.' },
];

export default function Reports() {
  return (
    <div>
      <PageHeader
        title="Reports"
        subtitle="Generate and view detailed reports for your business."
      />
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {reportTypes.map((report) => (
          <Card key={report.title}>
            <CardContent className="flex flex-col items-start">
              <div className="p-3 bg-primary-100 dark:bg-primary-900/50 rounded-lg mb-4">
                <report.icon className="h-6 w-6 text-primary-600 dark:text-primary-400" />
              </div>
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white">{report.title}</h3>
              <p className="text-sm text-gray-500 dark:text-gray-400 mt-1 mb-4">{report.description}</p>
              <Button variant="secondary" size="sm">Generate</Button>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}

import React, { useState, useEffect, useCallback } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate, useNavigate, useLocation, Link } from 'react-router-dom';
import { ThemeProvider } from './contexts/ThemeContext';
import { LanguageProvider } from './contexts/LanguageContext';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import Header from './components/Header';
import Hero from './components/Hero';
import BusinessTypes from './components/BusinessTypes';
import Features from './components/Features';
import AccessControl from './components/AccessControl';
import Footer from './components/Footer';
import DashboardLayout from './components/dashboard/DashboardLayout';
import Sidebar from './components/dashboard/Sidebar';
import DashboardHome from './components/dashboard/DashboardHome';
import { supabase, type Business, type BusinessType } from './lib/supabase';
import AuthPage from './pages/Auth';
import ForgotPassword from './pages/ForgotPassword';
import UpdatePassword from './pages/UpdatePassword';

// Import Pages
import Products from './pages/Products';
import Sales from './pages/Sales';
import Students from './pages/Students';
import Tenants from './pages/Tenants';
import Rooms from './pages/Rooms';
import Listings from './pages/Listings';
import Bookings from './pages/Bookings';
import FeePayments from './pages/FeePayments';
import RentPayments from './pages/RentPayments';
import Staff from './pages/Staff';
import Reports from './pages/Reports';
import Settings from './pages/Settings';

function LandingPage() {
  const navigate = useNavigate();

  const handleSelectBusinessType = (type: BusinessType) => {
    navigate(`/auth?type=${type}`);
  };

  const handleGetStarted = () => {
    const pricingSection = document.getElementById('pricing');
    if (pricingSection) {
      pricingSection.scrollIntoView({ behavior: 'smooth' });
    }
  };

  return (
    <>
      <Header onGetStarted={handleGetStarted} />
      <main>
        <Hero onGetStarted={handleGetStarted} />
        <BusinessTypes onSelectBusinessType={handleSelectBusinessType} />
        <Features />
        <AccessControl />
      </main>
      <Footer />
    </>
  );
}

function Dashboard() {
  const [selectedBusiness, setSelectedBusiness] = useState<Business | null>(null);
  const [businesses, setBusinesses] = useState<Business[]>([]);
  const [loadingBusinesses, setLoadingBusinesses] = useState(true);
  const { user } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  const fetchBusinesses = useCallback(async () => {
    if (!user) return;
    setLoadingBusinesses(true);
    try {
      const { data: fetchedBusinesses, error } = await supabase.rpc('get_my_businesses');

      if (error) {
        console.error('Error fetching user businesses:', error);
        throw error;
      }
        
      setBusinesses(fetchedBusinesses || []);

      const query = new URLSearchParams(location.search);
      const typeFromUrl = query.get('type') as BusinessType | null;

      let businessToSelect: Business | null = null;
      if (typeFromUrl) {
        businessToSelect = fetchedBusinesses?.find(b => b.business_type === typeFromUrl) || null;
      }

      if (!businessToSelect && fetchedBusinesses && fetchedBusinesses.length > 0) {
        businessToSelect = fetchedBusinesses[0];
      }
      
      setSelectedBusiness(businessToSelect);

    } catch (error) {
      console.error('Error processing businesses:', error);
      setBusinesses([]);
      setSelectedBusiness(null);
    } finally {
      setLoadingBusinesses(false);
    }
  }, [user, location.search]);
  
  useEffect(() => {
    fetchBusinesses();
  }, [fetchBusinesses]);

  const handleBusinessSelect = (business: Business) => {
    setSelectedBusiness(business);
    navigate(`/dashboard?type=${business.business_type}`);
  };

  return (
    <DashboardLayout
      sidebar={
        <Sidebar
          businesses={businesses}
          selectedBusiness={selectedBusiness}
          onBusinessSelect={handleBusinessSelect}
          onBusinessCreated={fetchBusinesses}
        />
      }
    >
      <Routes>
        <Route 
          path="/" 
          element={
            loadingBusinesses ? (
              <div className="min-h-screen flex items-center justify-center">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
              </div>
            ) : selectedBusiness ? (
              <DashboardHome business={selectedBusiness} />
            ) : (
              <div className="text-center py-12">
                <h2 className="text-xl font-semibold text-gray-900 dark:text-white mb-4">
                  Welcome to Fedha Plus!
                </h2>
                <p className="text-gray-600 dark:text-gray-400">
                  Select or create a business to get started.
                </p>
              </div>
            )
          } 
        />
        {selectedBusiness && (
          <>
            <Route path="/products" element={<Products businessId={selectedBusiness.id} />} />
            <Route path="/sales" element={<Sales businessId={selectedBusiness.id} />} />
            <Route path="/students" element={<Students businessId={selectedBusiness.id} />} />
            <Route path="/tenants" element={<Tenants businessId={selectedBusiness.id} />} />
            <Route path="/rooms" element={<Rooms businessId={selectedBusiness.id} />} />
            <Route path="/listings" element={<Listings businessId={selectedBusiness.id} />} />
            <Route path="/bookings" element={<Bookings businessId={selectedBusiness.id} />} />
            <Route path="/fee-payments" element={<FeePayments businessId={selectedBusiness.id} />} />
            <Route path="/rent-payments" element={<RentPayments businessId={selectedBusiness.id} />} />
            <Route path="/staff" element={<Staff businessId={selectedBusiness.id} />} />
            <Route path="/reports" element={<Reports businessId={selectedBusiness.id} />} />
            <Route path="/settings" element={<Settings business={selectedBusiness} onBusinessUpdate={fetchBusinesses} />} />
          </>
        )}
      </Routes>
    </DashboardLayout>
  );
}

function AppRoutes() {
  const { user, loading } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  useEffect(() => {
    if (!loading && user && (location.pathname === '/' || location.pathname.startsWith('/auth'))) {
      const query = new URLSearchParams(location.search);
      const typeFromUrl = query.get('type');
      if (typeFromUrl) {
        navigate(`/dashboard?type=${typeFromUrl}`);
      } else {
        navigate('/dashboard');
      }
    }
  }, [user, loading, navigate, location.pathname, location.search]);
  
  return (
    <Routes>
      <Route path="/" element={<LandingPage />} />
      <Route path="/auth" element={<AuthPage />} />
      <Route path="/forgot-password" element={<ForgotPassword />} />
      <Route path="/update-password" element={<UpdatePassword />} />
      <Route 
        path="/dashboard/*" 
        element={
          loading ? (
            <div className="min-h-screen flex items-center justify-center">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
            </div>
          ) : user ? (
            <Dashboard />
          ) : (
            <Navigate to="/" replace />
          )
        } 
      />
    </Routes>
  );
}

function App() {
  return (
    <ThemeProvider>
      <LanguageProvider>
        <Router>
          <AuthProvider>
            <div className="min-h-screen bg-white dark:bg-gray-950 transition-colors duration-200">
              <AppRoutes />
            </div>
          </AuthProvider>
        </Router>
      </LanguageProvider>
    </ThemeProvider>
  );
}

export default App;

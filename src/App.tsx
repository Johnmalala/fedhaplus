import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate, useNavigate, useLocation } from 'react-router-dom';
import { ThemeProvider } from './contexts/ThemeContext';
import { LanguageProvider } from './contexts/LanguageContext';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import Header from './components/Header';
import Hero from './components/Hero';
import BusinessTypes from './components/BusinessTypes';
import Features from './components/Features';
import AccessControl from './components/AccessControl';
import Footer from './components/Footer';
import AuthModal from './components/auth/AuthModal';
import DashboardLayout from './components/dashboard/DashboardLayout';
import Sidebar from './components/dashboard/Sidebar';
import DashboardHome from './components/dashboard/DashboardHome';
import { supabase, type Business } from './lib/supabase';
import Signup from './pages/Signup';

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
  const [showAuthModal, setShowAuthModal] = useState(false);
  const navigate = useNavigate();

  const handleSelectBusinessType = (plan: string) => {
    const planKey = plan.toLowerCase().replace(/ & /g, '-').replace(/ /g, '-');
    navigate(`/signup?plan=${planKey}`);
  };

  const handleGetStarted = () => {
    const pricingSection = document.getElementById('pricing');
    if (pricingSection) {
      pricingSection.scrollIntoView({ behavior: 'smooth' });
    }
  };

  return (
    <>
      <Header onLogin={() => setShowAuthModal(true)} onSignup={handleGetStarted} />
      <main>
        <Hero onGetStarted={handleGetStarted} />
        <BusinessTypes onSelectBusinessType={handleSelectBusinessType} />
        <Features />
        <AccessControl />
      </main>
      <Footer />
      
      <AuthModal
        isOpen={showAuthModal}
        onClose={() => setShowAuthModal(false)}
      />
    </>
  );
}

function Dashboard() {
  const [selectedBusiness, setSelectedBusiness] = useState<Business | null>(null);
  const [businesses, setBusinesses] = useState<Business[]>([]);
  const [loading, setLoading] = useState(true);
  const { user } = useAuth();
  const navigate = useNavigate();

  const fetchBusinesses = async () => {
    if (!user) return;
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('businesses')
        .select('*')
        .eq('owner_id', user.id)
        .order('created_at', { ascending: false });

      if (error) throw error;
      
      setBusinesses(data || []);
      if (data && data.length > 0 && !selectedBusiness) {
        setSelectedBusiness(data[0]);
      } else if (data && data.length === 0) {
        // Handle case where user has no businesses, maybe show a creation screen
      }
    } catch (error) {
      console.error('Error fetching businesses:', error);
    } finally {
      setLoading(false);
    }
  };
  
  useEffect(() => {
    fetchBusinesses();
  }, [user]);

  const handleBusinessSelect = (business: Business) => {
    setSelectedBusiness(business);
    // Navigate to the dashboard home of the selected business
    navigate('/dashboard');
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
      </div>
    );
  }

  return (
    <DashboardLayout
      sidebar={
        <Sidebar
          businesses={businesses}
          selectedBusiness={selectedBusiness}
          onBusinessSelect={handleBusinessSelect}
          onBusinessCreated={fetchBusinesses} // Refresh list when new business is added
        />
      }
    >
      <Routes>
        <Route 
          path="/" 
          element={
            selectedBusiness ? (
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
    if (!loading && user && (location.pathname === '/' || location.pathname.startsWith('/signup'))) {
      navigate('/dashboard');
    }
  }, [user, loading, navigate, location.pathname]);
  
  return (
    <Routes>
      <Route path="/" element={<LandingPage />} />
      <Route path="/signup" element={<Signup />} />
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
            <div className="min-h-screen bg-gray-50 dark:bg-gray-900 transition-colors duration-200">
              <AppRoutes />
            </div>
          </AuthProvider>
        </Router>
      </LanguageProvider>
    </ThemeProvider>
  );
}

export default App;

import React, { useState } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
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
import { type Business } from './lib/supabase';

function LandingPage() {
  const [showAuthModal, setShowAuthModal] = useState(false);
  const [authMode, setAuthMode] = useState<'login' | 'signup'>('login');

  const openAuthModal = (mode: 'login' | 'signup') => {
    setAuthMode(mode);
    setShowAuthModal(true);
  };

  return (
    <>
      <Header onLogin={() => openAuthModal('login')} onSignup={() => openAuthModal('signup')} />
      <main>
        <Hero onGetStarted={() => openAuthModal('signup')} />
        <BusinessTypes />
        <Features />
        <AccessControl />
      </main>
      <Footer />
      
      <AuthModal
        isOpen={showAuthModal}
        onClose={() => setShowAuthModal(false)}
        mode={authMode}
      />
    </>
  );
}

function Dashboard() {
  const [selectedBusiness, setSelectedBusiness] = useState<Business | null>(null);

  return (
    <DashboardLayout
      sidebar={
        <Sidebar
          selectedBusiness={selectedBusiness}
          onBusinessSelect={setSelectedBusiness}
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
                  Create your first business to get started.
                </p>
              </div>
            )
          } 
        />
        <Route path="/products" element={<div>Products Management (Coming Soon)</div>} />
        <Route path="/sales" element={<div>Sales Management (Coming Soon)</div>} />
        <Route path="/students" element={<div>Student Management (Coming Soon)</div>} />
        <Route path="/tenants" element={<div>Tenant Management (Coming Soon)</div>} />
        <Route path="/rooms" element={<div>Room Management (Coming Soon)</div>} />
        <Route path="/bookings" element={<div>Booking Management (Coming Soon)</div>} />
        <Route path="/fee-payments" element={<div>Fee Payments (Coming Soon)</div>} />
        <Route path="/rent-payments" element={<div>Rent Payments (Coming Soon)</div>} />
        <Route path="/staff" element={<div>Staff Management (Coming Soon)</div>} />
        <Route path="/reports" element={<div>Reports (Coming Soon)</div>} />
        <Route path="/settings" element={<div>Settings (Coming Soon)</div>} />
      </Routes>
    </DashboardLayout>
  );
}

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600 mx-auto mb-4"></div>
          <p className="text-gray-600 dark:text-gray-400">Loading...</p>
        </div>
      </div>
    );
  }

  if (!user) {
    return <Navigate to="/" replace />;
  }

  return <>{children}</>;
}

function App() {
  return (
    <ThemeProvider>
      <LanguageProvider>
        <AuthProvider>
          <Router>
            <div className="min-h-screen bg-white dark:bg-gray-900 transition-colors duration-200">
              <Routes>
                <Route path="/" element={<LandingPage />} />
                <Route 
                  path="/dashboard/*" 
                  element={
                    <ProtectedRoute>
                      <Dashboard />
                    </ProtectedRoute>
                  } 
                />
              </Routes>
            </div>
          </Router>
        </AuthProvider>
      </LanguageProvider>
    </ThemeProvider>
  );
}

export default App;

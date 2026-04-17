import React from "react";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { ThemeProvider, createTheme } from "@mui/material/styles";
import CssBaseline from "@mui/material/CssBaseline";
import { ToastContainer } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";

import { AuthProvider } from "./context/AuthContext";
import { ProtectedRoute, ErrorBoundary } from "./components/common";
import { MainLayout } from "./components/layout";
import Login from "./pages/shared/Login";
import NotFound from "./pages/shared/NotFound";

import {
    AdminDashboard,
    AdminUsers,
    AdminOrganisers,
    AdminEvents,
    AdminCategories,
    AdminCities,
    AdminNotifications,
    AdminBoosts,
    AdminRevenue,
} from "./pages/admin";

import {
    OrganiserDashboard,
    OrganiserEvents,
    OrganiserRegistrations,
    OrganiserQuestions,
    OrganiserProfile,
    OrganiserNotifications,
    OrganiserRegistrationQuestions,
    OrganiserCertificates,
    OrganiserBoost,
    OrganiserSubscription,
    OrganiserPolls,
    OrganiserFunnelAnalytics,
    OrganiserCoupons,
    OrganiserSchedule,
} from "./pages/organiser";

const theme = createTheme({
    palette: {
        mode: 'light',
        primary: {
            main: '#6366f1',
            light: '#818cf8',
            dark: '#4f46e5',
            contrastText: '#ffffff',
        },
        secondary: {
            main: '#ec4899',
            light: '#f472b6',
            dark: '#db2777',
            contrastText: '#ffffff',
        },
        success: {
            main: '#10b981',
            light: '#34d399',
            dark: '#059669',
        },
        warning: {
            main: '#f59e0b',
            light: '#fbbf24',
            dark: '#d97706',
        },
        error: {
            main: '#ef4444',
            light: '#f87171',
            dark: '#dc2626',
        },
        info: {
            main: '#3b82f6',
            light: '#60a5fa',
            dark: '#2563eb',
        },
        background: {
            default: '#f1f5f9',
            paper: '#ffffff',
        },
        grey: {
            50: '#f8fafc',
            100: '#f1f5f9',
            200: '#e2e8f0',
            300: '#cbd5e1',
            400: '#94a3b8',
            500: '#64748b',
            600: '#475569',
            700: '#334155',
            800: '#1e293b',
            900: '#0f172a',
        },
    },
    typography: {
        fontFamily: '"Inter", "Roboto", "Helvetica", "Arial", sans-serif',
        h1: { fontWeight: 700 },
        h2: { fontWeight: 700 },
        h3: { fontWeight: 600 },
        h4: { fontWeight: 600 },
        h5: { fontWeight: 600 },
        h6: { fontWeight: 600 },
        subtitle1: { fontWeight: 500 },
        subtitle2: { fontWeight: 500 },
    },
    shape: {
        borderRadius: 12,
    },
    components: {
        MuiButton: {
            styleOverrides: {
                root: {
                    textTransform: 'none',
                    fontWeight: 600,
                    borderRadius: 10,
                    padding: '10px 20px',
                },
                contained: {
                    boxShadow: '0 4px 14px 0 rgba(99, 102, 241, 0.4)',
                    '&:hover': {
                        boxShadow: '0 6px 20px rgba(99, 102, 241, 0.5)',
                    },
                },
            },
        },
        MuiCard: {
            styleOverrides: {
                root: {
                    borderRadius: 16,
                    boxShadow: '0 4px 20px rgba(0, 0, 0, 0.08)',
                    border: '1px solid rgba(0, 0, 0, 0.05)',
                },
            },
        },
        MuiPaper: {
            styleOverrides: {
                root: {
                    borderRadius: 16,
                },
            },
        },
        MuiTextField: {
            styleOverrides: {
                root: {
                    '& .MuiOutlinedInput-root': {
                        borderRadius: 10,
                    },
                },
            },
        },
        MuiChip: {
            styleOverrides: {
                root: {
                    fontWeight: 500,
                },
            },
        },
        MuiTableHead: {
            styleOverrides: {
                root: {
                    '& .MuiTableCell-head': {
                        fontWeight: 600,
                        backgroundColor: '#f8fafc',
                    },
                },
            },
        },
        MuiDrawer: {
            styleOverrides: {
                paper: {
                    border: 'none',
                },
            },
        },
    },
});

function App() {
    return (
        <ErrorBoundary>
            <ThemeProvider theme={theme}>
                <CssBaseline />
                <AuthProvider>
                    <BrowserRouter>
                        <Routes>
                            <Route path="/login" element={<Login />} />
                            <Route element={<ProtectedRoute allowedRoles={["ADMIN", "ORGANISER"]}><MainLayout /></ProtectedRoute>}>
                                <Route path="/admin/dashboard" element={<ProtectedRoute allowedRoles={["ADMIN"]}><AdminDashboard /></ProtectedRoute>} />
                                <Route path="/admin/users" element={<ProtectedRoute allowedRoles={["ADMIN"]}><AdminUsers /></ProtectedRoute>} />
                                <Route path="/admin/organisers" element={<ProtectedRoute allowedRoles={["ADMIN"]}><AdminOrganisers /></ProtectedRoute>} />
                                <Route path="/admin/events" element={<ProtectedRoute allowedRoles={["ADMIN"]}><AdminEvents /></ProtectedRoute>} />
                                <Route path="/admin/categories" element={<ProtectedRoute allowedRoles={["ADMIN"]}><AdminCategories /></ProtectedRoute>} />
                                <Route path="/admin/cities" element={<ProtectedRoute allowedRoles={["ADMIN"]}><AdminCities /></ProtectedRoute>} />
                                <Route path="/admin/notifications" element={<ProtectedRoute allowedRoles={["ADMIN"]}><AdminNotifications /></ProtectedRoute>} />
                                <Route path="/admin/boosts" element={<ProtectedRoute allowedRoles={["ADMIN"]}><AdminBoosts /></ProtectedRoute>} />
                                <Route path="/admin/revenue" element={<ProtectedRoute allowedRoles={["ADMIN"]}><AdminRevenue /></ProtectedRoute>} />
                                <Route path="/organiser/dashboard" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserDashboard /></ProtectedRoute>} />
                                <Route path="/organiser/events" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserEvents /></ProtectedRoute>} />
                                <Route path="/organiser/registrations" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserRegistrations /></ProtectedRoute>} />
                                <Route path="/organiser/questions" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserQuestions /></ProtectedRoute>} />
                                <Route path="/organiser/polls" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserPolls /></ProtectedRoute>} />
                                <Route path="/organiser/funnel" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserFunnelAnalytics /></ProtectedRoute>} />
                                <Route path="/organiser/coupons" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserCoupons /></ProtectedRoute>} />
                                <Route path="/organiser/schedule" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserSchedule /></ProtectedRoute>} />
                                <Route path="/organiser/registration-questions" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserRegistrationQuestions /></ProtectedRoute>} />
                                <Route path="/organiser/profile" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserProfile /></ProtectedRoute>} />
                                <Route path="/organiser/certificates" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserCertificates /></ProtectedRoute>} />
                                <Route path="/organiser/boost" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserBoost /></ProtectedRoute>} />
                                <Route path="/organiser/subscription" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserSubscription /></ProtectedRoute>} />
                                <Route path="/organiser/notifications" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserNotifications /></ProtectedRoute>} />
                            </Route>
                            <Route path="/" element={<Navigate to="/login" replace />} />
                            <Route path="*" element={<NotFound />} />
                        </Routes>
                    </BrowserRouter>
                </AuthProvider>
                <ToastContainer position="top-right" autoClose={3000} hideProgressBar={false} newestOnTop closeOnClick rtl={false} pauseOnFocusLoss draggable pauseOnHover theme="colored" />
            </ThemeProvider>
        </ErrorBoundary>
    );
}

export default App;

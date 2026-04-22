import React from "react";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { ThemeProvider } from "@mui/material/styles";
import CssBaseline from "@mui/material/CssBaseline";
import { ToastContainer } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";

import theme from "./theme";
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
    AdminBoostPackages,
    AdminSubscriptionPlans,
    AdminRevenue,
    AdminSupportRequests,
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
    OrganiserEventChats,
} from "./pages/organiser";

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
                                <Route path="/admin/boost-packages" element={<ProtectedRoute allowedRoles={["ADMIN"]}><AdminBoostPackages /></ProtectedRoute>} />
                                <Route path="/admin/subscription-plans" element={<ProtectedRoute allowedRoles={["ADMIN"]}><AdminSubscriptionPlans /></ProtectedRoute>} />
                                <Route path="/admin/revenue" element={<ProtectedRoute allowedRoles={["ADMIN"]}><AdminRevenue /></ProtectedRoute>} />
                                <Route path="/admin/support-requests" element={<ProtectedRoute allowedRoles={["ADMIN"]}><AdminSupportRequests /></ProtectedRoute>} />
                                <Route path="/organiser/dashboard" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserDashboard /></ProtectedRoute>} />
                                <Route path="/organiser/events" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserEvents /></ProtectedRoute>} />
                                <Route path="/organiser/registrations" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserRegistrations /></ProtectedRoute>} />
                                <Route path="/organiser/questions" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserQuestions /></ProtectedRoute>} />
                                <Route path="/organiser/polls" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserPolls /></ProtectedRoute>} />
                                <Route path="/organiser/funnel" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserFunnelAnalytics /></ProtectedRoute>} />
                                <Route path="/organiser/coupons" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserCoupons /></ProtectedRoute>} />
                                <Route path="/organiser/schedule" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserSchedule /></ProtectedRoute>} />
                                <Route path="/organiser/event-chats" element={<ProtectedRoute allowedRoles={["ORGANISER"]}><OrganiserEventChats /></ProtectedRoute>} />
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
                <ToastContainer
                    position="top-right"
                    autoClose={3000}
                    hideProgressBar={false}
                    newestOnTop
                    closeOnClick
                    pauseOnFocusLoss={false}
                    draggable
                    pauseOnHover={false}
                    limit={3}
                    theme="colored"
                />
            </ThemeProvider>
        </ErrorBoundary>
    );
}

export default App;

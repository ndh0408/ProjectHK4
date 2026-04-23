import api from './axios';

const adminApi = {
    getUsers: (params) => api.get('/admin/users', { params }),
    getUserById: (id) => api.get(`/admin/users/${id}`),
    updateUserStatus: (id, status) => api.put(`/admin/users/${id}/status`, null, { params: { status } }),
    updateUserRole: (id, role) => api.put(`/admin/users/${id}/role`, null, { params: { role } }),
    deleteUser: (id) => api.delete(`/admin/users/${id}`),

    getEvents: (params) => api.get('/admin/events', { params }),
    getPendingEvents: (params) => api.get('/admin/events/pending', { params }),
    getEventById: (id) => api.get(`/admin/events/${id}`),
    approveEvent: (id) => api.post(`/admin/events/${id}/approve`),
    rejectEvent: (id, reason) => api.post(`/admin/events/${id}/reject`, { reason: reason || null }),
    hideEvent: (id) => api.patch(`/admin/events/${id}/hide`),
    unhideEvent: (id) => api.patch(`/admin/events/${id}/unhide`),
    deleteEvent: (id) => api.delete(`/admin/events/${id}`),

    getCategories: () => api.get('/admin/categories'),
    getCategoryById: (id) => api.get(`/admin/categories/${id}`),
    createCategory: (data) => api.post('/admin/categories', data),
    updateCategory: (id, data) => api.put(`/admin/categories/${id}`, data),
    deleteCategory: (id) => api.delete(`/admin/categories/${id}`),

    getCities: () => api.get('/admin/cities'),
    getCityById: (id) => api.get(`/admin/cities/${id}`),
    createCity: (data) => api.post('/admin/cities', data),
    updateCity: (id, data) => api.put(`/admin/cities/${id}`, data),
    deleteCity: (id) => api.delete(`/admin/cities/${id}`),

    getOrganisers: (params) => api.get('/admin/organisers', { params }),
    getOrganiserById: (id) => api.get(`/admin/organisers/${id}`),
    verifyOrganiser: (id) => api.post(`/admin/organisers/${id}/verify`),
    unverifyOrganiser: (id) => api.post(`/admin/organisers/${id}/unverify`),
    updateOrganiserStatus: (id, status) => api.put(`/admin/organisers/${id}/status`, null, { params: { status } }),

    // Supports: { status, isApplication, page, size }
    getVerificationRequests: (params) => api.get('/admin/verification-requests', { params }),
    getVerificationStats: () => api.get('/admin/verification-requests/stats'),
    reviewVerification: (id, data) => api.post(`/admin/verification-requests/${id}/review`, data),

    getNotifications: (params) => api.get('/admin/notifications', { params }),
    getUnreadNotifications: (params) => api.get('/admin/notifications/unread', { params }),
    getUnreadCount: () => api.get('/admin/notifications/unread-count'),
    markAsRead: (id) => api.put(`/admin/notifications/${id}/read`),
    markAllAsRead: () => api.put('/admin/notifications/read-all'),
    broadcastNotification: (data) => api.post('/admin/notifications/broadcast', data),

    getSystemStats: () => api.get('/admin/reports/stats'),
    getUserGrowth: (months) => api.get('/admin/reports/user-growth', { params: { months } }),
    getEventsByCity: () => api.get('/admin/reports/events-by-city'),
    getEventsByCategory: () => api.get('/admin/reports/events-by-category'),

    analyzeEvent: (eventId) => api.post(`/admin/ai/analyze-event/${eventId}`),
    generateRejectionReason: (data) => api.post('/admin/ai/generate-rejection-reason', data),
    generateBroadcastMessage: (data) => api.post('/admin/ai/generate-broadcast-message', data),
    getAIInsights: () => api.get('/admin/ai/dashboard-insights'),

    getBoosts: (params) => api.get('/admin/boosts', { params }),
    getBoostById: (id) => api.get(`/admin/boosts/${id}`),
    getBoostStats: () => api.get('/admin/boosts/stats'),

    getRevenueStats: () => api.get('/admin/revenue/stats'),

    getFunnelAnalytics: () => api.get('/admin/analytics/funnel'),
    getEventFunnel: (eventId) => api.get(`/admin/analytics/funnel/event/${eventId}`),

    // Support requests escalated from the AI assistant
    getSupportRequests: (params) => api.get('/admin/support-requests', { params }),
    getSupportRequestById: (id) => api.get(`/admin/support-requests/${id}`),
    getSupportRequestCounts: () => api.get('/admin/support-requests/counts'),
    updateSupportRequest: (id, payload) => api.patch(`/admin/support-requests/${id}`, payload),

    // Boost package pricing CRUD (admin-editable tier configuration)
    getBoostPackages: () => api.get('/admin/pricing/boost-packages'),
    getBoostPackage: (key) => api.get(`/admin/pricing/boost-packages/${key}`),
    createBoostPackage: (key, payload) => api.post(`/admin/pricing/boost-packages/${key}`, payload),
    updateBoostPackage: (key, payload) => api.put(`/admin/pricing/boost-packages/${key}`, payload),
    deleteBoostPackage: (key) => api.delete(`/admin/pricing/boost-packages/${key}`),

    // Subscription plan pricing CRUD
    getSubscriptionPlans: () => api.get('/admin/pricing/subscription-plans'),
    getSubscriptionPlan: (key) => api.get(`/admin/pricing/subscription-plans/${key}`),
    createSubscriptionPlan: (key, payload) => api.post(`/admin/pricing/subscription-plans/${key}`, payload),
    updateSubscriptionPlan: (key, payload) => api.put(`/admin/pricing/subscription-plans/${key}`, payload),
    deleteSubscriptionPlan: (key) => api.delete(`/admin/pricing/subscription-plans/${key}`),

    // Boost moderation
    forceExpireBoost: (boostId) => api.post(`/admin/boosts/${boostId}/force-expire`),
};

export default adminApi;

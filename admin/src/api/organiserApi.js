import api from './axios';

const organiserApi = {
    getDashboardStats: () => api.get('/organiser/dashboard/stats'),
    getAIInsights: () => api.get('/organiser/dashboard/ai-insights'),

    getProfile: () => api.get('/organiser/profile'),
    updateProfile: (data) => api.put('/organiser/profile', data),
    uploadAvatar: (file) => {
        const formData = new FormData();
        formData.append('file', file);
        return api.post('/organiser/profile/avatar', formData, {
            headers: { 'Content-Type': 'multipart/form-data' },
        });
    },
    uploadSignature: (file) => {
        const formData = new FormData();
        formData.append('file', file);
        return api.post('/organiser/profile/signature', formData, {
            headers: { 'Content-Type': 'multipart/form-data' },
        });
    },

    getMyEvents: (params) => api.get('/organiser/events', { params }),
    getEventById: (id) => api.get(`/organiser/events/${id}`),
    createEvent: (data) => api.post('/organiser/events', data),
    updateEvent: (id, data) => api.put(`/organiser/events/${id}`, data),
    deleteEvent: (id) => api.delete(`/organiser/events/${id}`),
    publishEvent: (id) => api.post(`/organiser/events/${id}/publish`),
    cancelEvent: (id) => api.post(`/organiser/events/${id}/cancel`),
    uploadEventImage: (id, file) => {
        const formData = new FormData();
        formData.append('file', file);
        return api.post(`/organiser/events/${id}/image`, formData, {
            headers: { 'Content-Type': 'multipart/form-data' },
        });
    },

    getEventRegistrations: (eventId, params) => api.get(`/organiser/registrations/event/${eventId}`, { params }),
    getWaitingList: (eventId) => api.get(`/organiser/events/${eventId}/registrations/waiting-list`),
    getRegistrationAnswers: (registrationId) => api.get(`/organiser/registrations/${registrationId}/answers`),
    approveRegistration: (id) => api.put(`/organiser/registrations/${id}/approve`),
    rejectRegistration: (id) => api.put(`/organiser/registrations/${id}/reject`),
    checkInRegistration: (id) => api.put(`/organiser/registrations/${id}/check-in`),
    exportAttendees: (eventId) => api.get(`/organiser/registrations/event/${eventId}/export`, {
        responseType: 'blob',
    }),

    getEventQuestions: (eventId, params) => api.get(`/organiser/questions/event/${eventId}`, { params }),
    getAllQuestions: (params) => api.get('/organiser/questions', { params }),
    getUnansweredQuestions: (params) => api.get('/organiser/questions/unanswered', { params }),
    getAnsweredQuestions: (params) => api.get('/organiser/questions/answered', { params }),
    getQuestionStats: () => api.get('/organiser/questions/stats'),
    answerQuestion: (id, answer) => api.post(`/organiser/questions/${id}/answer`, { answer }),
    getAISuggestion: (questionId) => api.get(`/organiser/questions/${questionId}/ai-suggest`),
    deleteQuestion: (questionId) => api.delete(`/organiser/questions/${questionId}`),

    generateEventDescription: (data) => api.post('/organiser/events/ai/generate-description', data),
    improveEventDescription: (data) => api.post('/organiser/events/ai/improve-description', data),
    generateSpeakerBio: (data) => api.post('/organiser/events/ai/generate-speaker-bio', data),
    generateNotification: (data) => api.post('/organiser/events/ai/generate-notification', data),
    suggestRegistrationQuestions: (data) => api.post('/organiser/events/ai/suggest-questions', data),
    generateFullEvent: (data) => api.post('/organiser/events/ai/generate-event', data),

    getRegistrationQuestions: (eventId) => api.get(`/organiser/events/${eventId}/registration-questions`),
    saveRegistrationQuestions: (eventId, questions) => api.post(`/organiser/events/${eventId}/registration-questions/batch`, questions),
    addRegistrationQuestion: (eventId, question) => api.post(`/organiser/events/${eventId}/registration-questions`, question),
    updateRegistrationQuestion: (eventId, questionId, question) => api.put(`/organiser/events/${eventId}/registration-questions/${questionId}`, question),
    deleteRegistrationQuestion: (eventId, questionId) => api.delete(`/organiser/events/${eventId}/registration-questions/${questionId}`),

    getFollowers: (params) => api.get('/organiser/dashboard/followers', { params }),

    getNotifications: (params) => api.get('/organiser/notifications', { params }),
    getUnreadNotifications: (params) => api.get('/organiser/notifications/unread', { params }),
    getUnreadCount: () => api.get('/organiser/notifications/unread-count'),
    markAsRead: (id) => api.put(`/organiser/notifications/${id}/read`),
    markAllAsRead: () => api.put('/organiser/notifications/read-all'),
    sendToAttendees: (data) => api.post('/organiser/notifications/send-to-attendees', data),
    getRecipientCount: (eventId, notificationType) => api.get('/organiser/notifications/recipient-count', {
        params: { eventId, notificationType }
    }),

    getCertificates: (params) => api.get('/organiser/certificates', { params }),
    getEventCertificates: (eventId, params) => api.get(`/organiser/certificates/event/${eventId}`, { params }),

    generateBio: (data) => api.post('/organiser/profile/ai/generate-bio', data),

    getBoostPackages: () => api.get('/organiser/boosts/packages'),
    createBoost: (data) => api.post('/organiser/boosts', data),
    createBoostCheckout: (data) => api.post('/organiser/boosts/checkout', data),
    activateBoost: (boostId, paymentIntentId) => api.post(`/organiser/boosts/${boostId}/activate`, null, { params: { paymentIntentId } }),
    cancelBoost: (boostId) => api.delete(`/organiser/boosts/${boostId}`),
    getMyBoosts: (params) => api.get('/organiser/boosts', { params }),
    getBoostById: (boostId) => api.get(`/organiser/boosts/${boostId}`),
    checkEventBoosted: (eventId) => api.get(`/organiser/boosts/check/${eventId}`),
    confirmBoostPayment: (boostId, action, existingBoostId) => api.post(`/organiser/boosts/${boostId}/confirm-payment`, null, {
        params: { action, existingBoostId }
    }),
    checkBoostUpgrade: (eventId, packageType) => api.get(`/organiser/boosts/check-upgrade/${eventId}`, { params: { packageType } }),
    extendBoost: (boostId) => api.post(`/organiser/boosts/${boostId}/extend`),
    upgradeBoost: (boostId, newPackage) => api.post(`/organiser/boosts/${boostId}/upgrade`, null, { params: { newPackage } }),

    getSubscriptionPlans: () => api.get('/organiser/subscription/plans'),
    getMySubscription: () => api.get('/organiser/subscription'),
    upgradePlan: (plan) => api.post(`/organiser/subscription/upgrade/${plan}`),
    cancelSubscription: () => api.post('/organiser/subscription/cancel'),
    canCreateEvent: () => api.get('/organiser/subscription/can-create-event'),
    canUseAI: () => api.get('/organiser/subscription/can-use-ai'),
    canGenerateCertificates: () => api.get('/organiser/subscription/can-generate-certificates'),
    canExportExcel: () => api.get('/organiser/subscription/can-export-excel'),
    getBoostDiscount: () => api.get('/organiser/subscription/boost-discount'),
    createSubscriptionCheckout: (plan) => api.post(`/organiser/subscription/checkout/${plan}`),
    confirmSubscriptionPayment: (plan) => api.post(`/organiser/subscription/confirm-payment/${plan}`),

};

export { organiserApi };
export default organiserApi;

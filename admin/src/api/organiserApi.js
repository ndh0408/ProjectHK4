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

    getTicketTypes: (eventId) => api.get(`/organiser/events/${eventId}/ticket-types`),
    getTicketType: (eventId, ticketTypeId) => api.get(`/organiser/events/${eventId}/ticket-types/${ticketTypeId}`),
    createTicketType: (eventId, data) => api.post(`/organiser/events/${eventId}/ticket-types`, data),
    updateTicketType: (eventId, ticketTypeId, data) => api.put(`/organiser/events/${eventId}/ticket-types/${ticketTypeId}`, data),
    deleteTicketType: (eventId, ticketTypeId) => api.delete(`/organiser/events/${eventId}/ticket-types/${ticketTypeId}`),
    toggleTicketTypeVisibility: (eventId, ticketTypeId) => api.patch(`/organiser/events/${eventId}/ticket-types/${ticketTypeId}/toggle-visibility`),
    reorderTicketTypes: (eventId, ticketTypeIds) => api.put(`/organiser/events/${eventId}/ticket-types/reorder`, ticketTypeIds),
    getTicketTypeStats: (eventId) => api.get(`/organiser/events/${eventId}/ticket-types/stats`),
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
    checkInByCode: (eventId, ticketCode) => api.post(`/organiser/registrations/event/${eventId}/check-in-by-code`, null, { params: { ticketCode } }),
    exportAttendees: (eventId) => api.get(`/organiser/registrations/event/${eventId}/export`, {
        responseType: 'blob',
    }),

    getWaitlistOffers: (eventId) => api.get(`/organiser/events/${eventId}/waitlist-offers`),
    getFunnelAnalytics: () => api.get('/organiser/analytics/funnel'),
    getEventFunnel: (eventId) => api.get(`/organiser/analytics/funnel/event/${eventId}`),

    getEventQuestions: (eventId, params) => api.get(`/organiser/questions/event/${eventId}`, { params }),
    getAllQuestions: (params) => api.get('/organiser/questions', { params }),
    getUnansweredQuestions: (params) => api.get('/organiser/questions/unanswered', { params }),
    getAnsweredQuestions: (params) => api.get('/organiser/questions/answered', { params }),
    getQuestionStats: () => api.get('/organiser/questions/stats'),
    answerQuestion: (id, answer) => api.post(`/organiser/questions/${id}/answer`, { answer }),
    getAISuggestion: (questionId) => api.get(`/organiser/questions/${questionId}/ai-suggest`),
    deleteQuestion: (questionId) => api.delete(`/organiser/questions/${questionId}`),

    getEventPolls: (eventId, params) => api.get(`/organiser/polls/event/${eventId}`, { params }),
    createPoll: (eventId, data) => api.post(`/organiser/polls/event/${eventId}`, data),
    updatePoll: (pollId, data) => api.put(`/organiser/polls/${pollId}`, data),
    // Poll State Transitions
    publishPoll: (pollId) => api.post(`/organiser/polls/${pollId}/publish`),
    schedulePoll: (pollId, openAt) => api.post(`/organiser/polls/${pollId}/schedule?openAt=${openAt}`),
    openPoll: (pollId) => api.post(`/organiser/polls/${pollId}/open`),
    closePoll: (pollId) => api.post(`/organiser/polls/${pollId}/close`),
    reopenPoll: (pollId) => api.post(`/organiser/polls/${pollId}/reopen`),
    cancelPoll: (pollId) => api.post(`/organiser/polls/${pollId}/cancel`),
    extendPoll: (pollId, params) => api.post(`/organiser/polls/${pollId}/extend`, null, { params }),
    deletePoll: (pollId) => api.delete(`/organiser/polls/${pollId}`),
    generatePollWithAI: (data) => api.post('/organiser/polls/ai/generate', data),

    getCoupons: (params) => api.get('/organiser/coupons', { params }),
    createCoupon: (data) => api.post('/organiser/coupons', data),
    disableCoupon: (id) => api.post(`/organiser/coupons/${id}/disable`),
    generateCouponAI: (data) => api.post('/organiser/coupons/ai/generate', data),

    createSeatMap: (eventId, zones) => api.post(`/organiser/seat-map/event/${eventId}`, zones),
    getSeatMap: (eventId) => api.get(`/organiser/seat-map/event/${eventId}`),

    getSchedule: (eventId) => api.get(`/organiser/schedule/event/${eventId}`),
    createSession: (eventId, data) => api.post(`/organiser/schedule/event/${eventId}/sessions`, data),
    deleteSession: (sessionId) => api.delete(`/organiser/schedule/sessions/${sessionId}`),

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
    getBoostSubscription: () => api.get('/organiser/boosts/subscription'),
    createSubscriptionCheckout: (plan) => api.post(`/organiser/subscription/checkout/${plan}`),
    confirmSubscriptionPayment: (plan) => api.post(`/organiser/subscription/confirm-payment/${plan}`),

    // Chat Management
    pinMessage: (conversationId, messageId) => api.post(`/organiser/chat/conversations/${conversationId}/messages/${messageId}/pin`),
    unpinMessage: (conversationId) => api.post(`/organiser/chat/conversations/${conversationId}/messages/unpin`),
    banUser: (conversationId, userId) => api.post(`/organiser/chat/conversations/${conversationId}/participants/${userId}/ban`),
    unbanUser: (conversationId, userId) => api.post(`/organiser/chat/conversations/${conversationId}/participants/${userId}/unban`),
    muteUser: (conversationId, userId, mute = true) => api.post(`/organiser/chat/conversations/${conversationId}/participants/${userId}/mute?mute=${mute}`),
    unmuteUser: (conversationId, userId) => api.post(`/organiser/chat/conversations/${conversationId}/participants/${userId}/mute?mute=false`),
    deleteAnyMessage: (messageId) => api.delete(`/organiser/chat/messages/${messageId}`),
    searchChatMessages: (conversationId, query) => api.get(`/organiser/chat/conversations/${conversationId}/search`, { params: { query } }),

};

export { organiserApi };
export default organiserApi;

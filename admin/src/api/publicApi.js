import api from './axios';

const publicApi = {
    getCategories: () => api.get('/categories'),

    getCities: () => api.get('/cities'),

    applyAsOrganiser: (data) => api.post('/public/organiser-application', data),
    uploadOrganiserApplicationDocument: (file) => {
        const formData = new FormData();
        formData.append('file', file);
        return api.post('/public/organiser-application/upload', formData, {
            headers: { 'Content-Type': 'multipart/form-data' },
        });
    },

    // Authenticated endpoint — USER role calls this after login to see app status
    getMyOrganiserApplicationStatus: () => api.get('/user/organiser-application/status'),
};

export default publicApi;

import api from './axios';

const authApi = {
    login: (email, password) => api.post('/auth/login', { email, password }),

    logout: (refreshToken) => api.post('/auth/logout', { refreshToken }),

    refreshToken: (refreshToken) => api.post('/auth/refresh', { refreshToken }),

    getProfile: () => api.get('/user/profile'),

    updateProfile: (data) => api.put('/user/profile', data),

    changePassword: (data) => api.post('/user/profile/change-password', data),
};

export default authApi;

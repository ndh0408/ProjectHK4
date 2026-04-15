import api from './axios';

const publicApi = {
    getCategories: () => api.get('/categories'),

    getCities: () => api.get('/cities'),
};

export default publicApi;

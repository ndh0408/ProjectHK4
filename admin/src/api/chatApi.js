import api from './axios';

const unwrap = (response) => response.data.data;

const chatApi = {
    listEventChats: () => api.get('/user/chat/event-chats').then(unwrap),

    joinEventChat: (eventId) =>
        api.post(`/user/chat/event-chats/${eventId}/join`).then(unwrap),

    getConversation: (conversationId) =>
        api.get(`/user/chat/conversations/${conversationId}`).then(unwrap),

    getMessages: (conversationId, { page = 0, size = 50 } = {}) =>
        api
            .get(`/user/chat/conversations/${conversationId}/messages`, {
                params: { page, size },
            })
            .then(unwrap),

    sendMessage: (conversationId, { content, type = 'TEXT', replyToId } = {}) =>
        api
            .post(`/user/chat/conversations/${conversationId}/messages`, {
                content,
                type,
                ...(replyToId ? { replyToId } : {}),
            })
            .then(unwrap),

    markRead: (conversationId) =>
        api.post(`/user/chat/conversations/${conversationId}/read`).then(unwrap),

    deleteMessage: (messageId) =>
        api.delete(`/user/chat/messages/${messageId}`).then(unwrap),
};

export default chatApi;

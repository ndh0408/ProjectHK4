import React, { createContext, useContext, useState, useEffect, useCallback, useMemo } from 'react';
import { authApi } from '../api';

const AuthContext = createContext(null);

export const useAuth = () => {
    const context = useContext(AuthContext);
    if (!context) {
        throw new Error('useAuth must be used within an AuthProvider');
    }
    return context;
};

export const AuthProvider = ({ children }) => {
    const [user, setUser] = useState(null);
    const [loading, setLoading] = useState(true);

    const logout = useCallback(async () => {
        try {
            const refreshToken = localStorage.getItem('refreshToken');
            if (refreshToken) {
                await authApi.logout(refreshToken);
            }
        } catch (error) {
            console.error('Logout error:', error);
        } finally {
            localStorage.removeItem('accessToken');
            localStorage.removeItem('refreshToken');
            localStorage.removeItem('user');
            setUser(null);
        }
    }, []);

    useEffect(() => {
        let cancelled = false;
        const controller = new AbortController();

        const loadUser = async () => {
            const token = localStorage.getItem('accessToken');
            const savedUser = localStorage.getItem('user');

            if (token && savedUser) {
                try {
                    if (!cancelled) setUser(JSON.parse(savedUser));
                    const response = await authApi.getProfile();
                    if (!cancelled) {
                        const userData = response.data.data;
                        setUser(userData);
                        localStorage.setItem('user', JSON.stringify(userData));
                    }
                } catch (error) {
                    if (!cancelled) {
                        console.error('Failed to load user:', error);
                        logout();
                    }
                }
            }
            if (!cancelled) setLoading(false);
        };

        loadUser();

        return () => {
            cancelled = true;
            controller.abort();
        };
    }, [logout]);

    const login = useCallback(async (email, password) => {
        const response = await authApi.login(email, password);
        const { accessToken, refreshToken, user: userData } = response.data.data;

        if (userData.role !== 'ADMIN' && userData.role !== 'ORGANISER') {
            throw new Error('Access denied. Only Admin and Organiser can access this panel.');
        }

        localStorage.setItem('accessToken', accessToken);
        localStorage.setItem('refreshToken', refreshToken);
        localStorage.setItem('user', JSON.stringify(userData));
        setUser(userData);

        return userData;
    }, []);

    const isAdmin = useCallback(() => user?.role === 'ADMIN', [user]);
    const isOrganiser = useCallback(() => user?.role === 'ORGANISER', [user]);

    const value = useMemo(() => ({
        user,
        loading,
        login,
        logout,
        isAdmin,
        isOrganiser,
        isAuthenticated: !!user,
    }), [user, loading, login, logout, isAdmin, isOrganiser]);

    return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export default AuthContext;

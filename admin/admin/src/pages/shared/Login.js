import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Box, CircularProgress } from '@mui/material';
import {
    Visibility,
    VisibilityOff,
    Email as EmailIcon,
    Lock as LockIcon,
    AutoAwesome as SparkleIcon,
    Event as EventIcon,
    People as PeopleIcon,
    TrendingUp as AnalyticsIcon,
    ErrorOutline as ErrorIcon,
} from '@mui/icons-material';
import { useAuth } from '../../context/AuthContext';

const Login = () => {
    const navigate = useNavigate();
    const { login } = useAuth();

    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [error, setError] = useState('');
    const [fieldErrors, setFieldErrors] = useState({});
    const [loading, setLoading] = useState(false);

    const validateForm = () => {
        const errors = {};

        if (!email.trim()) {
            errors.email = 'Email is required';
        } else {
            const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
            if (!emailPattern.test(email.trim())) {
                errors.email = 'Please enter a valid email address';
            }
        }

        if (!password) {
            errors.password = 'Password is required';
        } else if (password.length < 6) {
            errors.password = 'Password must be at least 6 characters';
        }

        setFieldErrors(errors);
        return Object.keys(errors).length === 0;
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError('');
        setFieldErrors({});

        if (!validateForm()) {
            return;
        }

        setLoading(true);

        try {
            const user = await login(email, password);
            if (user.role === 'ADMIN') {
                navigate('/admin/dashboard', { replace: true });
            } else if (user.role === 'ORGANISER') {
                navigate('/organiser/dashboard', { replace: true });
            } else {
                setError('Access denied. Only Admin and Organiser can access this panel.');
            }
        } catch (err) {
            setError(err.response?.data?.message || err.message || 'Login failed.');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="login-page">
            <div className="login-left">
                <div className="floating-shape shape-1" />
                <div className="floating-shape shape-2" />
                <div className="floating-shape shape-3" />

                <div className="login-left-content">
                    <div className="login-left-logo">
                        <div className="login-left-logo-icon">
                            <SparkleIcon />
                        </div>
                        <h1>LUMA</h1>
                    </div>

                    <h2>
                        Welcome to <span>LUMA</span><br />
                        Event Management
                    </h2>
                    <p>
                        Powerful tools for managing events, registrations, and analytics.
                        Everything you need in one beautiful platform.
                    </p>

                    <div className="login-features">
                        <div className="login-feature">
                            <div className="login-feature-icon">
                                <EventIcon />
                            </div>
                            <div>
                                <h4>Event Management</h4>
                                <p>Create and manage events effortlessly</p>
                            </div>
                        </div>
                        <div className="login-feature">
                            <div className="login-feature-icon pink">
                                <PeopleIcon />
                            </div>
                            <div>
                                <h4>Registration Control</h4>
                                <p>Track attendees and registrations</p>
                            </div>
                        </div>
                        <div className="login-feature">
                            <div className="login-feature-icon green">
                                <AnalyticsIcon />
                            </div>
                            <div>
                                <h4>Real-time Analytics</h4>
                                <p>Insights and reports at your fingertips</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div className="login-right">
                <div className="login-form-container">
                    <div className="login-form-header">
                        <div className="mobile-logo">
                            <div className="mobile-logo-icon">
                                <SparkleIcon />
                            </div>
                            <h1>LUMA</h1>
                        </div>
                        <h2>Welcome Back!</h2>
                        <p>Sign in to access your dashboard</p>
                    </div>

                    <div className="login-form-card">
                        {error && (
                            <div className="login-alert error">
                                <ErrorIcon />
                                <span>{error}</span>
                            </div>
                        )}

                        <form onSubmit={handleSubmit}>
                            <div className={`login-form-group ${fieldErrors.email ? 'has-error' : ''}`}>
                                <label>Email Address</label>
                                <div className={`login-input-wrapper ${fieldErrors.email ? 'error' : ''}`}>
                                    <EmailIcon className="input-icon" />
                                    <input
                                        type="email"
                                        value={email}
                                        onChange={(e) => {
                                            setEmail(e.target.value);
                                            if (fieldErrors.email) {
                                                setFieldErrors({ ...fieldErrors, email: '' });
                                            }
                                        }}
                                        placeholder="Enter your email"
                                        autoFocus
                                    />
                                </div>
                                {fieldErrors.email && (
                                    <span className="field-error">{fieldErrors.email}</span>
                                )}
                            </div>

                            <div className={`login-form-group ${fieldErrors.password ? 'has-error' : ''}`}>
                                <label>Password</label>
                                <div className={`login-input-wrapper ${fieldErrors.password ? 'error' : ''}`}>
                                    <LockIcon className="input-icon" />
                                    <input
                                        type={showPassword ? 'text' : 'password'}
                                        value={password}
                                        onChange={(e) => {
                                            setPassword(e.target.value);
                                            if (fieldErrors.password) {
                                                setFieldErrors({ ...fieldErrors, password: '' });
                                            }
                                        }}
                                        placeholder="Enter your password (min 6 characters)"
                                    />
                                    <button
                                        type="button"
                                        className="toggle-password"
                                        onClick={() => setShowPassword(!showPassword)}
                                    >
                                        {showPassword ? <VisibilityOff /> : <Visibility />}
                                    </button>
                                </div>
                                {fieldErrors.password && (
                                    <span className="field-error">{fieldErrors.password}</span>
                                )}
                            </div>

                            <button type="submit" className="login-submit-btn" disabled={loading}>
                                {loading ? (
                                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                        <CircularProgress size={20} color="inherit" />
                                        <span>Signing in...</span>
                                    </Box>
                                ) : (
                                    'Sign In'
                                )}
                            </button>
                        </form>

                        <div className="login-demo">
                            <h4>Demo Accounts</h4>
                            <div className="login-demo-account">
                                <span className="role-badge admin">Admin</span>
                                <span className="credentials">
                                    <strong>admin@luma.com</strong> / admin123
                                </span>
                            </div>
                            <div className="login-demo-divider">Organiser Accounts</div>
                            <div className="login-demo-account">
                                <span className="role-badge organiser">TechViet</span>
                                <span className="credentials">
                                    <strong>techviet@luma.com</strong> / techviet123
                                </span>
                            </div>
                            <div className="login-demo-account">
                                <span className="role-badge organiser">Sunflower</span>
                                <span className="credentials">
                                    <strong>sunflower@luma.com</strong> / sunflower123
                                </span>
                            </div>
                            <div className="login-demo-account">
                                <span className="role-badge organiser">GreenLife</span>
                                <span className="credentials">
                                    <strong>greenlife@luma.com</strong> / greenlife123
                                </span>
                            </div>
                            <div className="login-demo-account">
                                <span className="role-badge organiser">StartupVN</span>
                                <span className="credentials">
                                    <strong>startupvn@luma.com</strong> / startupvn123
                                </span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default Login;

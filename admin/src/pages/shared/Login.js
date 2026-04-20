import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Box,
    Stack,
    Typography,
    TextField,
    InputAdornment,
    IconButton,
    Alert,
    Divider,
    Chip,
    Paper,
    useMediaQuery,
} from '@mui/material';
import { useTheme } from '@mui/material/styles';
import {
    Visibility,
    VisibilityOff,
    Email as EmailIcon,
    Lock as LockIcon,
    Event as EventIcon,
    People as PeopleIcon,
    TrendingUp as AnalyticsIcon,
    CheckCircleOutline as CheckIcon,
} from '@mui/icons-material';
import { useAuth } from '../../context/AuthContext';
import { LoadingButton } from '../../components/ui';
import { tokens } from '../../theme';
import LumaLogo from '../../components/brand/LumaLogo';

const DEMO_ACCOUNTS = [
    { role: 'Admin', color: 'primary', email: 'admin@luma.com', password: 'admin123' },
    { role: 'TechViet', color: 'secondary', email: 'techviet@luma.com', password: 'techviet123' },
    { role: 'Sunflower', color: 'secondary', email: 'sunflower@luma.com', password: 'sunflower123' },
    { role: 'GreenLife', color: 'secondary', email: 'greenlife@luma.com', password: 'greenlife123' },
    { role: 'StartupVN', color: 'secondary', email: 'startupvn@luma.com', password: 'startupvn123' },
];

const FEATURES = [
    {
        icon: <EventIcon />,
        title: 'Event Management',
        description: 'Create, publish and manage events at scale.',
    },
    {
        icon: <PeopleIcon />,
        title: 'Registration Control',
        description: 'Track attendees, tickets and check-ins in real time.',
    },
    {
        icon: <AnalyticsIcon />,
        title: 'Insights that matter',
        description: 'Revenue, funnel and engagement analytics built-in.',
    },
];

const Login = () => {
    const navigate = useNavigate();
    const { login } = useAuth();
    const theme = useTheme();
    const isMdUp = useMediaQuery(theme.breakpoints.up('md'));

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
        } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
            errors.email = 'Please enter a valid email address';
        }
        if (!password) {
            errors.password = 'Password is required';
        } else if (password.length < 8) {
            errors.password = 'Password must be at least 8 characters';
        }
        setFieldErrors(errors);
        return Object.keys(errors).length === 0;
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError('');
        setFieldErrors({});
        if (!validateForm()) return;

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

    const fillDemo = (account) => {
        setEmail(account.email);
        setPassword(account.password);
        setFieldErrors({});
    };

    return (
        <Box
            sx={{
                minHeight: '100vh',
                display: 'flex',
                bgcolor: 'background.default',
            }}
        >
            {isMdUp && (
                <Box
                    sx={{
                        flex: 1,
                        position: 'relative',
                        overflow: 'hidden',
                        background: tokens.gradient.primary,
                        color: 'common.white',
                        display: 'flex',
                        flexDirection: 'column',
                        justifyContent: 'center',
                        p: { md: 6, lg: 8 },
                    }}
                >
                    <Box
                        sx={{
                            position: 'absolute',
                            top: -80,
                            right: -80,
                            width: 280,
                            height: 280,
                            borderRadius: '50%',
                            bgcolor: 'rgba(255,255,255,0.12)',
                            filter: 'blur(8px)',
                        }}
                    />
                    <Box
                        sx={{
                            position: 'absolute',
                            bottom: -120,
                            left: -80,
                            width: 360,
                            height: 360,
                            borderRadius: '50%',
                            bgcolor: 'rgba(255,255,255,0.08)',
                            filter: 'blur(12px)',
                        }}
                    />
                    <Box sx={{ position: 'relative', maxWidth: 480 }}>
                        <Stack direction="row" alignItems="center" spacing={1.5} sx={{ mb: 6 }}>
                            <LumaLogo size={48} />
                            <Typography variant="h2" sx={{ fontWeight: 700, letterSpacing: '-0.02em' }}>
                                LUMA
                            </Typography>
                        </Stack>

                        <Typography
                            variant="h1"
                            sx={{
                                fontSize: { md: '2.25rem', lg: '2.75rem' },
                                lineHeight: 1.15,
                                fontWeight: 700,
                                mb: 2,
                            }}
                        >
                            Run your events like a premium brand.
                        </Typography>
                        <Typography sx={{ opacity: 0.85, mb: 5, fontSize: '1.0625rem', lineHeight: 1.6 }}>
                            A unified command center for event creation, attendee management,
                            payments and realtime analytics — designed for modern organisers.
                        </Typography>

                        <Stack spacing={2.5}>
                            {FEATURES.map((f) => (
                                <Stack key={f.title} direction="row" spacing={2} alignItems="flex-start">
                                    <Box
                                        sx={{
                                            width: 44,
                                            height: 44,
                                            borderRadius: 2,
                                            display: 'flex',
                                            alignItems: 'center',
                                            justifyContent: 'center',
                                            bgcolor: 'rgba(255,255,255,0.18)',
                                            flexShrink: 0,
                                        }}
                                    >
                                        {f.icon}
                                    </Box>
                                    <Box>
                                        <Typography sx={{ fontWeight: 600, fontSize: '1rem', mb: 0.25 }}>
                                            {f.title}
                                        </Typography>
                                        <Typography sx={{ opacity: 0.8, fontSize: '0.875rem' }}>
                                            {f.description}
                                        </Typography>
                                    </Box>
                                </Stack>
                            ))}
                        </Stack>
                    </Box>
                </Box>
            )}

            <Box
                sx={{
                    flex: { xs: 1, md: 1 },
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    p: { xs: 2.5, sm: 4 },
                    bgcolor: 'background.default',
                    overflowY: 'auto',
                }}
            >
                <Box sx={{ width: '100%', maxWidth: 440 }}>
                    {!isMdUp && (
                        <Stack
                            direction="row"
                            alignItems="center"
                            justifyContent="center"
                            spacing={1}
                            sx={{ mb: 3 }}
                        >
                            <LumaLogo size={36} />
                            <Typography variant="h3">LUMA</Typography>
                        </Stack>
                    )}

                    <Typography variant="h1" sx={{ mb: 0.75 }}>
                        Welcome back
                    </Typography>
                    <Typography variant="body1" color="text.secondary" sx={{ mb: 4 }}>
                        Sign in to manage events, attendees and analytics.
                    </Typography>

                    {error && (
                        <Alert severity="error" sx={{ mb: 2.5 }}>
                            {error}
                        </Alert>
                    )}

                    <Box component="form" onSubmit={handleSubmit} noValidate>
                        <Stack spacing={2.25}>
                            <TextField
                                label="Email address"
                                type="email"
                                value={email}
                                onChange={(e) => {
                                    setEmail(e.target.value);
                                    if (fieldErrors.email) setFieldErrors({ ...fieldErrors, email: '' });
                                }}
                                placeholder="you@company.com"
                                error={Boolean(fieldErrors.email)}
                                helperText={fieldErrors.email || ' '}
                                autoFocus
                                fullWidth
                                InputProps={{
                                    startAdornment: (
                                        <InputAdornment position="start">
                                            <EmailIcon sx={{ fontSize: 18 }} />
                                        </InputAdornment>
                                    ),
                                }}
                            />

                            <TextField
                                label="Password"
                                type={showPassword ? 'text' : 'password'}
                                value={password}
                                onChange={(e) => {
                                    setPassword(e.target.value);
                                    if (fieldErrors.password) setFieldErrors({ ...fieldErrors, password: '' });
                                }}
                                placeholder="At least 8 characters"
                                error={Boolean(fieldErrors.password)}
                                helperText={fieldErrors.password || ' '}
                                fullWidth
                                InputProps={{
                                    startAdornment: (
                                        <InputAdornment position="start">
                                            <LockIcon sx={{ fontSize: 18 }} />
                                        </InputAdornment>
                                    ),
                                    endAdornment: (
                                        <InputAdornment position="end">
                                            <IconButton
                                                edge="end"
                                                size="small"
                                                onClick={() => setShowPassword((s) => !s)}
                                                aria-label={showPassword ? 'Hide password' : 'Show password'}
                                            >
                                                {showPassword ? <VisibilityOff fontSize="small" /> : <Visibility fontSize="small" />}
                                            </IconButton>
                                        </InputAdornment>
                                    ),
                                }}
                            />

                            <LoadingButton
                                type="submit"
                                variant="contained"
                                size="large"
                                loading={loading}
                                fullWidth
                                sx={{ py: 1.5, mt: 0.5 }}
                            >
                                {loading ? 'Signing in...' : 'Sign in'}
                            </LoadingButton>
                        </Stack>
                    </Box>

                    <Divider sx={{ my: 3.5 }}>
                        <Typography variant="caption" color="text.secondary">
                            Quick access — Demo accounts
                        </Typography>
                    </Divider>

                    <Paper
                        variant="outlined"
                        sx={{
                            p: 2,
                            bgcolor: 'grey.50',
                            borderStyle: 'dashed',
                        }}
                    >
                        <Stack spacing={1}>
                            {DEMO_ACCOUNTS.map((account) => (
                                <Box
                                    key={account.email}
                                    onClick={() => fillDemo(account)}
                                    sx={{
                                        display: 'flex',
                                        alignItems: 'center',
                                        gap: 1,
                                        p: 1.25,
                                        borderRadius: 1.5,
                                        bgcolor: 'background.paper',
                                        border: '1px solid',
                                        borderColor: 'divider',
                                        cursor: 'pointer',
                                        transition: 'all 150ms ease',
                                        '&:hover': {
                                            borderColor: 'primary.300',
                                            bgcolor: 'primary.50',
                                        },
                                    }}
                                >
                                    <Chip
                                        size="small"
                                        label={account.role}
                                        color={account.color}
                                        variant={account.color === 'primary' ? 'filled' : 'outlined'}
                                        sx={{ minWidth: 82, fontWeight: 600 }}
                                    />
                                    <Typography variant="caption" sx={{ flex: 1, fontFamily: 'monospace', color: 'text.secondary' }}>
                                        {account.email}
                                    </Typography>
                                    <CheckIcon sx={{ fontSize: 16, color: 'primary.400', opacity: 0.7 }} />
                                </Box>
                            ))}
                        </Stack>
                    </Paper>
                </Box>
            </Box>
        </Box>
    );
};

export default Login;

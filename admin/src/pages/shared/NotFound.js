import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Box, Typography, Button, Stack } from '@mui/material';
import {
    Home as HomeIcon,
    ArrowBack as BackIcon,
    SearchOff as NotFoundIcon,
} from '@mui/icons-material';
import { useAuth } from '../../context/AuthContext';
import { tokens } from '../../theme';

const NotFound = () => {
    const navigate = useNavigate();
    const { user, isAuthenticated } = useAuth();

    const goHome = () => {
        if (!isAuthenticated) {
            navigate('/login', { replace: true });
            return;
        }
        if (user?.role === 'ADMIN') {
            navigate('/admin/dashboard', { replace: true });
        } else if (user?.role === 'ORGANISER') {
            navigate('/organiser/dashboard', { replace: true });
        } else {
            navigate('/login', { replace: true });
        }
    };

    return (
        <Box
            sx={{
                minHeight: '100vh',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                bgcolor: 'background.default',
                p: 3,
            }}
        >
            <Box sx={{ textAlign: 'center', maxWidth: 540 }}>
                <Box
                    sx={{
                        width: 96,
                        height: 96,
                        borderRadius: '50%',
                        bgcolor: 'primary.50',
                        color: 'primary.600',
                        mx: 'auto',
                        mb: 3,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        border: '1px solid',
                        borderColor: 'primary.100',
                    }}
                >
                    <NotFoundIcon sx={{ fontSize: 48 }} />
                </Box>
                <Typography
                    variant="display"
                    component="h1"
                    sx={{
                        fontSize: { xs: '3.5rem', md: '5rem' },
                        fontWeight: 800,
                        mb: 1,
                        lineHeight: 1,
                        background: tokens.gradient.primary,
                        WebkitBackgroundClip: 'text',
                        WebkitTextFillColor: 'transparent',
                    }}
                >
                    404
                </Typography>
                <Typography variant="h2" sx={{ mb: 1.5 }}>
                    Page not found
                </Typography>
                <Typography color="text.secondary" sx={{ mb: 4, fontSize: '1rem' }}>
                    The page you are looking for does not exist, has been moved,
                    or you do not have access to it.
                </Typography>
                <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} justifyContent="center">
                    <Button
                        variant="outlined"
                        startIcon={<BackIcon fontSize="small" />}
                        onClick={() => navigate(-1)}
                        size="large"
                    >
                        Go back
                    </Button>
                    <Button
                        variant="contained"
                        startIcon={<HomeIcon fontSize="small" />}
                        onClick={goHome}
                        size="large"
                    >
                        {isAuthenticated ? 'Go to dashboard' : 'Go to login'}
                    </Button>
                </Stack>
            </Box>
        </Box>
    );
};

export default NotFound;

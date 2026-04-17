import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Box, Typography, Button, Stack } from '@mui/material';
import {
    SentimentDissatisfied as SadIcon,
    Home as HomeIcon,
    ArrowBack as BackIcon,
} from '@mui/icons-material';
import { useAuth } from '../../context/AuthContext';

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
            <Box sx={{ textAlign: 'center', maxWidth: 520 }}>
                <SadIcon sx={{ fontSize: 96, color: 'primary.main', mb: 2 }} />
                <Typography variant="h2" fontWeight={700} color="text.primary" gutterBottom>
                    404
                </Typography>
                <Typography variant="h5" fontWeight={600} gutterBottom>
                    Page not found
                </Typography>
                <Typography color="text.secondary" sx={{ mb: 4 }}>
                    The page you are looking for does not exist, has been moved, or you do not have access to it.
                </Typography>
                <Stack direction="row" spacing={2} justifyContent="center">
                    <Button
                        variant="outlined"
                        startIcon={<BackIcon />}
                        onClick={() => navigate(-1)}
                    >
                        Go back
                    </Button>
                    <Button
                        variant="contained"
                        startIcon={<HomeIcon />}
                        onClick={goHome}
                    >
                        {isAuthenticated ? 'Dashboard' : 'Login'}
                    </Button>
                </Stack>
            </Box>
        </Box>
    );
};

export default NotFound;

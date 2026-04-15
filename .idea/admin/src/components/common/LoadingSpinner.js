import React from 'react';
import { Box, CircularProgress, Typography } from '@mui/material';

const LoadingSpinner = ({ message = 'Loading...' }) => {
    return (
        <Box
            display="flex"
            flexDirection="column"
            justifyContent="center"
            alignItems="center"
            minHeight="200px"
            gap={2}
        >
            <CircularProgress />
            <Typography color="text.secondary">{message}</Typography>
        </Box>
    );
};

export default LoadingSpinner;

import React from 'react';
import { Box, Typography, Button, Stack } from '@mui/material';
import ErrorOutlineIcon from '@mui/icons-material/ErrorOutline';
import RefreshIcon from '@mui/icons-material/Refresh';

const ErrorState = ({
    title = 'Something went wrong',
    description = 'We couldn\u2019t load the data. Please try again in a moment.',
    onRetry,
    retryLabel = 'Try again',
    compact = false,
    sx,
}) => (
    <Stack
        alignItems="center"
        justifyContent="center"
        spacing={1.5}
        sx={{
            py: compact ? 4 : 8,
            px: 3,
            textAlign: 'center',
            ...sx,
        }}
    >
        <Box
            sx={{
                width: 56,
                height: 56,
                borderRadius: '50%',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                bgcolor: 'error.50',
                color: 'error.600',
            }}
        >
            <ErrorOutlineIcon sx={{ fontSize: 28 }} />
        </Box>
        <Box>
            <Typography variant="h3" sx={{ mb: 0.5 }}>
                {title}
            </Typography>
            {description && (
                <Typography variant="body2" color="text.secondary" sx={{ maxWidth: 420 }}>
                    {description}
                </Typography>
            )}
        </Box>
        {onRetry && (
            <Button
                variant="outlined"
                size="small"
                startIcon={<RefreshIcon fontSize="small" />}
                onClick={onRetry}
                sx={{ mt: 0.5 }}
            >
                {retryLabel}
            </Button>
        )}
    </Stack>
);

export default ErrorState;

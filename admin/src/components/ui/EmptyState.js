import React from 'react';
import { Box, Typography, Stack } from '@mui/material';
import InboxOutlinedIcon from '@mui/icons-material/InboxOutlined';

const EmptyState = ({
    icon,
    title = 'No data yet',
    description,
    action,
    compact = false,
    sx,
}) => {
    const IconEl = icon ?? <InboxOutlinedIcon sx={{ fontSize: 32 }} />;
    return (
        <Stack
            alignItems="center"
            justifyContent="center"
            spacing={1.5}
            sx={{
                py: compact ? 4 : 8,
                px: 3,
                textAlign: 'center',
                color: 'text.secondary',
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
                    bgcolor: 'primary.50',
                    color: 'primary.600',
                }}
            >
                {IconEl}
            </Box>
            <Box>
                <Typography variant="h3" color="text.primary" sx={{ mb: 0.5 }}>
                    {title}
                </Typography>
                {description && (
                    <Typography
                        variant="body2"
                        color="text.secondary"
                        sx={{ maxWidth: 420, mx: 'auto' }}
                    >
                        {description}
                    </Typography>
                )}
            </Box>
            {action && <Box sx={{ mt: 1 }}>{action}</Box>}
        </Stack>
    );
};

export default EmptyState;

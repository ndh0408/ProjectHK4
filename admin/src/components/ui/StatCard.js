import React from 'react';
import { Card, CardContent, Box, Typography, Stack, Skeleton } from '@mui/material';
import TrendingUpIcon from '@mui/icons-material/TrendingUp';
import TrendingDownIcon from '@mui/icons-material/TrendingDown';
import TrendingFlatIcon from '@mui/icons-material/TrendingFlat';

/**
 * Dashboard metric card. Supports optional icon, change indicator, helper text.
 */
const StatCard = ({
    label,
    value,
    icon,
    iconColor = 'primary',
    change,
    changeLabel,
    helper,
    loading = false,
    sx,
}) => {
    const parsedChange = typeof change === 'number' ? change : null;
    const isPositive = parsedChange != null && parsedChange > 0;
    const isNegative = parsedChange != null && parsedChange < 0;
    const trendColor = isPositive
        ? 'success.main'
        : isNegative
            ? 'error.main'
            : 'text.secondary';
    const TrendIcon = isPositive
        ? TrendingUpIcon
        : isNegative
            ? TrendingDownIcon
            : TrendingFlatIcon;

    return (
        <Card sx={{ height: '100%', ...sx }}>
            <CardContent sx={{ p: 2.5, '&:last-child': { pb: 2.5 } }}>
                <Stack direction="row" alignItems="flex-start" spacing={2}>
                    <Box sx={{ minWidth: 0, flex: 1 }}>
                        <Typography
                            variant="overline"
                            sx={{
                                color: 'text.secondary',
                                fontWeight: 600,
                                fontSize: '0.6875rem',
                                letterSpacing: '0.06em',
                            }}
                        >
                            {label}
                        </Typography>
                        {loading ? (
                            <Skeleton variant="text" width="60%" height={36} sx={{ mt: 0.5 }} />
                        ) : (
                            <Typography
                                variant="h1"
                                sx={{
                                    fontSize: { xs: '1.5rem', md: '1.75rem' },
                                    fontWeight: 700,
                                    mt: 0.25,
                                    lineHeight: 1.2,
                                }}
                            >
                                {value}
                            </Typography>
                        )}
                        {(parsedChange != null || changeLabel || helper) && (
                            <Stack direction="row" spacing={0.75} alignItems="center" sx={{ mt: 1 }}>
                                {parsedChange != null && (
                                    <>
                                        <TrendIcon sx={{ fontSize: 16, color: trendColor }} />
                                        <Typography
                                            variant="caption"
                                            sx={{ color: trendColor, fontWeight: 600 }}
                                        >
                                            {Math.abs(parsedChange)}%
                                        </Typography>
                                    </>
                                )}
                                {(changeLabel || helper) && (
                                    <Typography variant="caption" color="text.secondary">
                                        {changeLabel || helper}
                                    </Typography>
                                )}
                            </Stack>
                        )}
                    </Box>
                    {icon && (
                        <Box
                            sx={{
                                width: 44,
                                height: 44,
                                borderRadius: 2,
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                bgcolor: `${iconColor}.50`,
                                color: `${iconColor}.600`,
                                flexShrink: 0,
                            }}
                        >
                            {icon}
                        </Box>
                    )}
                </Stack>
            </CardContent>
        </Card>
    );
};

export default StatCard;

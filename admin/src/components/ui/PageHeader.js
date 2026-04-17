import React from 'react';
import { Box, Stack, Typography, Breadcrumbs, Link as MuiLink } from '@mui/material';
import ChevronRightIcon from '@mui/icons-material/ChevronRight';
import { Link as RouterLink } from 'react-router-dom';

/**
 * Standardized page header with optional breadcrumbs, title, subtitle and actions.
 * Drop this at the top of every management page.
 */
const PageHeader = ({
    title,
    subtitle,
    breadcrumbs,
    actions,
    icon,
    sx,
    dense = false,
}) => {
    return (
        <Box
            sx={{
                display: 'flex',
                flexDirection: { xs: 'column', md: 'row' },
                alignItems: { xs: 'stretch', md: 'flex-start' },
                justifyContent: 'space-between',
                gap: { xs: 2, md: 3 },
                mb: dense ? 2.5 : 4,
                ...sx,
            }}
        >
            <Box sx={{ minWidth: 0, flex: 1 }}>
                {breadcrumbs && breadcrumbs.length > 0 && (
                    <Breadcrumbs
                        separator={<ChevronRightIcon sx={{ fontSize: 16 }} />}
                        sx={{ mb: 1, fontSize: '0.8125rem' }}
                    >
                        {breadcrumbs.map((crumb, idx) => {
                            const isLast = idx === breadcrumbs.length - 1;
                            if (isLast || !crumb.to) {
                                return (
                                    <Typography
                                        key={idx}
                                        variant="caption"
                                        color="text.primary"
                                        sx={{ fontWeight: 500 }}
                                    >
                                        {crumb.label}
                                    </Typography>
                                );
                            }
                            return (
                                <MuiLink
                                    key={idx}
                                    component={RouterLink}
                                    to={crumb.to}
                                    underline="hover"
                                    color="text.secondary"
                                    sx={{ fontSize: '0.8125rem' }}
                                >
                                    {crumb.label}
                                </MuiLink>
                            );
                        })}
                    </Breadcrumbs>
                )}
                <Stack direction="row" alignItems="center" spacing={1.5}>
                    {icon && (
                        <Box
                            sx={{
                                display: { xs: 'none', sm: 'flex' },
                                width: 44,
                                height: 44,
                                borderRadius: 2,
                                alignItems: 'center',
                                justifyContent: 'center',
                                bgcolor: 'primary.50',
                                color: 'primary.600',
                                flexShrink: 0,
                            }}
                        >
                            {icon}
                        </Box>
                    )}
                    <Box sx={{ minWidth: 0 }}>
                        <Typography
                            variant="h1"
                            sx={{ fontSize: { xs: '1.375rem', md: '1.5rem' }, fontWeight: 700 }}
                        >
                            {title}
                        </Typography>
                        {subtitle && (
                            <Typography variant="body2" color="text.secondary" sx={{ mt: 0.25 }}>
                                {subtitle}
                            </Typography>
                        )}
                    </Box>
                </Stack>
            </Box>
            {actions && (
                <Stack
                    direction={{ xs: 'column', sm: 'row' }}
                    spacing={1}
                    sx={{ flexShrink: 0, alignSelf: { xs: 'stretch', md: 'flex-start' } }}
                >
                    {actions}
                </Stack>
            )}
        </Box>
    );
};

export default PageHeader;

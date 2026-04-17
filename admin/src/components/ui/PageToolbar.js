import React from 'react';
import { Box, TextField, InputAdornment, Stack } from '@mui/material';
import SearchIcon from '@mui/icons-material/Search';

/**
 * Table / list toolbar: search input + filter slot + actions slot.
 * Visually matches cards above and below, works responsive.
 */
const PageToolbar = ({
    search,
    onSearchChange,
    searchPlaceholder = 'Search...',
    filters,
    actions,
    dense = false,
    sx,
}) => {
    return (
        <Box
            sx={{
                display: 'flex',
                flexDirection: { xs: 'column', md: 'row' },
                alignItems: { xs: 'stretch', md: 'center' },
                gap: 1.5,
                mb: dense ? 1.5 : 2,
                ...sx,
            }}
        >
            {onSearchChange && (
                <TextField
                    size="small"
                    placeholder={searchPlaceholder}
                    value={search ?? ''}
                    onChange={(e) => onSearchChange(e.target.value)}
                    InputProps={{
                        startAdornment: (
                            <InputAdornment position="start">
                                <SearchIcon sx={{ fontSize: 18 }} />
                            </InputAdornment>
                        ),
                    }}
                    sx={{
                        flex: { md: 1 },
                        maxWidth: { md: 360 },
                        bgcolor: 'background.paper',
                    }}
                />
            )}
            {filters && (
                <Stack
                    direction="row"
                    spacing={1}
                    flexWrap="wrap"
                    sx={{ flex: 1, alignItems: 'center', rowGap: 1 }}
                >
                    {filters}
                </Stack>
            )}
            {actions && (
                <Stack
                    direction="row"
                    spacing={1}
                    sx={{ flexShrink: 0, alignSelf: { xs: 'stretch', md: 'center' } }}
                >
                    {actions}
                </Stack>
            )}
        </Box>
    );
};

export default PageToolbar;

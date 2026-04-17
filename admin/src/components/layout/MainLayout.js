import React, { useState } from 'react';
import { Outlet } from 'react-router-dom';
import { Box, Toolbar } from '@mui/material';
import Header from './Header';
import Sidebar from './Sidebar';
import { tokens } from '../../theme';

const DRAWER_WIDTH = tokens.layout.sidebarWidth;

const MainLayout = () => {
    const [mobileOpen, setMobileOpen] = useState(false);
    const handleDrawerToggle = () => setMobileOpen((prev) => !prev);

    return (
        <Box sx={{ display: 'flex', minHeight: '100vh', bgcolor: 'background.default' }}>
            <Header onMenuClick={handleDrawerToggle} />
            <Sidebar open={mobileOpen} onClose={handleDrawerToggle} />
            <Box
                component="main"
                sx={{
                    flexGrow: 1,
                    minWidth: 0,
                    width: { xs: '100%', md: `calc(100% - ${DRAWER_WIDTH}px)` },
                    minHeight: '100vh',
                    bgcolor: 'background.default',
                }}
            >
                <Toolbar sx={{ minHeight: `${tokens.layout.headerHeight}px !important` }} />
                <Box
                    sx={{
                        px: { xs: 2, sm: 3, md: 4 },
                        py: { xs: 2.5, md: 3.5 },
                        maxWidth: tokens.layout.pageMaxWidth,
                        mx: 'auto',
                    }}
                >
                    <Outlet />
                </Box>
            </Box>
        </Box>
    );
};

export default MainLayout;

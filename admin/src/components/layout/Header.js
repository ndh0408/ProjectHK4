import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    AppBar,
    Toolbar,
    IconButton,
    Typography,
    Menu,
    MenuItem,
    Avatar,
    Box,
    Divider,
    ListItemIcon,
    Tooltip,
} from '@mui/material';
import {
    Menu as MenuIcon,
    Logout as LogoutIcon,
    Person as PersonIcon,
    KeyboardArrowDown as ArrowDownIcon,
} from '@mui/icons-material';
import { useAuth } from '../../context/AuthContext';
import NotificationBell from '../common/NotificationBell';
import { tokens } from '../../theme';

const DRAWER_WIDTH = tokens.layout.sidebarWidth;

const Header = ({ onMenuClick }) => {
    const navigate = useNavigate();
    const { user, logout, isAdmin } = useAuth();
    const [anchorEl, setAnchorEl] = useState(null);

    const handleMenu = (event) => setAnchorEl(event.currentTarget);
    const handleClose = () => setAnchorEl(null);

    const handleProfile = () => {
        handleClose();
        if (isAdmin()) return;
        navigate('/organiser/profile');
    };

    const handleLogout = async () => {
        handleClose();
        await logout();
        navigate('/login');
    };

    return (
        <AppBar
            position="fixed"
            color="default"
            elevation={0}
            sx={{
                width: { md: `calc(100% - ${DRAWER_WIDTH}px)` },
                ml: { md: `${DRAWER_WIDTH}px` },
                bgcolor: 'background.paper',
                color: 'text.primary',
                borderBottom: '1px solid',
                borderColor: 'divider',
            }}
        >
            <Toolbar sx={{ minHeight: `${tokens.layout.headerHeight}px !important`, px: { xs: 2, md: 3 } }}>
                <Tooltip title="Toggle menu">
                    <IconButton
                        edge="start"
                        onClick={onMenuClick}
                        sx={{ mr: 1.5, display: { md: 'none' } }}
                    >
                        <MenuIcon />
                    </IconButton>
                </Tooltip>

                <Box sx={{ flex: 1 }} />

                <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                    <NotificationBell />

                    <Box
                        onClick={handleMenu}
                        role="button"
                        aria-label="Account menu"
                        sx={{
                            display: 'flex',
                            alignItems: 'center',
                            gap: 1.25,
                            ml: 0.5,
                            px: { xs: 0.75, md: 1.25 },
                            py: 0.75,
                            borderRadius: 2,
                            cursor: 'pointer',
                            border: '1px solid transparent',
                            transition: 'all 150ms ease',
                            '&:hover': {
                                bgcolor: 'grey.50',
                                borderColor: 'divider',
                            },
                        }}
                    >
                        <Avatar
                            src={user?.avatarUrl}
                            alt={user?.fullName}
                            sx={{
                                width: 34,
                                height: 34,
                                background: tokens.gradient.primary,
                                fontSize: 14,
                                fontWeight: 600,
                            }}
                        >
                            {user?.fullName?.charAt(0)}
                        </Avatar>
                        <Box sx={{ display: { xs: 'none', md: 'block' }, textAlign: 'left', minWidth: 0 }}>
                            <Typography variant="subtitle2" sx={{ lineHeight: 1.25, fontWeight: 600 }} noWrap>
                                {user?.fullName}
                            </Typography>
                            <Typography variant="caption" color="text.secondary" noWrap sx={{ display: 'block' }}>
                                {user?.role === 'ADMIN' ? 'Administrator' : 'Organiser'}
                            </Typography>
                        </Box>
                        <ArrowDownIcon
                            sx={{
                                fontSize: 16,
                                color: 'text.secondary',
                                display: { xs: 'none', md: 'block' },
                            }}
                        />
                    </Box>

                    <Menu
                        anchorEl={anchorEl}
                        open={Boolean(anchorEl)}
                        onClose={handleClose}
                        transformOrigin={{ horizontal: 'right', vertical: 'top' }}
                        anchorOrigin={{ horizontal: 'right', vertical: 'bottom' }}
                        PaperProps={{
                            sx: { mt: 1, minWidth: 240 },
                        }}
                    >
                        <Box sx={{ px: 2, py: 1.25 }}>
                            <Typography variant="subtitle2" fontWeight={600}>
                                {user?.fullName}
                            </Typography>
                            <Typography variant="caption" color="text.secondary" sx={{ wordBreak: 'break-all' }}>
                                {user?.email}
                            </Typography>
                        </Box>
                        <Divider />
                        {!isAdmin() && (
                            <MenuItem onClick={handleProfile}>
                                <ListItemIcon>
                                    <PersonIcon fontSize="small" />
                                </ListItemIcon>
                                Profile
                            </MenuItem>
                        )}
                        <MenuItem
                            onClick={handleLogout}
                            sx={{
                                color: 'error.main',
                                '&:hover': { bgcolor: 'error.50' },
                            }}
                        >
                            <ListItemIcon>
                                <LogoutIcon fontSize="small" color="error" />
                            </ListItemIcon>
                            Sign out
                        </MenuItem>
                    </Menu>
                </Box>
            </Toolbar>
        </AppBar>
    );
};

export default Header;

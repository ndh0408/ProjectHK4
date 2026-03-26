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
} from '@mui/material';
import {
    Menu as MenuIcon,
    Logout as LogoutIcon,
    Person as PersonIcon,
} from '@mui/icons-material';
import { useAuth } from '../../context/AuthContext';
import NotificationBell from '../common/NotificationBell';

const DRAWER_WIDTH = 280;

const Header = ({ onMenuClick }) => {
    const navigate = useNavigate();
    const { user, logout, isAdmin } = useAuth();
    const [anchorEl, setAnchorEl] = useState(null);

    const handleMenu = (event) => {
        setAnchorEl(event.currentTarget);
    };

    const handleClose = () => {
        setAnchorEl(null);
    };

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
            elevation={0}
            sx={{
                width: { sm: `calc(100% - ${DRAWER_WIDTH}px)` },
                ml: { sm: `${DRAWER_WIDTH}px` },
                bgcolor: 'background.paper',
                color: 'text.primary',
                borderBottom: '1px solid',
                borderColor: 'grey.200',
            }}
        >
            <Toolbar sx={{ minHeight: '70px !important' }}>
                <IconButton
                    color="inherit"
                    edge="start"
                    onClick={onMenuClick}
                    sx={{ mr: 2, display: { sm: 'none' } }}
                >
                    <MenuIcon />
                </IconButton>

                <Box sx={{ flexGrow: 1 }} />

                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <NotificationBell />

                    <Box
                        onClick={handleMenu}
                        sx={{
                            display: 'flex',
                            alignItems: 'center',
                            gap: 1.5,
                            ml: 1,
                            px: 1.5,
                            py: 0.75,
                            borderRadius: 2,
                            cursor: 'pointer',
                            transition: 'all 0.2s',
                            '&:hover': { bgcolor: 'grey.100' },
                        }}
                    >
                        <Avatar
                            src={user?.avatarUrl}
                            alt={user?.fullName}
                            sx={{
                                width: 40,
                                height: 40,
                                background: 'linear-gradient(135deg, #6366f1 0%, #ec4899 100%)',
                                fontWeight: 600,
                            }}
                        >
                            {user?.fullName?.charAt(0)}
                        </Avatar>
                        <Box sx={{ display: { xs: 'none', md: 'block' }, textAlign: 'left' }}>
                            <Typography variant="subtitle2" fontWeight="600" sx={{ lineHeight: 1.3 }}>
                                {user?.fullName}
                            </Typography>
                            <Typography variant="caption" color="text.secondary">
                                {user?.role}
                            </Typography>
                        </Box>
                    </Box>

                    <Menu
                        anchorEl={anchorEl}
                        open={Boolean(anchorEl)}
                        onClose={handleClose}
                        transformOrigin={{ horizontal: 'right', vertical: 'top' }}
                        anchorOrigin={{ horizontal: 'right', vertical: 'bottom' }}
                        PaperProps={{
                            sx: {
                                mt: 1,
                                minWidth: 220,
                                boxShadow: '0 10px 40px rgba(0,0,0,0.15)',
                                borderRadius: 3,
                            },
                        }}
                    >
                        <Box sx={{ px: 2, py: 1.5 }}>
                            <Typography variant="subtitle2" fontWeight="600">
                                {user?.fullName}
                            </Typography>
                            <Typography variant="caption" color="text.secondary">
                                {user?.email}
                            </Typography>
                        </Box>
                        <Divider />
                        {!isAdmin() && (
                            <MenuItem onClick={handleProfile} sx={{ py: 1.5 }}>
                                <ListItemIcon>
                                    <PersonIcon fontSize="small" />
                                </ListItemIcon>
                                Profile
                            </MenuItem>
                        )}
                        <MenuItem
                            onClick={handleLogout}
                            sx={{
                                py: 1.5,
                                color: 'error.main',
                                '&:hover': { bgcolor: 'error.50' },
                            }}
                        >
                            <ListItemIcon>
                                <LogoutIcon fontSize="small" color="error" />
                            </ListItemIcon>
                            Logout
                        </MenuItem>
                    </Menu>
                </Box>
            </Toolbar>
        </AppBar>
    );
};

export default Header;

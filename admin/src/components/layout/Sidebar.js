import React, { useMemo } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import {
    Drawer,
    Box,
    Stack,
    Typography,
    List,
    ListItemButton,
    ListItemIcon,
    ListItemText,
    Avatar,
    Divider,
} from '@mui/material';
import {
    Dashboard as DashboardIcon,
    Event as EventIcon,
    Category as CategoryIcon,
    LocationCity as CityIcon,
    Notifications as NotificationsIcon,
    Business as BusinessIcon,
    HowToReg as RegistrationsIcon,
    QuestionAnswer as QuestionsIcon,
    Quiz as QuizIcon,
    Poll as PollIcon,
    FilterAlt as FunnelIcon,
    LocalOffer as CouponIcon,
    CalendarMonth as ScheduleIcon,
    Person as ProfileIcon,
    WorkspacePremium as CertificateIcon,
    Rocket as BoostIcon,
    CardMembership as SubscriptionIcon,
    AttachMoney as RevenueIcon,
    Groups as UsersIcon,
} from '@mui/icons-material';
import { useAuth } from '../../context/AuthContext';
import { tokens } from '../../theme';
import LumaLogo from '../brand/LumaLogo';

const DRAWER_WIDTH = tokens.layout.sidebarWidth;

const adminGroups = [
    {
        label: 'Overview',
        items: [
            { text: 'Dashboard', icon: <DashboardIcon />, path: '/admin/dashboard' },
            { text: 'Revenue', icon: <RevenueIcon />, path: '/admin/revenue' },
        ],
    },
    {
        label: 'People',
        items: [
            { text: 'Users', icon: <UsersIcon />, path: '/admin/users' },
            { text: 'Organisers', icon: <BusinessIcon />, path: '/admin/organisers' },
        ],
    },
    {
        label: 'Catalog',
        items: [
            { text: 'Events', icon: <EventIcon />, path: '/admin/events' },
            { text: 'Boosts', icon: <BoostIcon />, path: '/admin/boosts' },
            { text: 'Categories', icon: <CategoryIcon />, path: '/admin/categories' },
            { text: 'Cities', icon: <CityIcon />, path: '/admin/cities' },
        ],
    },
    {
        label: 'Engagement',
        items: [
            { text: 'Notifications', icon: <NotificationsIcon />, path: '/admin/notifications' },
        ],
    },
];

const organiserGroups = [
    {
        label: 'Overview',
        items: [
            { text: 'Dashboard', icon: <DashboardIcon />, path: '/organiser/dashboard' },
            { text: 'My Events', icon: <EventIcon />, path: '/organiser/events' },
            { text: 'Schedule', icon: <ScheduleIcon />, path: '/organiser/schedule' },
        ],
    },
    {
        label: 'Attendees',
        items: [
            { text: 'Registrations', icon: <RegistrationsIcon />, path: '/organiser/registrations' },
            { text: 'Registration Form', icon: <QuizIcon />, path: '/organiser/registration-questions' },
            { text: 'Questions', icon: <QuestionsIcon />, path: '/organiser/questions' },
            { text: 'Live Polls', icon: <PollIcon />, path: '/organiser/polls' },
        ],
    },
    {
        label: 'Growth',
        items: [
            { text: 'Funnel Analytics', icon: <FunnelIcon />, path: '/organiser/funnel' },
            { text: 'Coupons', icon: <CouponIcon />, path: '/organiser/coupons' },
            { text: 'Boost', icon: <BoostIcon />, path: '/organiser/boost' },
        ],
    },
    {
        label: 'Account',
        items: [
            { text: 'Certificates', icon: <CertificateIcon />, path: '/organiser/certificates' },
            { text: 'Subscription', icon: <SubscriptionIcon />, path: '/organiser/subscription' },
            { text: 'Notifications', icon: <NotificationsIcon />, path: '/organiser/notifications' },
            { text: 'Profile', icon: <ProfileIcon />, path: '/organiser/profile' },
        ],
    },
];

const Sidebar = ({ open, onClose }) => {
    const navigate = useNavigate();
    const location = useLocation();
    const { isAdmin, user } = useAuth();

    const groups = useMemo(
        () => (isAdmin() ? adminGroups : organiserGroups),
        [isAdmin],
    );

    const handleNavigation = (path) => {
        navigate(path);
        if (onClose) onClose();
    };

    const drawerContent = (
        <Box
            sx={{
                height: '100%',
                display: 'flex',
                flexDirection: 'column',
                bgcolor: 'background.paper',
                borderRight: '1px solid',
                borderColor: 'divider',
            }}
        >
            <Stack
                direction="row"
                alignItems="center"
                spacing={1.5}
                sx={{
                    px: 2.5,
                    height: tokens.layout.headerHeight,
                    borderBottom: '1px solid',
                    borderColor: 'divider',
                    flexShrink: 0,
                }}
            >
                <LumaLogo size={36} />
                <Box sx={{ minWidth: 0 }}>
                    <Typography variant="h4" sx={{ letterSpacing: '-0.01em', lineHeight: 1.1 }}>
                        LUMA
                    </Typography>
                    <Typography variant="caption" color="text.secondary" sx={{ lineHeight: 1 }}>
                        {isAdmin() ? 'Admin Portal' : 'Organiser Portal'}
                    </Typography>
                </Box>
            </Stack>

            <Box
                sx={{
                    mx: 2,
                    mt: 2,
                    p: 1.5,
                    display: 'flex',
                    alignItems: 'center',
                    gap: 1.25,
                    borderRadius: 2,
                    bgcolor: 'grey.50',
                    border: '1px solid',
                    borderColor: 'divider',
                }}
            >
                <Avatar
                    src={user?.avatarUrl}
                    sx={{
                        width: 36,
                        height: 36,
                        background: tokens.gradient.primary,
                        fontSize: 14,
                    }}
                >
                    {user?.fullName?.charAt(0) || 'U'}
                </Avatar>
                <Box sx={{ minWidth: 0, flex: 1 }}>
                    <Typography variant="subtitle2" noWrap sx={{ fontWeight: 600 }}>
                        {user?.fullName}
                    </Typography>
                    <Typography variant="caption" color="text.secondary" noWrap sx={{ display: 'block' }}>
                        {user?.email}
                    </Typography>
                </Box>
            </Box>

            <Box sx={{ flex: 1, overflowY: 'auto', px: 1.5, py: 2 }}>
                {groups.map((group, idx) => (
                    <Box key={group.label} sx={{ mb: idx === groups.length - 1 ? 0 : 2 }}>
                        <Typography
                            variant="overline"
                            sx={{
                                px: 1.5,
                                color: 'text.secondary',
                                fontSize: '0.6875rem',
                                fontWeight: 600,
                                letterSpacing: '0.08em',
                            }}
                        >
                            {group.label}
                        </Typography>
                        <List dense disablePadding sx={{ mt: 0.5 }}>
                            {group.items.map((item) => {
                                const isActive = location.pathname === item.path
                                    || (item.path !== '/' && location.pathname.startsWith(item.path + '/'));
                                return (
                                    <ListItemButton
                                        key={item.text}
                                        onClick={() => handleNavigation(item.path)}
                                        selected={isActive}
                                        sx={{
                                            px: 1.5,
                                            py: 1,
                                            mx: 0,
                                            borderRadius: 2,
                                            mb: 0.25,
                                            color: 'text.secondary',
                                            '& .MuiListItemIcon-root': {
                                                minWidth: 0,
                                                mr: 1.5,
                                                color: 'inherit',
                                            },
                                            '&:hover': { bgcolor: 'grey.100' },
                                            '&.Mui-selected': {
                                                bgcolor: 'primary.50',
                                                color: 'primary.700',
                                                fontWeight: 600,
                                                '&:hover': { bgcolor: 'primary.100' },
                                            },
                                        }}
                                    >
                                        <ListItemIcon>
                                            {React.cloneElement(item.icon, { sx: { fontSize: 20 } })}
                                        </ListItemIcon>
                                        <ListItemText
                                            primary={item.text}
                                            primaryTypographyProps={{
                                                fontSize: '0.875rem',
                                                fontWeight: isActive ? 600 : 500,
                                            }}
                                        />
                                    </ListItemButton>
                                );
                            })}
                        </List>
                    </Box>
                ))}
            </Box>

            <Divider />
            <Box sx={{ p: 2 }}>
                <Typography
                    variant="caption"
                    color="text.secondary"
                    sx={{ display: 'block', textAlign: 'center' }}
                >
                    LUMA Event Management
                </Typography>
                <Typography
                    variant="caption"
                    color="text.secondary"
                    sx={{ display: 'block', textAlign: 'center', opacity: 0.6 }}
                >
                    v1.0.0
                </Typography>
            </Box>
        </Box>
    );

    return (
        <Box
            component="nav"
            sx={{ width: { md: DRAWER_WIDTH }, flexShrink: { md: 0 } }}
        >
            <Drawer
                variant="temporary"
                open={open}
                onClose={onClose}
                ModalProps={{ keepMounted: true }}
                sx={{
                    display: { xs: 'block', md: 'none' },
                    '& .MuiDrawer-paper': {
                        boxSizing: 'border-box',
                        width: DRAWER_WIDTH,
                    },
                }}
            >
                {drawerContent}
            </Drawer>
            <Drawer
                variant="permanent"
                sx={{
                    display: { xs: 'none', md: 'block' },
                    '& .MuiDrawer-paper': {
                        boxSizing: 'border-box',
                        width: DRAWER_WIDTH,
                    },
                }}
                open
            >
                {drawerContent}
            </Drawer>
        </Box>
    );
};

export default Sidebar;

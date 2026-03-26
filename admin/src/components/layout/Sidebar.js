import React from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { Drawer, Box } from '@mui/material';
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
    Person as ProfileIcon,
    AutoAwesome as SparkleIcon,
    WorkspacePremium as CertificateIcon,
    Rocket as BoostIcon,
    CardMembership as SubscriptionIcon,
    AttachMoney as RevenueIcon,
} from '@mui/icons-material';
import { useAuth } from '../../context/AuthContext';

const DRAWER_WIDTH = 280;

const adminMenuItems = [
    { text: 'Dashboard', icon: <DashboardIcon />, path: '/admin/dashboard' },
    { text: 'Revenue', icon: <RevenueIcon />, path: '/admin/revenue' },
    { text: 'Organisers', icon: <BusinessIcon />, path: '/admin/organisers' },
    { text: 'Events', icon: <EventIcon />, path: '/admin/events' },
    { text: 'Boosts', icon: <BoostIcon />, path: '/admin/boosts' },
    { text: 'Categories', icon: <CategoryIcon />, path: '/admin/categories' },
    { text: 'Cities', icon: <CityIcon />, path: '/admin/cities' },
    { text: 'Notifications', icon: <NotificationsIcon />, path: '/admin/notifications' },
];

const organiserMenuItems = [
    { text: 'Dashboard', icon: <DashboardIcon />, path: '/organiser/dashboard' },
    { text: 'My Events', icon: <EventIcon />, path: '/organiser/events' },
    { text: 'Registrations', icon: <RegistrationsIcon />, path: '/organiser/registrations' },
    { text: 'Registration Form', icon: <QuizIcon />, path: '/organiser/registration-questions' },
    { text: 'Questions', icon: <QuestionsIcon />, path: '/organiser/questions' },
    { text: 'Certificates', icon: <CertificateIcon />, path: '/organiser/certificates' },
    { text: 'Boost', icon: <BoostIcon />, path: '/organiser/boost' },
    { text: 'Subscription', icon: <SubscriptionIcon />, path: '/organiser/subscription' },
    { text: 'Notifications', icon: <NotificationsIcon />, path: '/organiser/notifications' },
    { text: 'Profile', icon: <ProfileIcon />, path: '/organiser/profile' },
];

const Sidebar = ({ open, onClose }) => {
    const navigate = useNavigate();
    const location = useLocation();
    const { isAdmin, user } = useAuth();

    const menuItems = isAdmin() ? adminMenuItems : organiserMenuItems;

    const handleNavigation = (path) => {
        navigate(path);
        if (onClose) onClose();
    };

    const drawer = (
        <div className="sidebar">
            <div className="sidebar-logo">
                <div className="sidebar-logo-icon">
                    <SparkleIcon />
                </div>
                <div className="sidebar-logo-text">
                    <h1>LUMA</h1>
                    <span>{isAdmin() ? 'Admin Portal' : 'Organiser Portal'}</span>
                </div>
            </div>

            <div className="sidebar-user-card">
                <div className="sidebar-user-avatar">
                    {user?.fullName?.charAt(0) || 'U'}
                </div>
                <div className="sidebar-user-info">
                    <div className="sidebar-user-name">{user?.fullName}</div>
                    <div className="sidebar-user-email">{user?.email}</div>
                </div>
            </div>

            <div className="sidebar-menu-container">
                <div className="sidebar-menu-label">Main Menu</div>

                <ul className="sidebar-menu">
                    {menuItems.map((item) => {
                        const isActive = location.pathname === item.path;
                        return (
                            <li key={item.text} className="sidebar-menu-item">
                                <button
                                    className={"sidebar-menu-link " + (isActive ? "active" : "")}
                                    onClick={() => handleNavigation(item.path)}
                                >
                                    {item.icon}
                                    <span>{item.text}</span>
                                    {isActive && <div className="active-indicator" />}
                                </button>
                            </li>
                        );
                    })}
                </ul>
            </div>

            <div className="sidebar-footer">
                <div className="sidebar-footer-card">
                    <p>LUMA Event Management</p>
                    <span>v1.0.0</span>
                </div>
            </div>
        </div>
    );

    return (
        <Box component="nav" sx={{ width: { sm: DRAWER_WIDTH }, flexShrink: { sm: 0 } }}>
            <Drawer
                variant="temporary"
                open={open}
                onClose={onClose}
                ModalProps={{ keepMounted: true }}
                sx={{
                    display: { xs: 'block', sm: 'none' },
                    '& .MuiDrawer-paper': { boxSizing: 'border-box', width: DRAWER_WIDTH, border: 'none' },
                }}
            >
                {drawer}
            </Drawer>
            <Drawer
                variant="permanent"
                sx={{
                    display: { xs: 'none', sm: 'block' },
                    '& .MuiDrawer-paper': { boxSizing: 'border-box', width: DRAWER_WIDTH, border: 'none' },
                }}
                open
            >
                {drawer}
            </Drawer>
        </Box>
    );
};

export default Sidebar;

import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    IconButton,
    Badge,
    Menu,
    Box,
    Typography,
    List,
    ListItem,
    ListItemText,
    ListItemIcon,
    Button,
    Divider,
    CircularProgress,
    Tooltip,
} from '@mui/material';
import {
    Notifications as NotificationsIcon,
    Event as EventIcon,
    CheckCircle as ApprovedIcon,
    Cancel as RejectedIcon,
    Info as InfoIcon,
    Campaign as BroadcastIcon,
    DoneAll as MarkReadIcon,
    MarkEmailRead as ReadIcon,
} from '@mui/icons-material';
import { formatDistanceToNow } from 'date-fns';
import adminApi from '../../api/adminApi';
import organiserApi from '../../api/organiserApi';
import { useAuth } from '../../context/AuthContext';

const NotificationBell = () => {
    const navigate = useNavigate();
    const { isAdmin } = useAuth();
    const [anchorEl, setAnchorEl] = useState(null);
    const [notifications, setNotifications] = useState([]);
    const [unreadCount, setUnreadCount] = useState(0);
    const [loading, setLoading] = useState(false);

    const api = isAdmin() ? adminApi : organiserApi;

    const fetchUnreadCount = useCallback(async () => {
        try {
            const response = await api.getUnreadCount();
            setUnreadCount(response.data.data.count);
        } catch (error) {
            console.error('Failed to fetch unread count:', error);
        }
    }, [api]);

    const fetchNotifications = useCallback(async () => {
        setLoading(true);
        try {
            const response = await api.getUnreadNotifications({ page: 0, size: 10 });
            const content = response.data.data.content || [];
            setNotifications(content);
            if (content.length > 0) {
                setUnreadCount(prev => Math.max(prev, content.length));
            }
        } catch (error) {
            console.error('Failed to fetch notifications:', error);
        } finally {
            setLoading(false);
        }
    }, [api]);

    useEffect(() => {
        fetchUnreadCount();
        const interval = setInterval(fetchUnreadCount, 30000);
        return () => clearInterval(interval);
    }, [fetchUnreadCount]);

    const handleClick = (event) => {
        setAnchorEl(event.currentTarget);
        fetchNotifications();
        fetchUnreadCount();
    };

    const handleClose = () => {
        setAnchorEl(null);
    };

    const handleMarkAsRead = async (id, event) => {
        event.stopPropagation();
        try {
            await api.markAsRead(id);
            setNotifications(prev => prev.filter(n => n.id !== id));
            setUnreadCount(prev => Math.max(0, prev - 1));
        } catch (error) {
            console.error('Failed to mark as read:', error);
        }
    };

    const handleMarkAllAsRead = async () => {
        try {
            await api.markAllAsRead();
            setNotifications([]);
            setUnreadCount(0);
        } catch (error) {
            console.error('Failed to mark all as read:', error);
        }
    };

    const handleNotificationClick = async (notification) => {
        try {
            await api.markAsRead(notification.id);
            setNotifications(prev => prev.filter(n => n.id !== notification.id));
            setUnreadCount(prev => Math.max(0, prev - 1));
        } catch (error) {
            console.error('Failed to mark as read:', error);
        }

        handleClose();

        if (notification.referenceId && notification.referenceType === 'EVENT') {
            if (isAdmin()) {
                navigate(`/admin/events`);
            } else {
                navigate(`/organiser/events`);
            }
        }
    };

    const handleViewAll = () => {
        handleClose();
        if (isAdmin()) {
            navigate('/admin/notifications');
        } else {
            navigate('/organiser/notifications');
        }
    };

    const getNotificationIcon = (type) => {
        switch (type) {
            case 'EVENT_CREATED':
                return <EventIcon sx={{ color: 'info.main' }} />;
            case 'EVENT_APPROVED':
                return <ApprovedIcon sx={{ color: 'success.main' }} />;
            case 'EVENT_REJECTED':
                return <RejectedIcon sx={{ color: 'error.main' }} />;
            case 'BROADCAST':
                return <BroadcastIcon sx={{ color: 'primary.main' }} />;
            default:
                return <InfoIcon sx={{ color: 'grey.500' }} />;
        }
    };

    const formatTime = (dateString) => {
        try {
            return formatDistanceToNow(new Date(dateString), { addSuffix: true });
        } catch {
            return '';
        }
    };

    return (
        <>
            <Tooltip title="Notifications">
                <IconButton
                    onClick={handleClick}
                    sx={{
                        bgcolor: 'grey.100',
                        '&:hover': { bgcolor: 'grey.200' },
                    }}
                >
                    <Badge
                        badgeContent={unreadCount}
                        color="error"
                        max={99}
                    >
                        <NotificationsIcon sx={{ color: 'grey.600' }} />
                    </Badge>
                </IconButton>
            </Tooltip>

            <Menu
                anchorEl={anchorEl}
                open={Boolean(anchorEl)}
                onClose={handleClose}
                transformOrigin={{ horizontal: 'right', vertical: 'top' }}
                anchorOrigin={{ horizontal: 'right', vertical: 'bottom' }}
                PaperProps={{
                    sx: {
                        mt: 1,
                        width: { xs: '100vw', sm: 380 },
                        maxWidth: '100%',
                        maxHeight: 500,
                        boxShadow: '0 10px 40px rgba(0,0,0,0.15)',
                        borderRadius: 3,
                    },
                }}
            >
                <Box sx={{
                    px: 2,
                    py: 1.5,
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                    borderBottom: '1px solid',
                    borderColor: 'grey.200',
                }}>
                    <Typography variant="subtitle1" fontWeight="600">
                        Notifications
                    </Typography>
                    {(unreadCount > 0 || notifications.some(n => !n.isRead)) && (
                        <Button
                            size="small"
                            startIcon={<MarkReadIcon />}
                            onClick={handleMarkAllAsRead}
                            sx={{ textTransform: 'none' }}
                        >
                            Mark all as read
                        </Button>
                    )}
                </Box>

                {loading ? (
                    <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
                        <CircularProgress size={32} />
                    </Box>
                ) : notifications.length === 0 ? (
                    <Box sx={{ py: 4, textAlign: 'center' }}>
                        <NotificationsIcon sx={{ fontSize: 48, color: 'grey.300', mb: 1 }} />
                        <Typography color="text.secondary">
                            No unread notifications
                        </Typography>
                    </Box>
                ) : (
                    <List sx={{ py: 0, maxHeight: 350, overflow: 'auto' }}>
                        {notifications.map((notification, index) => (
                            <React.Fragment key={notification.id}>
                                <ListItem
                                    onClick={() => handleNotificationClick(notification)}
                                    sx={{
                                        py: 1.5,
                                        px: 2,
                                        pr: 6,
                                        cursor: 'pointer',
                                        bgcolor: 'action.hover',
                                        '&:hover': { bgcolor: 'grey.100' },
                                        position: 'relative',
                                    }}
                                >
                                    <ListItemIcon sx={{ minWidth: 40 }}>
                                        {getNotificationIcon(notification.type)}
                                    </ListItemIcon>
                                    <ListItemText
                                        primary={
                                            <Typography
                                                variant="body2"
                                                component="span"
                                                fontWeight={600}
                                                sx={{
                                                    overflow: 'hidden',
                                                    textOverflow: 'ellipsis',
                                                    display: '-webkit-box',
                                                    WebkitLineClamp: 1,
                                                    WebkitBoxOrient: 'vertical',
                                                }}
                                            >
                                                {notification.title}
                                            </Typography>
                                        }
                                        secondary={
                                            <Box component="span" sx={{ display: 'block' }}>
                                                <Typography
                                                    variant="caption"
                                                    component="span"
                                                    color="text.secondary"
                                                    sx={{
                                                        overflow: 'hidden',
                                                        textOverflow: 'ellipsis',
                                                        display: '-webkit-box',
                                                        WebkitLineClamp: 2,
                                                        WebkitBoxOrient: 'vertical',
                                                    }}
                                                >
                                                    {notification.message}
                                                </Typography>
                                                <Typography
                                                    variant="caption"
                                                    component="span"
                                                    color="text.disabled"
                                                    sx={{ display: 'block', mt: 0.5 }}
                                                >
                                                    {formatTime(notification.createdAt)}
                                                </Typography>
                                            </Box>
                                        }
                                    />
                                    <Tooltip title="Mark as read">
                                        <IconButton
                                            size="small"
                                            onClick={(e) => handleMarkAsRead(notification.id, e)}
                                            sx={{
                                                position: 'absolute',
                                                right: 8,
                                                top: '50%',
                                                transform: 'translateY(-50%)',
                                            }}
                                        >
                                            <ReadIcon fontSize="small" />
                                        </IconButton>
                                    </Tooltip>
                                </ListItem>
                                {index < notifications.length - 1 && <Divider />}
                            </React.Fragment>
                        ))}
                    </List>
                )}

                <Divider />
                <Box sx={{ p: 1 }}>
                    <Button
                        fullWidth
                        onClick={handleViewAll}
                        sx={{ textTransform: 'none' }}
                    >
                        View all notifications
                    </Button>
                </Box>
            </Menu>
        </>
    );
};

export default NotificationBell;

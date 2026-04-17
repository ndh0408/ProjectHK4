import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Typography,
    Paper,
    TextField,
    FormControl,
    InputLabel,
    Select,
    MenuItem,
    Alert,
    Card,
    Grid,
    List,
    ListItem,
    ListItemText,
    ListItemIcon,
    ListItemSecondaryAction,
    IconButton,
    Chip,
    Tabs,
    Tab,
    Pagination,
    Divider,
    Tooltip,
    Stack,
} from '@mui/material';
import {
    Send as SendIcon,
    Notifications as NotificationsIcon,
    Group as GroupIcon,
    Event as EventIcon,
    CheckCircle as ApprovedIcon,
    Cancel as RejectedIcon,
    Info as InfoIcon,
    Campaign as BroadcastIcon,
    DoneAll as MarkReadIcon,
    MarkEmailRead as ReadIcon,
    Circle as UnreadIcon,
    AutoAwesome as AIIcon,
} from '@mui/icons-material';
import { formatDistanceToNow } from 'date-fns';
import { adminApi } from '../../api';
import { toast } from 'react-toastify';
import {
    PageHeader,
    SectionCard,
    EmptyState,
    LoadingButton,
    SkeletonCard,
} from '../../components/ui';
import { tokens } from '../../theme';

const Notifications = () => {
    const [tabValue, setTabValue] = useState(0);
    const [notifications, setNotifications] = useState([]);
    const [loading, setLoading] = useState(false);
    const [page, setPage] = useState(0);
    const [totalPages, setTotalPages] = useState(0);
    const [unreadCount, setUnreadCount] = useState(0);

    const [notificationType, setNotificationType] = useState('broadcast');
    const [formData, setFormData] = useState({
        title: '',
        message: '',
        targetRole: '',
    });
    const [formErrors, setFormErrors] = useState({});
    const [sendLoading, setSendLoading] = useState(false);
    const [aiLoading, setAiLoading] = useState(false);
    const [aiPurpose, setAiPurpose] = useState('');

    const fetchNotifications = useCallback(async () => {
        setLoading(true);
        try {
            const response = await adminApi.getUnreadNotifications({ page, size: 10 });
            setNotifications(response.data.data.content || []);
            setTotalPages(response.data.data.totalPages || 0);
        } catch (error) {
            console.error('Failed to fetch notifications:', error);
            toast.error('Failed to load notifications');
        } finally {
            setLoading(false);
        }
    }, [page]);

    const fetchUnreadCount = useCallback(async () => {
        try {
            const response = await adminApi.getUnreadCount();
            setUnreadCount(response.data.data.count);
        } catch (error) {
            console.error('Failed to fetch unread count:', error);
        }
    }, []);

    useEffect(() => {
        if (tabValue === 0) {
            fetchNotifications();
            fetchUnreadCount();
        }
    }, [tabValue, fetchNotifications, fetchUnreadCount]);

    const handleMarkAsRead = async (id) => {
        try {
            await adminApi.markAsRead(id);
            setNotifications(prev => prev.filter(n => n.id !== id));
            setUnreadCount(prev => Math.max(0, prev - 1));
            toast.success('Marked as read');
        } catch (error) {
            toast.error('Failed to mark as read');
        }
    };

    const handleMarkAllAsRead = async () => {
        try {
            await adminApi.markAllAsRead();
            setNotifications([]);
            setUnreadCount(0);
            setTotalPages(0);
            toast.success('All notifications marked as read');
        } catch (error) {
            toast.error('Failed to mark all as read');
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
                return <InfoIcon sx={{ color: 'text.disabled' }} />;
        }
    };

    const formatTime = (dateString) => {
        try {
            return formatDistanceToNow(new Date(dateString), { addSuffix: true });
        } catch {
            return '';
        }
    };

    const validateForm = () => {
        const errors = {};

        if (!formData.title.trim()) {
            errors.title = 'Title is required';
        } else if (formData.title.trim().length < 3) {
            errors.title = 'Title must be at least 3 characters';
        } else if (formData.title.trim().length > 100) {
            errors.title = 'Title must be less than 100 characters';
        }

        if (!formData.message.trim()) {
            errors.message = 'Message is required';
        } else if (formData.message.trim().length < 10) {
            errors.message = 'Message must be at least 10 characters';
        } else if (formData.message.trim().length > 500) {
            errors.message = 'Message must be less than 500 characters';
        }

        setFormErrors(errors);
        return Object.keys(errors).length === 0;
    };

    const handleAICompose = async () => {
        if (!aiPurpose.trim()) {
            toast.error('Please enter a purpose for the notification');
            return;
        }

        setAiLoading(true);
        try {
            const targetAudience = notificationType === 'role' && formData.targetRole
                ? formData.targetRole
                : 'All users';

            const response = await adminApi.generateBroadcastMessage({
                purpose: aiPurpose,
                targetAudience: targetAudience,
                additionalContext: formData.message || '',
            });

            setFormData(prev => ({
                ...prev,
                message: response.data.data.message,
                title: prev.title || aiPurpose.substring(0, 50),
            }));
            toast.success('Message generated with AI!');
        } catch (error) {
            toast.error('Failed to generate message');
        } finally {
            setAiLoading(false);
        }
    };

    const handleSubmit = async (e) => {
        e.preventDefault();

        if (!validateForm()) {
            toast.error('Please fix the errors in the form');
            return;
        }

        setSendLoading(true);
        try {
            await adminApi.broadcastNotification({
                title: formData.title,
                message: formData.message,
                targetRole: formData.targetRole || null,
            });
            toast.success('Notification sent successfully');
            setFormData({
                title: '',
                message: '',
                targetRole: '',
            });
            setAiPurpose('');
        } catch (error) {
            toast.error(error.response?.data?.message || 'Failed to send notification');
        } finally {
            setSendLoading(false);
        }
    };

    return (
        <Box>
            <PageHeader
                title="Notification Management"
                subtitle="Review unread notifications and broadcast messages to your users."
                icon={<NotificationsIcon />}
            />

            <Paper sx={{ mb: 3, borderRadius: 2, overflow: 'hidden' }}>
                <Tabs
                    value={tabValue}
                    onChange={(e, newValue) => setTabValue(newValue)}
                    sx={{ borderBottom: 1, borderColor: 'divider', px: 2 }}
                >
                    <Tab
                        label={
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                Unread Notifications
                                {unreadCount > 0 && (
                                    <Chip
                                        label={unreadCount}
                                        size="small"
                                        color="error"
                                        sx={{ height: 20, minWidth: 20 }}
                                    />
                                )}
                            </Box>
                        }
                    />
                    <Tab label="Send Notification" />
                </Tabs>
            </Paper>

            {tabValue === 0 && (
                <SectionCard
                    title={`Unread (${notifications.length})`}
                    subtitle="Click an item to mark it as read"
                    action={
                        unreadCount > 0 ? (
                            <LoadingButton
                                startIcon={<MarkReadIcon />}
                                onClick={handleMarkAllAsRead}
                                size="small"
                                variant="outlined"
                            >
                                Mark all as read
                            </LoadingButton>
                        ) : null
                    }
                    noPadding
                >
                    {loading ? (
                        <Box sx={{ p: 3 }}>
                            <SkeletonCard rows={4} />
                        </Box>
                    ) : notifications.length === 0 ? (
                        <EmptyState
                            icon={<NotificationsIcon sx={{ fontSize: 32 }} />}
                            title="No unread notifications"
                            description="You're all caught up! New notifications will appear here."
                        />
                    ) : (
                        <Box sx={{ px: 1, pb: 2 }}>
                            <List disablePadding>
                                {notifications.map((notification, index) => (
                                    <React.Fragment key={notification.id}>
                                        <ListItem
                                            onClick={() => handleMarkAsRead(notification.id)}
                                            sx={{
                                                py: 2,
                                                px: 2,
                                                my: 0.5,
                                                borderRadius: 1.5,
                                                cursor: 'pointer',
                                                transition: tokens.motion.fast,
                                                '&:hover': {
                                                    bgcolor: tokens.palette.primary[50],
                                                },
                                            }}
                                        >
                                            <ListItemIcon>
                                                {getNotificationIcon(notification.type)}
                                            </ListItemIcon>
                                            <ListItemText
                                                primary={
                                                    <Box component="span" sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                                        <Typography
                                                            variant="subtitle1"
                                                            component="span"
                                                            fontWeight={600}
                                                        >
                                                            {notification.title}
                                                        </Typography>
                                                        <UnreadIcon sx={{ fontSize: 10, color: 'primary.main' }} />
                                                    </Box>
                                                }
                                                secondary={
                                                    <Box component="span" sx={{ display: 'block' }}>
                                                        <Typography
                                                            variant="body2"
                                                            component="span"
                                                            color="text.secondary"
                                                            sx={{ display: 'block', mt: 0.5 }}
                                                        >
                                                            {notification.message}
                                                        </Typography>
                                                        <Typography
                                                            variant="caption"
                                                            component="span"
                                                            color="text.disabled"
                                                            sx={{ display: 'block', mt: 1 }}
                                                        >
                                                            {formatTime(notification.createdAt)}
                                                        </Typography>
                                                    </Box>
                                                }
                                            />
                                            <ListItemSecondaryAction>
                                                <Tooltip title="Mark as read">
                                                    <IconButton
                                                        edge="end"
                                                        aria-label="mark as read"
                                                        onClick={(e) => {
                                                            e.stopPropagation();
                                                            handleMarkAsRead(notification.id);
                                                        }}
                                                        size="small"
                                                    >
                                                        <ReadIcon />
                                                    </IconButton>
                                                </Tooltip>
                                            </ListItemSecondaryAction>
                                        </ListItem>
                                        {index < notifications.length - 1 && <Divider sx={{ mx: 2 }} />}
                                    </React.Fragment>
                                ))}
                            </List>

                            {totalPages > 1 && (
                                <Box sx={{ display: 'flex', justifyContent: 'center', mt: 3 }}>
                                    <Pagination
                                        count={totalPages}
                                        page={page + 1}
                                        onChange={(e, value) => setPage(value - 1)}
                                        color="primary"
                                    />
                                </Box>
                            )}
                        </Box>
                    )}
                </SectionCard>
            )}

            {tabValue === 1 && (
                <Box>
                    <Grid container spacing={2} sx={{ mb: 3 }}>
                        <Grid item xs={12} md={6}>
                            <Card
                                sx={{
                                    cursor: 'pointer',
                                    p: 2.5,
                                    border: 2,
                                    borderColor: notificationType === 'broadcast' ? 'primary.main' : 'divider',
                                    bgcolor: notificationType === 'broadcast' ? tokens.palette.primary[50] : 'background.paper',
                                    transition: tokens.motion.fast,
                                    '&:hover': { borderColor: 'primary.light' },
                                }}
                                onClick={() => setNotificationType('broadcast')}
                            >
                                <Stack direction="row" alignItems="center" spacing={2}>
                                    <Box
                                        sx={{
                                            width: 48,
                                            height: 48,
                                            borderRadius: 2,
                                            display: 'flex',
                                            alignItems: 'center',
                                            justifyContent: 'center',
                                            bgcolor: notificationType === 'broadcast' ? 'primary.main' : tokens.palette.neutral[100],
                                            color: notificationType === 'broadcast' ? 'primary.contrastText' : 'text.secondary',
                                        }}
                                    >
                                        <GroupIcon />
                                    </Box>
                                    <Box>
                                        <Typography variant="h6" sx={{ fontWeight: 600 }}>
                                            Broadcast
                                        </Typography>
                                        <Typography variant="body2" color="text.secondary">
                                            Send notification to all users
                                        </Typography>
                                    </Box>
                                </Stack>
                            </Card>
                        </Grid>
                        <Grid item xs={12} md={6}>
                            <Card
                                sx={{
                                    cursor: 'pointer',
                                    p: 2.5,
                                    border: 2,
                                    borderColor: notificationType === 'role' ? 'primary.main' : 'divider',
                                    bgcolor: notificationType === 'role' ? tokens.palette.primary[50] : 'background.paper',
                                    transition: tokens.motion.fast,
                                    '&:hover': { borderColor: 'primary.light' },
                                }}
                                onClick={() => setNotificationType('role')}
                            >
                                <Stack direction="row" alignItems="center" spacing={2}>
                                    <Box
                                        sx={{
                                            width: 48,
                                            height: 48,
                                            borderRadius: 2,
                                            display: 'flex',
                                            alignItems: 'center',
                                            justifyContent: 'center',
                                            bgcolor: notificationType === 'role' ? 'primary.main' : tokens.palette.neutral[100],
                                            color: notificationType === 'role' ? 'primary.contrastText' : 'text.secondary',
                                        }}
                                    >
                                        <NotificationsIcon />
                                    </Box>
                                    <Box>
                                        <Typography variant="h6" sx={{ fontWeight: 600 }}>
                                            By Role
                                        </Typography>
                                        <Typography variant="body2" color="text.secondary">
                                            Send notification to users by role
                                        </Typography>
                                    </Box>
                                </Stack>
                            </Card>
                        </Grid>
                    </Grid>

                    <SectionCard
                        title="Compose Notification"
                        subtitle="Fill in the details below and send when ready"
                    >
                        <form onSubmit={handleSubmit}>
                            {notificationType === 'role' && (
                                <FormControl fullWidth margin="normal">
                                    <InputLabel>Target Role</InputLabel>
                                    <Select
                                        value={formData.targetRole}
                                        onChange={(e) => setFormData({ ...formData, targetRole: e.target.value })}
                                        label="Target Role"
                                    >
                                        <MenuItem value="">All</MenuItem>
                                        <MenuItem value="USER">User</MenuItem>
                                        <MenuItem value="ORGANISER">Organiser</MenuItem>
                                        <MenuItem value="ADMIN">Admin</MenuItem>
                                    </Select>
                                </FormControl>
                            )}

                            <TextField
                                fullWidth
                                label="Title"
                                value={formData.title}
                                onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                                margin="normal"
                                required
                                error={!!formErrors.title}
                                helperText={formErrors.title || '3-100 characters'}
                            />

                            <Paper
                                variant="outlined"
                                sx={{
                                    p: 2,
                                    mt: 2,
                                    mb: 2,
                                    background: tokens.gradient.primarySoft,
                                    borderStyle: 'dashed',
                                    borderColor: tokens.palette.primary[200],
                                }}
                            >
                                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
                                    <AIIcon sx={{ color: tokens.palette.secondary[600] }} />
                                    <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                                        AI Compose Assistant
                                    </Typography>
                                </Stack>
                                <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1}>
                                    <TextField
                                        fullWidth
                                        size="small"
                                        placeholder="Describe the purpose (e.g., 'System maintenance tomorrow')"
                                        value={aiPurpose}
                                        onChange={(e) => setAiPurpose(e.target.value)}
                                        disabled={aiLoading}
                                        sx={{ bgcolor: 'background.paper' }}
                                    />
                                    <LoadingButton
                                        variant="contained"
                                        color="secondary"
                                        onClick={handleAICompose}
                                        loading={aiLoading}
                                        disabled={!aiPurpose.trim()}
                                        startIcon={<AIIcon />}
                                    >
                                        Generate
                                    </LoadingButton>
                                </Stack>
                            </Paper>

                            <TextField
                                fullWidth
                                label="Message"
                                value={formData.message}
                                onChange={(e) => setFormData({ ...formData, message: e.target.value })}
                                margin="normal"
                                required
                                multiline
                                rows={4}
                                error={!!formErrors.message}
                                helperText={formErrors.message || '10-500 characters'}
                            />

                            <Alert severity="warning" sx={{ mt: 2 }}>
                                {notificationType === 'broadcast'
                                    ? 'This notification will be sent to ALL users in the system.'
                                    : formData.targetRole
                                        ? `This notification will be sent to all ${formData.targetRole === 'USER' ? 'users' : formData.targetRole === 'ORGANISER' ? 'organisers' : 'admins'}.`
                                        : 'This notification will be sent to ALL users in the system.'
                                }
                            </Alert>

                            <Box sx={{ mt: 3, display: 'flex', justifyContent: 'flex-end' }}>
                                <LoadingButton
                                    type="submit"
                                    variant="contained"
                                    startIcon={<SendIcon />}
                                    loading={sendLoading}
                                    size="large"
                                >
                                    Send Notification
                                </LoadingButton>
                            </Box>
                        </form>
                    </SectionCard>
                </Box>
            )}
        </Box>
    );
};

export default Notifications;

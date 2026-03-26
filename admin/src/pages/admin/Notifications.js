import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Typography,
    Paper,
    TextField,
    Button,
    FormControl,
    InputLabel,
    Select,
    MenuItem,
    Alert,
    Card,
    CardContent,
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
    CircularProgress,
    Pagination,
    Divider,
    Tooltip,
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
            <Typography variant="h5" fontWeight="bold" mb={3}>
                Notification Management
            </Typography>

            <Paper sx={{ mb: 3 }}>
                <Tabs
                    value={tabValue}
                    onChange={(e, newValue) => setTabValue(newValue)}
                    sx={{ borderBottom: 1, borderColor: 'divider' }}
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
                <Paper sx={{ p: 2 }}>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
                        <Typography variant="h6">
                            Unread ({notifications.length})
                        </Typography>
                        {unreadCount > 0 && (
                            <Button
                                startIcon={<MarkReadIcon />}
                                onClick={handleMarkAllAsRead}
                                size="small"
                            >
                                Mark all as read
                            </Button>
                        )}
                    </Box>

                    {loading ? (
                        <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
                            <CircularProgress />
                        </Box>
                    ) : notifications.length === 0 ? (
                        <Box sx={{ py: 4, textAlign: 'center' }}>
                            <NotificationsIcon sx={{ fontSize: 64, color: 'grey.300', mb: 2 }} />
                            <Typography color="text.secondary">
                                No unread notifications
                            </Typography>
                            <Typography variant="body2" color="text.disabled">
                                You're all caught up!
                            </Typography>
                        </Box>
                    ) : (
                        <>
                            <List>
                                {notifications.map((notification, index) => (
                                    <React.Fragment key={notification.id}>
                                        <ListItem
                                            onClick={() => handleMarkAsRead(notification.id)}
                                            sx={{
                                                py: 2,
                                                bgcolor: 'action.hover',
                                                borderRadius: 1,
                                                cursor: 'pointer',
                                                '&:hover': {
                                                    bgcolor: 'action.selected',
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
                                        {index < notifications.length - 1 && <Divider />}
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
                        </>
                    )}
                </Paper>
            )}

            {tabValue === 1 && (
                <>
                    <Grid container spacing={3} mb={3}>
                        <Grid item xs={12} md={6}>
                            <Card
                                sx={{
                                    cursor: 'pointer',
                                    border: notificationType === 'broadcast' ? 2 : 1,
                                    borderColor: notificationType === 'broadcast' ? 'primary.main' : 'divider',
                                }}
                                onClick={() => setNotificationType('broadcast')}
                            >
                                <CardContent sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                                    <GroupIcon
                                        sx={{
                                            fontSize: 40,
                                            color: notificationType === 'broadcast' ? 'primary.main' : 'text.secondary',
                                        }}
                                    />
                                    <Box>
                                        <Typography variant="h6">Broadcast</Typography>
                                        <Typography variant="body2" color="text.secondary">
                                            Send notification to all users
                                        </Typography>
                                    </Box>
                                </CardContent>
                            </Card>
                        </Grid>
                        <Grid item xs={12} md={6}>
                            <Card
                                sx={{
                                    cursor: 'pointer',
                                    border: notificationType === 'role' ? 2 : 1,
                                    borderColor: notificationType === 'role' ? 'primary.main' : 'divider',
                                }}
                                onClick={() => setNotificationType('role')}
                            >
                                <CardContent sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                                    <NotificationsIcon
                                        sx={{
                                            fontSize: 40,
                                            color: notificationType === 'role' ? 'primary.main' : 'text.secondary',
                                        }}
                                    />
                                    <Box>
                                        <Typography variant="h6">By Role</Typography>
                                        <Typography variant="body2" color="text.secondary">
                                            Send notification to users by role
                                        </Typography>
                                    </Box>
                                </CardContent>
                            </Card>
                        </Grid>
                    </Grid>

                    <Paper sx={{ p: 3 }}>
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

                            <Paper sx={{ p: 2, mt: 2, mb: 2, bgcolor: 'grey.50', border: '1px dashed', borderColor: 'grey.300' }}>
                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                                    <AIIcon color="secondary" />
                                    <Typography variant="subtitle2">AI Compose Assistant</Typography>
                                </Box>
                                <Box sx={{ display: 'flex', gap: 1 }}>
                                    <TextField
                                        fullWidth
                                        size="small"
                                        placeholder="Describe the purpose (e.g., 'System maintenance tomorrow', 'New feature announcement')"
                                        value={aiPurpose}
                                        onChange={(e) => setAiPurpose(e.target.value)}
                                        disabled={aiLoading}
                                    />
                                    <Button
                                        variant="contained"
                                        color="secondary"
                                        onClick={handleAICompose}
                                        disabled={aiLoading || !aiPurpose.trim()}
                                        startIcon={aiLoading ? <CircularProgress size={16} color="inherit" /> : <AIIcon />}
                                    >
                                        {aiLoading ? 'Generating...' : 'Generate'}
                                    </Button>
                                </Box>
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
                                <Button
                                    type="submit"
                                    variant="contained"
                                    startIcon={<SendIcon />}
                                    disabled={sendLoading}
                                    size="large"
                                >
                                    {sendLoading ? 'Sending...' : 'Send Notification'}
                                </Button>
                            </Box>
                        </form>
                    </Paper>
                </>
            )}
        </Box>
    );
};

export default Notifications;

import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Typography,
    Paper,
    List,
    ListItem,
    ListItemText,
    ListItemIcon,
    ListItemSecondaryAction,
    IconButton,
    Button,
    CircularProgress,
    Pagination,
    Divider,
    Tooltip,
    Chip,
    Tabs,
    Tab,
    TextField,
    Autocomplete,
    Alert,
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
    Circle as UnreadIcon,
    Send as SendIcon,
    AutoAwesome as AIIcon,
} from '@mui/icons-material';
import { formatDistanceToNow } from 'date-fns';
import { organiserApi } from '../../api/organiserApi';
import { toast } from 'react-toastify';

const NOTIFICATION_TYPES = [
    { value: 'EVENT_UPDATE', label: 'Event Update', description: 'Attendees + Pending registrations' },
    { value: 'ANNOUNCEMENT', label: 'Announcement', description: 'Attendees + Pending + Followers' },
    { value: 'THANK_YOU', label: 'Thank You Message', description: 'Attendees (approved only)' },
    { value: 'FEEDBACK_REQUEST', label: 'Feedback Request', description: 'Checked-in attendees only' },
];

const Notifications = () => {
    const [tabValue, setTabValue] = useState(0);
    const [notifications, setNotifications] = useState([]);
    const [loading, setLoading] = useState(false);
    const [page, setPage] = useState(0);
    const [totalPages, setTotalPages] = useState(0);
    const [unreadCount, setUnreadCount] = useState(0);

    const [events, setEvents] = useState([]);
    const [selectedEvent, setSelectedEvent] = useState(null);
    const [notificationType, setNotificationType] = useState(null);
    const [formData, setFormData] = useState({ title: '', message: '' });
    const [formErrors, setFormErrors] = useState({});
    const [sendLoading, setSendLoading] = useState(false);
    const [aiLoading, setAiLoading] = useState(false);
    const [recipientCount, setRecipientCount] = useState(null);
    const [recipientLoading, setRecipientLoading] = useState(false);

    const fetchNotifications = useCallback(async () => {
        setLoading(true);
        try {
            const response = await organiserApi.getUnreadNotifications({ page, size: 10 });
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
            const response = await organiserApi.getUnreadCount();
            setUnreadCount(response.data.data.count);
        } catch (error) {
            console.error('Failed to fetch unread count:', error);
        }
    }, []);

    const fetchEvents = useCallback(async () => {
        try {
            const response = await organiserApi.getMyEvents({ page: 0, size: 100, status: 'PUBLISHED' });
            setEvents(response.data.data.content || []);
        } catch (error) {
            console.error('Failed to fetch events:', error);
        }
    }, []);

    useEffect(() => {
        if (tabValue === 0) {
            fetchNotifications();
            fetchUnreadCount();
        } else if (tabValue === 1) {
            fetchEvents();
        }
    }, [tabValue, fetchNotifications, fetchUnreadCount, fetchEvents]);

    useEffect(() => {
        const fetchRecipientCount = async () => {
            if (!selectedEvent || !notificationType) {
                setRecipientCount(null);
                return;
            }
            setRecipientLoading(true);
            try {
                const response = await organiserApi.getRecipientCount(selectedEvent.id, notificationType.value);
                setRecipientCount(response.data.data.recipientCount);
            } catch (error) {
                console.error('Failed to fetch recipient count:', error);
                setRecipientCount(null);
            } finally {
                setRecipientLoading(false);
            }
        };
        fetchRecipientCount();
    }, [selectedEvent, notificationType]);

    const handleMarkAsRead = async (id) => {
        try {
            await organiserApi.markAsRead(id);
            setNotifications(prev => prev.filter(n => n.id !== id));
            setUnreadCount(prev => Math.max(0, prev - 1));
            toast.success('Marked as read');
        } catch (error) {
            toast.error('Failed to mark as read');
        }
    };

    const handleMarkAllAsRead = async () => {
        try {
            await organiserApi.markAllAsRead();
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

        if (!selectedEvent) {
            errors.event = 'Please select an event';
        }

        if (!notificationType) {
            errors.notificationType = 'Please select a notification type';
        }

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

    const handleGenerateAI = async () => {
        if (!selectedEvent) {
            toast.error('Please select an event first');
            return;
        }
        if (!notificationType) {
            toast.error('Please select a notification type');
            return;
        }

        setAiLoading(true);
        try {
            const response = await organiserApi.generateNotification({
                eventTitle: selectedEvent.title,
                notificationType: notificationType.value,
                additionalContext: formData.message || '',
            });
            setFormData(prev => ({ ...prev, message: response.data.data.message }));
            if (!formData.title.trim()) {
                const titleMap = {
                    EVENT_REMINDER: `Reminder: ${selectedEvent.title}`,
                    EVENT_UPDATE: `Update: ${selectedEvent.title}`,
                    ANNOUNCEMENT: `Announcement: ${selectedEvent.title}`,
                    THANK_YOU: `Thank You - ${selectedEvent.title}`,
                    FEEDBACK_REQUEST: `Your Feedback - ${selectedEvent.title}`,
                };
                setFormData(prev => ({ ...prev, title: titleMap[notificationType.value] || selectedEvent.title }));
            }
            toast.success('Message generated with AI!');
        } catch (error) {
            toast.error(error.response?.data?.message || 'Failed to generate message');
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
            const response = await organiserApi.sendToAttendees({
                eventId: selectedEvent.id,
                title: formData.title,
                message: formData.message,
                notificationType: notificationType.value,
            });
            const count = response.data.data.recipientCount;
            toast.success(`Notification sent to ${count} recipient${count !== 1 ? 's' : ''}`);
            setFormData({ title: '', message: '' });
            setSelectedEvent(null);
            setNotificationType(null);
            setRecipientCount(null);
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
                    <Tab label="Send to Attendees" />
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
                        <Box sx={{ py: 6, textAlign: 'center' }}>
                            <NotificationsIcon sx={{ fontSize: 80, color: 'grey.300', mb: 2 }} />
                            <Typography variant="h6" color="text.secondary">
                                No unread notifications
                            </Typography>
                            <Typography color="text.disabled">
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
                <Paper sx={{ p: 3 }}>
                    <Typography variant="h6" gutterBottom>
                        Send Notification to Event Attendees
                    </Typography>
                    <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
                        Send a notification to all approved attendees of your event.
                    </Typography>

                    <form onSubmit={handleSubmit}>
                        <Autocomplete
                            options={events}
                            getOptionLabel={(option) => option.title || ''}
                            value={selectedEvent}
                            onChange={(_, newValue) => setSelectedEvent(newValue)}
                            renderInput={(params) => (
                                <TextField
                                    {...params}
                                    label="Select Event"
                                    placeholder="Search your events..."
                                    error={!!formErrors.event}
                                    helperText={formErrors.event}
                                    required
                                />
                            )}
                            renderOption={(props, option) => (
                                <li {...props} key={option.id}>
                                    <Box sx={{ width: '100%' }}>
                                        <Typography variant="body1" noWrap>{option.title}</Typography>
                                        <Typography variant="caption" color="text.secondary">
                                            {option.startTime ? new Date(option.startTime).toLocaleDateString() : ''} - {option.currentRegistrations || 0} attendees
                                        </Typography>
                                    </Box>
                                </li>
                            )}
                            isOptionEqualToValue={(option, value) => option.id === value.id}
                            sx={{ mb: 2 }}
                        />

                        <Autocomplete
                            options={NOTIFICATION_TYPES}
                            getOptionLabel={(option) => option.label}
                            value={notificationType}
                            onChange={(_, newValue) => setNotificationType(newValue)}
                            renderInput={(params) => (
                                <TextField
                                    {...params}
                                    label="Notification Type"
                                    placeholder="Select notification type..."
                                    required
                                    error={!!formErrors.notificationType}
                                    helperText={formErrors.notificationType}
                                />
                            )}
                            renderOption={(props, option) => (
                                <li {...props} key={option.value}>
                                    <Box sx={{ width: '100%' }}>
                                        <Typography variant="body1">{option.label}</Typography>
                                        <Typography variant="caption" color="text.secondary">
                                            {option.description}
                                        </Typography>
                                    </Box>
                                </li>
                            )}
                            sx={{ mb: 2 }}
                        />

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

                        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mt: 2, mb: 1 }}>
                            <Typography variant="body2" color="text.secondary">
                                Message *
                            </Typography>
                            <Button
                                size="small"
                                variant="outlined"
                                color="secondary"
                                startIcon={<AIIcon />}
                                onClick={handleGenerateAI}
                                disabled={aiLoading || !selectedEvent || !notificationType}
                            >
                                {aiLoading ? 'Generating...' : 'AI Compose'}
                            </Button>
                        </Box>

                        <TextField
                            fullWidth
                            value={formData.message}
                            onChange={(e) => setFormData({ ...formData, message: e.target.value })}
                            required
                            multiline
                            rows={4}
                            error={!!formErrors.message}
                            helperText={formErrors.message || '10-500 characters'}
                            placeholder="Write your message or use AI Compose to generate..."
                        />

                        {selectedEvent && notificationType && (
                            <Alert severity="info" sx={{ mt: 2 }}>
                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                    {recipientLoading ? (
                                        <>
                                            <CircularProgress size={16} />
                                            <span>Calculating recipients...</span>
                                        </>
                                    ) : (
                                        <span>
                                            This notification will be sent to <strong>{recipientCount ?? 0}</strong> recipient(s).
                                            <br />
                                            <Typography variant="caption" color="text.secondary">
                                                Type: {notificationType.label} - {notificationType.description}
                                            </Typography>
                                        </span>
                                    )}
                                </Box>
                            </Alert>
                        )}
                        {selectedEvent && !notificationType && (
                            <Alert severity="warning" sx={{ mt: 2 }}>
                                Please select a notification type to see recipient count.
                            </Alert>
                        )}

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
            )}
        </Box>
    );
};

export default Notifications;

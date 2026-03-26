import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Typography,
    Paper,
    Button,
    IconButton,
    Chip,
    MenuItem,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    TextField,
    Grid,
    FormControl,
    InputLabel,
    Select,
    Autocomplete,
    Tooltip,
    Alert,
    Drawer,
    Divider,
    FormControlLabel,
    Checkbox,
    FormGroup,
} from '@mui/material';
import { DataGrid } from '@mui/x-data-grid';
import {
    Add as AddIcon,
    Refresh as RefreshIcon,
    AutoAwesome as AIIcon,
    MyLocation as LocationIcon,
    Close as CloseIcon,
    LocationOn as LocationOnIcon,
    People as PeopleIcon,
    AttachMoney as MoneyIcon,
    Category as CategoryIcon,
    Schedule as ScheduleIcon,
    Repeat as RepeatIcon,
    Cancel as CancelIcon,
    Edit as EditIcon,
} from '@mui/icons-material';
import { DateTimePicker } from '@mui/x-date-pickers/DateTimePicker';
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider';
import { AdapterDateFns } from '@mui/x-date-pickers/AdapterDateFns';
import MDEditor from '@uiw/react-md-editor';
import { organiserApi, publicApi } from '../../api';
import { ConfirmDialog, ImageUpload, SpeakerForm, UpgradeDialog } from '../../components/common';
import { toast } from 'react-toastify';
import { useNavigate } from 'react-router-dom';

const statusColors = {
    DRAFT: 'default',
    PUBLISHED: 'success',
    CANCELLED: 'error',
    COMPLETED: 'info',
    REJECTED: 'warning',
};

const recurrenceTypes = [
    { value: 'NONE', label: 'Does not repeat' },
    { value: 'DAILY', label: 'Daily' },
    { value: 'WEEKLY', label: 'Weekly' },
    { value: 'BIWEEKLY', label: 'Every 2 weeks' },
    { value: 'MONTHLY', label: 'Monthly' },
];

const daysOfWeek = [
    { value: 'MON', label: 'Mon' },
    { value: 'TUE', label: 'Tue' },
    { value: 'WED', label: 'Wed' },
    { value: 'THU', label: 'Thu' },
    { value: 'FRI', label: 'Fri' },
    { value: 'SAT', label: 'Sat' },
    { value: 'SUN', label: 'Sun' },
];

const toLocalISOString = (date) => {
    const pad = (n) => n.toString().padStart(2, '0');
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
};

const OrganiserEvents = () => {
    const navigate = useNavigate();
    const [events, setEvents] = useState([]);
    const [categories, setCategories] = useState([]);
    const [cities, setCities] = useState([]);
    const [loading, setLoading] = useState(true);
    const [paginationModel, setPaginationModel] = useState({ page: 0, pageSize: 10 });
    const [totalRows, setTotalRows] = useState(0);
    const [selectedEvent, setSelectedEvent] = useState(null);
    const [dialogOpen, setDialogOpen] = useState(false);
    const [editEvent, setEditEvent] = useState(null);
    const [confirmDialog, setConfirmDialog] = useState({ open: false, title: '', message: '', action: null });
    const [quickViewOpen, setQuickViewOpen] = useState(false);
    const [quickViewEvent, setQuickViewEvent] = useState(null);
    const [subscription, setSubscription] = useState(null);
    const [upgradeDialog, setUpgradeDialog] = useState({ open: false, message: '', feature: '' });
    const getDefaultDeadline = (startTime) => {
        const deadline = new Date(startTime);
        deadline.setDate(deadline.getDate() - 1);
        return deadline;
    };

    const [formData, setFormData] = useState({
        title: '',
        description: '',
        imageUrl: '',
        venue: '',
        address: '',
        latitude: '',
        longitude: '',
        startTime: new Date(),
        endTime: new Date(),
        registrationDeadline: getDefaultDeadline(new Date()),
        capacity: 100,
        ticketPrice: 0,
        isFree: true,
        categoryId: '',
        cityId: '',
        visibility: 'PUBLIC',
        requiresApproval: true,
        speakers: [],
        recurrenceType: 'NONE',
        recurrenceInterval: 1,
        recurrenceDaysOfWeek: [],
        recurrenceEndDate: null,
        recurrenceCount: null,
    });
    const [formErrors, setFormErrors] = useState({});
    const [aiGenerating, setAiGenerating] = useState(false);
    const [aiImproving, setAiImproving] = useState(false);
    const [geocoding, setGeocoding] = useState(false);

    const handleGeocodeAddress = async () => {
        if (!formData.address.trim()) {
            toast.error('Please enter an address first');
            return;
        }

        setGeocoding(true);
        try {
            const encodedAddress = encodeURIComponent(formData.address);
            const response = await fetch(
                `https://nominatim.openstreetmap.org/search?format=json&q=${encodedAddress}&limit=1`,
                {
                    headers: {
                        'Accept-Language': 'en',
                    },
                }
            );
            const data = await response.json();

            if (data && data.length > 0) {
                const { lat, lon } = data[0];
                setFormData(prev => ({
                    ...prev,
                    latitude: parseFloat(lat),
                    longitude: parseFloat(lon),
                }));
                toast.success(`Coordinates found: ${parseFloat(lat).toFixed(6)}, ${parseFloat(lon).toFixed(6)}`);
            } else {
                toast.warning('Could not find coordinates for this address. Please try a more specific address or enter manually.');
            }
        } catch (error) {
            console.error('Geocoding error:', error);
            toast.error('Failed to get coordinates. Please try again or enter manually.');
        } finally {
            setGeocoding(false);
        }
    };

    const loadEvents = useCallback(async () => {
        setLoading(true);
        try {
            const response = await organiserApi.getMyEvents({
                page: paginationModel.page,
                size: paginationModel.pageSize,
            });
            setEvents(response.data.data.content || []);
            setTotalRows(response.data.data.totalElements || 0);
        } catch (error) {
            toast.error('Failed to load events');
        } finally {
            setLoading(false);
        }
    }, [paginationModel]);

    const loadMasterData = async () => {
        try {
            const [catRes, cityRes, subRes] = await Promise.all([
                publicApi.getCategories(),
                publicApi.getCities(),
                organiserApi.getMySubscription().catch(() => null),
            ]);
            setCategories(catRes.data.data || []);
            setCities(cityRes.data.data || []);
            if (subRes?.data?.data) {
                setSubscription(subRes.data.data);
            }
        } catch (error) {
            console.error('Failed to load master data:', error);
        }
    };

    useEffect(() => {
        loadEvents();
        loadMasterData();
    }, [loadEvents]);

    const handleRowClick = async (params) => {
        try {
            const response = await organiserApi.getEventById(params.row.id);
            setQuickViewEvent(response.data.data);
            setQuickViewOpen(true);
        } catch (error) {
            toast.error('Failed to load event details');
        }
    };

    const handleOpenDialog = async (event = null) => {
        // Check subscription quota before creating new event
        if (!event && subscription) {
            const remaining = subscription.remainingEvents;
            if (remaining === 0) {
                setUpgradeDialog({
                    open: true,
                    message: `You have reached your monthly event limit (${subscription.maxEventsPerMonth} events). Upgrade your plan to create more events.`,
                    feature: 'Event Creation',
                });
                return;
            }
        }
        if (event) {
            try {
                const response = await organiserApi.getEventById(event.id);
                const eventData = response.data.data;

                setEditEvent(eventData);
                setFormData({
                    title: eventData.title || '',
                    description: eventData.description || '',
                    imageUrl: eventData.imageUrl || '',
                    venue: eventData.venue || '',
                    address: eventData.address || '',
                    latitude: eventData.latitude || '',
                    longitude: eventData.longitude || '',
                    startTime: new Date(eventData.startTime),
                    endTime: new Date(eventData.endTime),
                    registrationDeadline: eventData.registrationDeadline ? new Date(eventData.registrationDeadline) : null,
                    capacity: eventData.capacity || 100,
                    ticketPrice: eventData.ticketPrice || 0,
                    isFree: eventData.isFree !== false,
                    categoryId: eventData.category?.id || '',
                    cityId: eventData.city?.id || '',
                    visibility: eventData.visibility || 'PUBLIC',
                    requiresApproval: eventData.requiresApproval || false,
                    speakers: eventData.speakers || [],
                    recurrenceType: eventData.recurrenceType || 'NONE',
                    recurrenceInterval: eventData.recurrenceInterval || 1,
                    recurrenceDaysOfWeek: eventData.recurrenceDaysOfWeek || [],
                    recurrenceEndDate: eventData.recurrenceEndDate ? new Date(eventData.recurrenceEndDate) : null,
                    recurrenceCount: eventData.recurrenceCount || null,
                });
                setDialogOpen(true);
                setFormErrors({});
            } catch (error) {
                toast.error('Failed to load event details');
                console.error('Error loading event:', error);
            }
        } else {
            setEditEvent(null);
            const defaultStartTime = new Date();
            setFormData({
                title: '',
                description: '',
                imageUrl: '',
                venue: '',
                address: '',
                latitude: '',
                longitude: '',
                startTime: defaultStartTime,
                endTime: defaultStartTime,
                registrationDeadline: getDefaultDeadline(defaultStartTime),
                capacity: 100,
                ticketPrice: 0,
                isFree: true,
                categoryId: '',
                cityId: '',
                visibility: 'PUBLIC',
                requiresApproval: true,
                speakers: [],
                recurrenceType: 'NONE',
                recurrenceInterval: 1,
                recurrenceDaysOfWeek: [],
                recurrenceEndDate: null,
                recurrenceCount: null,
            });
            setDialogOpen(true);
            setFormErrors({});
        }
    };

    const handleCloseDialog = () => {
        setDialogOpen(false);
        setEditEvent(null);
        setFormErrors({});
    };

    const validateForm = () => {
        const errors = {};
        const now = new Date();

        if (!formData.title.trim()) {
            errors.title = 'Title is required';
        } else if (formData.title.trim().length < 5) {
            errors.title = 'Title must be at least 5 characters';
        } else if (formData.title.trim().length > 200) {
            errors.title = 'Title must be less than 200 characters';
        }

        if (!formData.description.trim()) {
            errors.description = 'Description is required';
        } else if (formData.description.trim().length < 20) {
            errors.description = 'Description must be at least 20 characters';
        }

        if (!formData.venue.trim()) {
            errors.venue = 'Venue is required';
        }

        if (!formData.address.trim()) {
            errors.address = 'Address is required';
        }

        if (!formData.categoryId) {
            errors.categoryId = 'Category is required';
        }

        if (!formData.cityId) {
            errors.cityId = 'City is required';
        }

        if (!formData.capacity || formData.capacity <= 0) {
            errors.capacity = 'Capacity must be greater than 0';
        } else if (formData.capacity > 100000) {
            errors.capacity = 'Capacity must be less than 100,000';
        }

        if (formData.ticketPrice < 0) {
            errors.ticketPrice = 'Price cannot be negative';
        }

        if (!editEvent) {
            if (formData.startTime <= now) {
                errors.startTime = 'Start time must be in the future';
            }
        }

        if (formData.endTime <= formData.startTime) {
            errors.endTime = 'End time must be after start time';
        }

        if (formData.registrationDeadline) {
            if (!editEvent && formData.registrationDeadline <= now) {
                errors.registrationDeadline = 'Registration deadline must be in the future';
            }

            if (formData.registrationDeadline >= formData.startTime) {
                errors.registrationDeadline = 'Registration deadline must be before start time';
            }
        }

        const hasLatitude = formData.latitude !== '' && formData.latitude !== null;
        const hasLongitude = formData.longitude !== '' && formData.longitude !== null;

        if (hasLatitude && !hasLongitude) {
            errors.longitude = 'Longitude is required when Latitude is provided';
        }
        if (hasLongitude && !hasLatitude) {
            errors.latitude = 'Latitude is required when Longitude is provided';
        }

        if (hasLatitude) {
            const lat = parseFloat(formData.latitude);
            if (isNaN(lat) || lat < -90 || lat > 90) {
                errors.latitude = 'Latitude must be between -90 and 90';
            }
        }

        if (hasLongitude) {
            const lng = parseFloat(formData.longitude);
            if (isNaN(lng) || lng < -180 || lng > 180) {
                errors.longitude = 'Longitude must be between -180 and 180';
            }
        }

        const speakerErrors = [];
        let hasSpeakerErrors = false;
        formData.speakers.forEach((speaker, index) => {
            const speakerError = {};
            if (!speaker.name || !speaker.name.trim()) {
                speakerError.name = 'Name is required';
                hasSpeakerErrors = true;
            }
            if (!speaker.title || !speaker.title.trim()) {
                speakerError.title = 'Title is required';
                hasSpeakerErrors = true;
            }
            if (!speaker.bio || !speaker.bio.trim()) {
                speakerError.bio = 'Bio is required';
                hasSpeakerErrors = true;
            }
            speakerErrors[index] = speakerError;
        });
        if (hasSpeakerErrors) {
            errors.speakers = speakerErrors;
        }

        setFormErrors(errors);
        return Object.keys(errors).length === 0;
    };

    const handleSubmit = async () => {
        const isValid = validateForm();

        if (!isValid) {
            toast.error('Please fix the errors in the form');
            return;
        }

        try {
            const data = {
                ...formData,
                startTime: toLocalISOString(formData.startTime),
                endTime: toLocalISOString(formData.endTime),
                registrationDeadline: formData.registrationDeadline ? toLocalISOString(formData.registrationDeadline) : null,
                latitude: formData.latitude !== '' ? formData.latitude : null,
                longitude: formData.longitude !== '' ? formData.longitude : null,
                recurrenceEndDate: formData.recurrenceEndDate ? toLocalISOString(formData.recurrenceEndDate) : null,
            };

            if (editEvent) {
                await organiserApi.updateEvent(editEvent.id, data);
                toast.success('Event updated successfully');
            } else {
                await organiserApi.createEvent(data);
                if (formData.recurrenceType !== 'NONE') {
                    toast.success('Recurring event series created successfully');
                } else {
                    toast.success('Event created successfully');
                }
            }
            handleCloseDialog();
            loadEvents();
        } catch (error) {
            toast.error(error.response?.data?.message || 'Failed to save event');
        }
    };

    const handleCancel = () => {
        setConfirmDialog({
            open: true,
            title: 'Cancel Event',
            message: 'Are you sure you want to cancel this event? Registered users will be notified.',
            confirmColor: 'error',
            action: async () => {
                try {
                    await organiserApi.cancelEvent(selectedEvent.id);
                    toast.success('Event cancelled successfully');
                    loadEvents();
                } catch (error) {
                    toast.error('Failed to cancel event');
                }
            },
        });
    };

    const handleDelete = () => {
        setConfirmDialog({
            open: true,
            title: 'Delete Event',
            message: 'Are you sure you want to delete this event? This action cannot be undone.',
            confirmColor: 'error',
            action: async () => {
                try {
                    await organiserApi.deleteEvent(selectedEvent.id);
                    toast.success('Event deleted successfully');
                    loadEvents();
                } catch (error) {
                    toast.error('Failed to delete event');
                }
            },
        });
    };

    const handleAIGenerate = async () => {
        if (!formData.title.trim()) {
            toast.error('Please enter a title first');
            return;
        }

        // Check AI quota before using
        if (subscription) {
            const remaining = subscription.remainingAIUsage;
            if (remaining === 0) {
                setUpgradeDialog({
                    open: true,
                    message: `You have reached your monthly AI usage limit (${subscription.maxAIUsagePerMonth} generations). Upgrade your plan to use more AI features.`,
                    feature: 'AI Generation',
                });
                return;
            }
            // Warning if near quota (3 or less remaining)
            if (remaining !== -1 && remaining <= 3) {
                toast.warning(`You have ${remaining} AI generation${remaining > 1 ? 's' : ''} remaining this month.`);
            }
        }

        setAiGenerating(true);
        try {
            const selectedCategory = categories.find(c => c.id === formData.categoryId);
            const response = await organiserApi.generateEventDescription({
                title: formData.title,
                category: selectedCategory?.name || '',
                venue: formData.venue,
                address: formData.address,
                startTime: formData.startTime?.toLocaleString() || '',
                endTime: formData.endTime?.toLocaleString() || '',
            });
            setFormData({ ...formData, description: response.data.data.description });
            toast.success('Description generated!');
            // Refresh subscription to update remaining AI usage
            loadMasterData();
        } catch (error) {
            toast.error(error.response?.data?.message || 'Failed to generate description');
        } finally {
            setAiGenerating(false);
        }
    };

    const handleAIImprove = async () => {
        if (!formData.description.trim()) {
            toast.error('Please enter a description first');
            return;
        }

        // Check AI quota before using
        if (subscription) {
            const remaining = subscription.remainingAIUsage;
            if (remaining === 0) {
                setUpgradeDialog({
                    open: true,
                    message: `You have reached your monthly AI usage limit (${subscription.maxAIUsagePerMonth} generations). Upgrade your plan to use more AI features.`,
                    feature: 'AI Generation',
                });
                return;
            }
            // Warning if near quota (3 or less remaining)
            if (remaining !== -1 && remaining <= 3) {
                toast.warning(`You have ${remaining} AI generation${remaining > 1 ? 's' : ''} remaining this month.`);
            }
        }

        setAiImproving(true);
        try {
            const response = await organiserApi.improveEventDescription({
                title: formData.title,
                description: formData.description,
            });
            setFormData({ ...formData, description: response.data.data.description });
            toast.success('Description improved!');
            // Refresh subscription to update remaining AI usage
            loadMasterData();
        } catch (error) {
            toast.error(error.response?.data?.message || 'Failed to improve description');
        } finally {
            setAiImproving(false);
        }
    };

    const columns = [
        {
            field: 'title',
            headerName: 'Title',
            flex: 1,
            minWidth: 200,
            renderCell: (params) => (
                <Box sx={{ cursor: 'pointer', '&:hover': { color: 'primary.main' } }}>
                    {params.value}
                </Box>
            ),
        },
        {
            field: 'startTime',
            headerName: 'Start Date',
            width: 150,
            valueFormatter: (params) => {
                if (!params.value) return '';
                return new Date(params.value).toLocaleDateString();
            },
        },
        {
            field: 'city',
            headerName: 'City',
            width: 120,
            valueGetter: (params) => params.row.city?.name || '',
        },
        {
            field: 'status',
            headerName: 'Status',
            width: 120,
            renderCell: (params) => {
                const chip = (
                    <Chip
                        label={params.value}
                        size="small"
                        color={statusColors[params.value] || 'default'}
                    />
                );
                if (params.value === 'REJECTED' && params.row.rejectionReason) {
                    return (
                        <Tooltip title={`Reason: ${params.row.rejectionReason}`} arrow>
                            {chip}
                        </Tooltip>
                    );
                }
                return chip;
            },
        },
        {
            field: 'registrations',
            headerName: 'Registrations',
            width: 130,
            align: 'center',
            valueGetter: (params) => `${params.row.currentRegistrations || 0}/${params.row.capacity || 0}`,
        },
        {
            field: 'ticketPrice',
            headerName: 'Price',
            width: 120,
            valueGetter: (params) => {
                if (!params.row) return 'Free';
                if (params.row.isFree || !params.row.ticketPrice) return 'Free';
                return new Intl.NumberFormat('vi-VN', {
                    style: 'currency',
                    currency: 'VND',
                }).format(params.row.ticketPrice);
            },
        },
    ];

    return (
        <LocalizationProvider dateAdapter={AdapterDateFns}>
            <Box>
                {/* Near Quota Warning */}
                {subscription && subscription.remainingEvents !== -1 && subscription.remainingEvents <= 2 && subscription.remainingEvents > 0 && (
                    <Alert severity="warning" sx={{ mb: 2 }}>
                        <Typography variant="body2">
                            <strong>Warning:</strong> You only have <strong>{subscription.remainingEvents}</strong> event{subscription.remainingEvents > 1 ? 's' : ''} remaining this month.
                            <Button size="small" color="warning" onClick={() => navigate('/organiser/subscription')} sx={{ ml: 1 }}>
                                View Plans
                            </Button>
                        </Typography>
                    </Alert>
                )}
                {subscription && subscription.remainingEvents === 0 && (
                    <Alert severity="error" sx={{ mb: 2 }}>
                        <Typography variant="body2">
                            <strong>Limit Reached:</strong> You have used all your event quota ({subscription.maxEventsPerMonth} events) for this month.
                            <Button size="small" color="error" onClick={() => navigate('/organiser/subscription')} sx={{ ml: 1 }}>
                                Upgrade Now
                            </Button>
                        </Typography>
                    </Alert>
                )}

                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                    <Typography variant="h5" fontWeight="bold">
                        My Events
                    </Typography>
                    <Box sx={{ display: 'flex', gap: 1 }}>
                        <Button startIcon={<RefreshIcon />} onClick={loadEvents}>
                            Refresh
                        </Button>
                        <Button
                            variant="contained"
                            startIcon={<AddIcon />}
                            onClick={() => handleOpenDialog()}
                        >
                            Create Event
                        </Button>
                    </Box>
                </Box>

                <Paper>
                    <DataGrid
                        rows={events}
                        columns={columns}
                        loading={loading}
                        paginationModel={paginationModel}
                        onPaginationModelChange={setPaginationModel}
                        pageSizeOptions={[10, 25, 50]}
                        rowCount={totalRows}
                        paginationMode="server"
                        onRowClick={handleRowClick}
                        disableRowSelectionOnClick
                        autoHeight
                        sx={{
                            '& .MuiDataGrid-row': {
                                cursor: 'pointer',
                            },
                        }}
                    />
                </Paper>

                <Dialog open={dialogOpen} onClose={handleCloseDialog} maxWidth="md" fullWidth>
                    <DialogTitle>{editEvent ? 'Edit Event' : 'Create Event'}</DialogTitle>
                    <DialogContent>
                        {editEvent?.status === 'REJECTED' && (
                            <Alert severity="warning" sx={{ mb: 2, mt: 1 }}>
                                <Typography variant="subtitle2" fontWeight="bold">
                                    This event was rejected by admin
                                </Typography>
                                {editEvent.rejectionReason && (
                                    <Typography variant="body2" sx={{ mt: 0.5 }}>
                                        Reason: {editEvent.rejectionReason}
                                    </Typography>
                                )}
                                <Typography variant="body2" sx={{ mt: 0.5 }}>
                                    Please make the necessary changes and save to re-submit for approval.
                                </Typography>
                            </Alert>
                        )}
                        <Grid container spacing={2} sx={{ mt: editEvent?.status === 'REJECTED' ? 0 : 1 }}>
                            <Grid item xs={12}>
                                <TextField
                                    fullWidth
                                    label="Title"
                                    value={formData.title}
                                    onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                                    required
                                    error={!!formErrors.title}
                                    helperText={formErrors.title}
                                />
                            </Grid>
                            <Grid item xs={12}>
                                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 0.5 }}>
                                    <Typography variant="subtitle2">
                                        Description *
                                    </Typography>
                                    <Box sx={{ display: 'flex', gap: 1 }}>
                                        <Button
                                            size="small"
                                            variant="outlined"
                                            color="secondary"
                                            startIcon={<AIIcon />}
                                            onClick={handleAIGenerate}
                                            disabled={aiGenerating || !formData.title.trim()}
                                        >
                                            {aiGenerating ? 'Generating...' : 'AI Generate'}
                                        </Button>
                                        <Button
                                            size="small"
                                            variant="outlined"
                                            color="secondary"
                                            startIcon={<AIIcon />}
                                            onClick={handleAIImprove}
                                            disabled={aiImproving || !formData.description.trim()}
                                        >
                                            {aiImproving ? 'Improving...' : 'AI Improve'}
                                        </Button>
                                    </Box>
                                </Box>
                                <Box data-color-mode="light">
                                    <MDEditor
                                        value={formData.description}
                                        onChange={(val) => setFormData({ ...formData, description: val || '' })}
                                        height={300}
                                        preview="edit"
                                    />
                                </Box>
                                {formErrors.description && (
                                    <Typography variant="caption" color="error" sx={{ mt: 0.5, display: 'block' }}>
                                        {formErrors.description}
                                    </Typography>
                                )}
                                {!formErrors.description && (
                                    <Typography variant="caption" color="text.secondary" sx={{ mt: 0.5, display: 'block' }}>
                                        Supports Markdown formatting. Minimum 20 characters. Use AI buttons to generate or improve.
                                    </Typography>
                                )}
                            </Grid>
                            <Grid item xs={12}>
                                <ImageUpload
                                    value={formData.imageUrl}
                                    onChange={(url) => setFormData({ ...formData, imageUrl: url })}
                                    label="Event Image"
                                    folder="luma/events"
                                    helperText="Upload an attractive image for your event"
                                />
                            </Grid>
                            <Grid item xs={12} md={6}>
                                <TextField
                                    fullWidth
                                    label="Venue"
                                    value={formData.venue}
                                    onChange={(e) => setFormData({ ...formData, venue: e.target.value })}
                                    required
                                    error={!!formErrors.venue}
                                    helperText={formErrors.venue}
                                />
                            </Grid>
                            <Grid item xs={12} md={6}>
                                <TextField
                                    fullWidth
                                    label="Address"
                                    value={formData.address}
                                    onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                                    required
                                    error={!!formErrors.address}
                                    helperText={formErrors.address}
                                />
                            </Grid>
                            <Grid item xs={12}>
                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 1 }}>
                                    <Typography variant="body2" color="text.secondary">
                                        Coordinates (optional)
                                    </Typography>
                                    <Tooltip title="Auto-fill coordinates from address">
                                        <Button
                                            size="small"
                                            variant="outlined"
                                            startIcon={<LocationIcon />}
                                            onClick={handleGeocodeAddress}
                                            disabled={geocoding || !formData.address.trim()}
                                        >
                                            {geocoding ? 'Getting...' : 'Get Coordinates'}
                                        </Button>
                                    </Tooltip>
                                </Box>
                            </Grid>
                            <Grid item xs={12} md={6}>
                                <TextField
                                    fullWidth
                                    label="Latitude"
                                    type="number"
                                    value={formData.latitude}
                                    onChange={(e) => setFormData({ ...formData, latitude: e.target.value ? parseFloat(e.target.value) : '' })}
                                    error={!!formErrors.latitude}
                                    helperText={formErrors.latitude || "Auto-filled from address or enter manually"}
                                    inputProps={{ step: 'any', min: -90, max: 90 }}
                                />
                            </Grid>
                            <Grid item xs={12} md={6}>
                                <TextField
                                    fullWidth
                                    label="Longitude"
                                    type="number"
                                    value={formData.longitude}
                                    onChange={(e) => setFormData({ ...formData, longitude: e.target.value ? parseFloat(e.target.value) : '' })}
                                    error={!!formErrors.longitude}
                                    helperText={formErrors.longitude || "Auto-filled from address or enter manually"}
                                    inputProps={{ step: 'any', min: -180, max: 180 }}
                                />
                            </Grid>
                            <Grid item xs={12} md={4}>
                                <DateTimePicker
                                    label="Start Time"
                                    value={formData.startTime}
                                    onChange={(value) => setFormData({ ...formData, startTime: value })}
                                    slotProps={{
                                        textField: {
                                            fullWidth: true,
                                            required: true,
                                            error: !!formErrors.startTime,
                                            helperText: formErrors.startTime
                                        }
                                    }}
                                    minDateTime={new Date()}
                                />
                            </Grid>
                            <Grid item xs={12} md={4}>
                                <DateTimePicker
                                    label="End Time"
                                    value={formData.endTime}
                                    onChange={(value) => setFormData({ ...formData, endTime: value })}
                                    slotProps={{
                                        textField: {
                                            fullWidth: true,
                                            required: true,
                                            error: !!formErrors.endTime,
                                            helperText: formErrors.endTime
                                        }
                                    }}
                                    minDateTime={formData.startTime}
                                />
                            </Grid>
                            <Grid item xs={12} md={4}>
                                <DateTimePicker
                                    label="Registration Deadline"
                                    value={formData.registrationDeadline}
                                    onChange={(value) => setFormData({ ...formData, registrationDeadline: value })}
                                    slotProps={{
                                        textField: {
                                            fullWidth: true,
                                            required: true,
                                            error: !!formErrors.registrationDeadline,
                                            helperText: formErrors.registrationDeadline || 'Must be before start time'
                                        }
                                    }}
                                    minDateTime={new Date()}
                                    maxDateTime={formData.startTime}
                                />
                            </Grid>
                            <Grid item xs={12} md={6}>
                                <Autocomplete
                                    options={categories}
                                    getOptionLabel={(option) => option.name || ''}
                                    value={categories.find(cat => cat.id === formData.categoryId) || null}
                                    onChange={(e, newValue) => setFormData({ ...formData, categoryId: newValue?.id || '' })}
                                    renderInput={(params) => (
                                        <TextField
                                            {...params}
                                            label="Category"
                                            required
                                            error={!!formErrors.categoryId}
                                            helperText={formErrors.categoryId}
                                        />
                                    )}
                                    isOptionEqualToValue={(option, value) => option.id === value?.id}
                                />
                            </Grid>
                            <Grid item xs={12} md={6}>
                                <Autocomplete
                                    options={cities}
                                    getOptionLabel={(option) => option.name || ''}
                                    value={cities.find(city => city.id === formData.cityId) || null}
                                    onChange={(e, newValue) => setFormData({ ...formData, cityId: newValue?.id || '' })}
                                    renderInput={(params) => (
                                        <TextField
                                            {...params}
                                            label="City"
                                            required
                                            error={!!formErrors.cityId}
                                            helperText={formErrors.cityId}
                                        />
                                    )}
                                    isOptionEqualToValue={(option, value) => option.id === value?.id}
                                />
                            </Grid>
                            <Grid item xs={12} md={4}>
                                <TextField
                                    fullWidth
                                    label="Capacity"
                                    type="number"
                                    value={formData.capacity}
                                    onChange={(e) => setFormData({ ...formData, capacity: parseInt(e.target.value) || 0 })}
                                    required
                                    error={!!formErrors.capacity}
                                    helperText={formErrors.capacity}
                                    inputProps={{ min: 1, max: 100000 }}
                                />
                            </Grid>
                            <Grid item xs={12} md={4}>
                                <TextField
                                    fullWidth
                                    label="Price (VND)"
                                    type="number"
                                    value={formData.ticketPrice}
                                    onChange={(e) => {
                                        const price = parseFloat(e.target.value) || 0;
                                        setFormData({ ...formData, ticketPrice: price, isFree: price === 0 });
                                    }}
                                    error={!!formErrors.ticketPrice}
                                    helperText={formErrors.ticketPrice || '0 for free event'}
                                    inputProps={{ min: 0 }}
                                />
                            </Grid>
                            <Grid item xs={12} md={4}>
                                <FormControl fullWidth>
                                    <InputLabel>Visibility</InputLabel>
                                    <Select
                                        value={formData.visibility}
                                        onChange={(e) => setFormData({ ...formData, visibility: e.target.value })}
                                        label="Visibility"
                                    >
                                        <MenuItem value="PUBLIC">Public</MenuItem>
                                        <MenuItem value="PRIVATE">Private</MenuItem>
                                    </Select>
                                </FormControl>
                            </Grid>
                            <Grid item xs={12}>
                                <Box sx={{ mt: 2, pt: 2, borderTop: '1px solid', borderColor: 'divider' }}>
                                    <SpeakerForm
                                        speakers={formData.speakers}
                                        onChange={(speakers) => setFormData({ ...formData, speakers })}
                                        errors={formErrors.speakers || []}
                                        eventTitle={formData.title}
                                        subscription={subscription}
                                        onAIUsed={loadMasterData}
                                        onUpgradeNeeded={(data) => setUpgradeDialog({ open: true, ...data })}
                                    />
                                </Box>
                            </Grid>

                            <Grid item xs={12}>
                                <Box sx={{ mt: 2, pt: 2, borderTop: '1px solid', borderColor: 'divider' }}>
                                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                                        <RepeatIcon color="action" />
                                        <Typography variant="subtitle1" fontWeight="bold">
                                            Recurring Event
                                        </Typography>
                                        {editEvent && formData.recurrenceType !== 'NONE' && (
                                            <Chip
                                                label={`Occurrence ${editEvent.occurrenceIndex || 1}/${editEvent.totalOccurrences || 1}`}
                                                size="small"
                                                color="primary"
                                            />
                                        )}
                                    </Box>

                                    <Grid container spacing={2}>
                                        <Grid item xs={12} md={6}>
                                            <FormControl fullWidth>
                                                <InputLabel>Repeat</InputLabel>
                                                <Select
                                                    value={formData.recurrenceType}
                                                    onChange={(e) => setFormData({
                                                        ...formData,
                                                        recurrenceType: e.target.value,
                                                        recurrenceDaysOfWeek: e.target.value === 'NONE' ? [] : formData.recurrenceDaysOfWeek
                                                    })}
                                                    label="Repeat"
                                                    disabled={editEvent && editEvent.totalOccurrences > 1}
                                                >
                                                    {recurrenceTypes.map((type) => (
                                                        <MenuItem key={type.value} value={type.value}>
                                                            {type.label}
                                                        </MenuItem>
                                                    ))}
                                                </Select>
                                                {editEvent && editEvent.totalOccurrences > 1 && (
                                                    <Typography variant="caption" color="text.secondary" sx={{ mt: 0.5 }}>
                                                        Cannot change recurrence type for existing series
                                                    </Typography>
                                                )}
                                            </FormControl>
                                        </Grid>

                                        {formData.recurrenceType !== 'NONE' && (
                                            <>
                                                <Grid item xs={12} md={6}>
                                                    <TextField
                                                        fullWidth
                                                        label="Number of occurrences"
                                                        type="number"
                                                        value={formData.recurrenceCount || ''}
                                                        onChange={(e) => setFormData({
                                                            ...formData,
                                                            recurrenceCount: e.target.value ? parseInt(e.target.value) : null
                                                        })}
                                                        helperText="Max 52 occurrences (1 year)"
                                                        inputProps={{ min: 1, max: 52 }}
                                                        disabled={editEvent && editEvent.totalOccurrences > 1}
                                                    />
                                                </Grid>

                                                {formData.recurrenceType === 'WEEKLY' && (
                                                    <Grid item xs={12}>
                                                        <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                                                            Repeat on days:
                                                        </Typography>
                                                        <FormGroup row>
                                                            {daysOfWeek.map((day) => (
                                                                <FormControlLabel
                                                                    key={day.value}
                                                                    control={
                                                                        <Checkbox
                                                                            checked={formData.recurrenceDaysOfWeek.includes(day.value)}
                                                                            onChange={(e) => {
                                                                                const newDays = e.target.checked
                                                                                    ? [...formData.recurrenceDaysOfWeek, day.value]
                                                                                    : formData.recurrenceDaysOfWeek.filter(d => d !== day.value);
                                                                                setFormData({ ...formData, recurrenceDaysOfWeek: newDays });
                                                                            }}
                                                                            disabled={editEvent && editEvent.totalOccurrences > 1}
                                                                        />
                                                                    }
                                                                    label={day.label}
                                                                />
                                                            ))}
                                                        </FormGroup>
                                                    </Grid>
                                                )}

                                                <Grid item xs={12} md={6}>
                                                    <DateTimePicker
                                                        label="End recurring on (optional)"
                                                        value={formData.recurrenceEndDate}
                                                        onChange={(value) => setFormData({ ...formData, recurrenceEndDate: value })}
                                                        slotProps={{
                                                            textField: {
                                                                fullWidth: true,
                                                                helperText: 'Leave empty to use occurrence count'
                                                            }
                                                        }}
                                                        minDateTime={formData.startTime}
                                                        disabled={editEvent && editEvent.totalOccurrences > 1}
                                                    />
                                                </Grid>
                                            </>
                                        )}
                                    </Grid>

                                    {!editEvent && formData.recurrenceType !== 'NONE' && (
                                        <Alert severity="info" sx={{ mt: 2 }}>
                                            This will create multiple event instances. Each instance will have its own registrations.
                                        </Alert>
                                    )}
                                    {editEvent && editEvent.totalOccurrences > 1 && formData.recurrenceType !== 'NONE' && (
                                        <Alert severity="info" sx={{ mt: 2 }}>
                                            This event is part of a recurring series with {editEvent.totalOccurrences} occurrences. Recurrence settings cannot be modified.
                                        </Alert>
                                    )}
                                </Box>
                            </Grid>
                        </Grid>
                    </DialogContent>
                    <DialogActions>
                        <Button onClick={handleCloseDialog}>Cancel</Button>
                        <Button onClick={handleSubmit} variant="contained">
                            {editEvent ? 'Update' : 'Create'}
                        </Button>
                    </DialogActions>
                </Dialog>

                <Drawer
                    anchor="right"
                    open={quickViewOpen}
                    onClose={() => setQuickViewOpen(false)}
                    PaperProps={{ sx: { width: { xs: '100%', sm: 450 } } }}
                >
                    {quickViewEvent && (
                        <Box sx={{ p: 3 }}>
                            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
                                <Typography variant="h6" fontWeight="bold">Event Details</Typography>
                                <IconButton onClick={() => setQuickViewOpen(false)}>
                                    <CloseIcon />
                                </IconButton>
                            </Box>
                            <Divider sx={{ mb: 2 }} />

                            {quickViewEvent.imageUrl && (
                                <Box sx={{ mb: 2, borderRadius: 2, overflow: 'hidden' }}>
                                    <img
                                        src={quickViewEvent.imageUrl}
                                        alt={quickViewEvent.title}
                                        style={{ width: '100%', height: 180, objectFit: 'cover' }}
                                    />
                                </Box>
                            )}

                            <Typography variant="h6" gutterBottom>{quickViewEvent.title}</Typography>
                            <Chip
                                label={quickViewEvent.status}
                                color={statusColors[quickViewEvent.status] || 'default'}
                                size="small"
                                sx={{ mb: 2 }}
                            />

                            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                    <ScheduleIcon color="action" fontSize="small" />
                                    <Box>
                                        <Typography variant="caption" color="text.secondary">Date & Time</Typography>
                                        <Typography variant="body2">
                                            {new Date(quickViewEvent.startTime).toLocaleString()} - {new Date(quickViewEvent.endTime).toLocaleString()}
                                        </Typography>
                                    </Box>
                                </Box>

                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                    <LocationOnIcon color="action" fontSize="small" />
                                    <Box>
                                        <Typography variant="caption" color="text.secondary">Location</Typography>
                                        <Typography variant="body2">{quickViewEvent.venue}</Typography>
                                        <Typography variant="caption" color="text.secondary">{quickViewEvent.address}</Typography>
                                    </Box>
                                </Box>

                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                    <CategoryIcon color="action" fontSize="small" />
                                    <Box>
                                        <Typography variant="caption" color="text.secondary">Category</Typography>
                                        <Typography variant="body2">{quickViewEvent.category?.name || 'N/A'}</Typography>
                                    </Box>
                                </Box>

                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                    <PeopleIcon color="action" fontSize="small" />
                                    <Box>
                                        <Typography variant="caption" color="text.secondary">Registrations</Typography>
                                        <Typography variant="body2">
                                            {quickViewEvent.currentRegistrations || 0} / {quickViewEvent.capacity}
                                        </Typography>
                                    </Box>
                                </Box>

                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                    <MoneyIcon color="action" fontSize="small" />
                                    <Box>
                                        <Typography variant="caption" color="text.secondary">Price</Typography>
                                        <Typography variant="body2">
                                            {quickViewEvent.isFree ? 'Free' : new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(quickViewEvent.ticketPrice)}
                                        </Typography>
                                    </Box>
                                </Box>
                            </Box>

                            <Divider sx={{ my: 2 }} />

                            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                                <Box sx={{ display: 'flex', gap: 1 }}>
                                    <Button
                                        fullWidth
                                        variant="outlined"
                                        startIcon={<EditIcon />}
                                        onClick={() => {
                                            setQuickViewOpen(false);
                                            handleOpenDialog(quickViewEvent);
                                        }}
                                    >
                                        Edit
                                    </Button>
                                    {quickViewEvent.status === 'PUBLISHED' && (
                                        <Button
                                            fullWidth
                                            variant="contained"
                                            color="warning"
                                            startIcon={<CancelIcon />}
                                            onClick={() => {
                                                setSelectedEvent(quickViewEvent);
                                                setQuickViewOpen(false);
                                                handleCancel();
                                            }}
                                        >
                                            Cancel
                                        </Button>
                                    )}
                                </Box>
                                {(quickViewEvent.status === 'DRAFT' || quickViewEvent.status === 'CANCELLED') && (
                                    <Button
                                        fullWidth
                                        variant="outlined"
                                        color="error"
                                        onClick={() => {
                                            setSelectedEvent(quickViewEvent);
                                            setQuickViewOpen(false);
                                            handleDelete();
                                        }}
                                    >
                                        Delete Event
                                    </Button>
                                )}
                            </Box>
                        </Box>
                    )}
                </Drawer>

                <ConfirmDialog
                    open={confirmDialog.open}
                    title={confirmDialog.title}
                    message={confirmDialog.message}
                    confirmColor={confirmDialog.confirmColor}
                    onConfirm={() => {
                        confirmDialog.action?.();
                        setConfirmDialog({ ...confirmDialog, open: false });
                    }}
                    onCancel={() => setConfirmDialog({ ...confirmDialog, open: false })}
                />

                <UpgradeDialog
                    open={upgradeDialog.open}
                    onClose={() => setUpgradeDialog({ ...upgradeDialog, open: false })}
                    title="Upgrade Required"
                    message={upgradeDialog.message}
                    feature={upgradeDialog.feature}
                />
            </Box>
        </LocalizationProvider>
    );
};

export default OrganiserEvents;

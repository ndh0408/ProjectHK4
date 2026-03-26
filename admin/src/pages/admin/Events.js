import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Typography,
    Paper,
    TextField,
    InputAdornment,
    IconButton,
    Chip,
    Menu,
    MenuItem,
    Button,
    FormControl,
    InputLabel,
    Select,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    Grid,
    Divider,
    Avatar,
    CircularProgress,
} from '@mui/material';
import { DataGrid } from '@mui/x-data-grid';
import {
    Search as SearchIcon,
    MoreVert as MoreVertIcon,
    Refresh as RefreshIcon,
    Event as EventIcon,
    LocationOn as LocationIcon,
    Person as PersonIcon,
    Category as CategoryIcon,
    AttachMoney as MoneyIcon,
    People as PeopleIcon,
    AutoAwesome as AIIcon,
    CheckCircle as ApproveIcon,
    Cancel as RejectIcon,
    Warning as WarningIcon,
    Lightbulb as TipIcon,
    Repeat as RepeatIcon,
} from '@mui/icons-material';
import MDEditor from '@uiw/react-md-editor';
import { adminApi } from '../../api';
import { ConfirmDialog } from '../../components/common';
import { toast } from 'react-toastify';

const statusColors = {
    DRAFT: 'default',
    PUBLISHED: 'success',
    CANCELLED: 'error',
    COMPLETED: 'info',
    REJECTED: 'warning',
};

const Events = () => {
    const [events, setEvents] = useState([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');
    const [statusFilter, setStatusFilter] = useState('');
    const [paginationModel, setPaginationModel] = useState({ page: 0, pageSize: 10 });
    const [totalRows, setTotalRows] = useState(0);
    const [anchorEl, setAnchorEl] = useState(null);
    const [selectedEvent, setSelectedEvent] = useState(null);
    const [confirmDialog, setConfirmDialog] = useState({ open: false, title: '', message: '', action: null });
    const [detailDialog, setDetailDialog] = useState({ open: false, event: null, loading: false });
    const [rejectDialog, setRejectDialog] = useState({ open: false, reason: '', loading: false });
    const [aiAnalysis, setAiAnalysis] = useState(null);
    const [aiLoading, setAiLoading] = useState(false);
    const [aiReasonLoading, setAiReasonLoading] = useState(false);

    const loadEvents = useCallback(async () => {
        setLoading(true);
        try {
            const response = await adminApi.getEvents({
                page: paginationModel.page,
                size: paginationModel.pageSize,
                search: search || undefined,
                status: statusFilter || undefined,
            });
            setEvents(response.data.data.content || []);
            setTotalRows(response.data.data.totalElements || 0);
        } catch (error) {
            toast.error('Failed to load events');
        } finally {
            setLoading(false);
        }
    }, [paginationModel, search, statusFilter]);

    useEffect(() => {
        loadEvents();
    }, [loadEvents]);

    const handleMenuOpen = (event, eventData) => {
        setAnchorEl(event.currentTarget);
        setSelectedEvent(eventData);
    };

    const handleMenuClose = () => {
        setAnchorEl(null);
    };

    const handleViewDetails = async () => {
        handleMenuClose();
        setDetailDialog({ open: true, event: null, loading: true });
        setAiAnalysis(null);
        try {
            const response = await adminApi.getEventById(selectedEvent.id);
            setDetailDialog({ open: true, event: response.data.data, loading: false });
        } catch (error) {
            toast.error('Failed to load event details');
            setDetailDialog({ open: false, event: null, loading: false });
        }
    };

    const handleAIAnalyze = async () => {
        if (!detailDialog.event) return;
        setAiLoading(true);
        try {
            const response = await adminApi.analyzeEvent(detailDialog.event.id);
            setAiAnalysis(response.data.data);
            toast.success('AI analysis completed');
        } catch (error) {
            toast.error('Failed to analyze event');
        } finally {
            setAiLoading(false);
        }
    };

    const handleAIGenerateReason = async () => {
        if (!selectedEvent) return;
        setAiReasonLoading(true);
        try {
            const response = await adminApi.generateRejectionReason({
                eventId: selectedEvent.id,
                concerns: aiAnalysis?.concerns?.join(', ') || '',
            });
            setRejectDialog(prev => ({ ...prev, reason: response.data.data.reason }));
            toast.success('Rejection reason generated');
        } catch (error) {
            toast.error('Failed to generate reason');
        } finally {
            setAiReasonLoading(false);
        }
    };

    const handleApprove = async () => {
        handleMenuClose();
        setConfirmDialog({
            open: true,
            title: 'Approve Event',
            message: 'Are you sure you want to approve this event? It will be published and visible to users.',
            action: async () => {
                try {
                    await adminApi.approveEvent(selectedEvent.id);
                    toast.success('Event approved successfully');
                    loadEvents();
                } catch (error) {
                    toast.error('Failed to approve event');
                }
            },
        });
    };

    const handleReject = () => {
        handleMenuClose();
        setRejectDialog({ open: true, reason: '', loading: false });
    };

    const handleRejectSubmit = async () => {
        setRejectDialog(prev => ({ ...prev, loading: true }));
        try {
            await adminApi.rejectEvent(selectedEvent.id, rejectDialog.reason);
            toast.success('Event rejected');
            setRejectDialog({ open: false, reason: '', loading: false });
            loadEvents();
        } catch (error) {
            toast.error('Failed to reject event: ' + (error.response?.data?.message || error.message));
            setRejectDialog(prev => ({ ...prev, loading: false }));
        }
    };

    const handleDelete = () => {
        handleMenuClose();
        setConfirmDialog({
            open: true,
            title: 'Delete Event',
            message: 'Are you sure you want to delete this event? This action cannot be undone.',
            confirmColor: 'error',
            action: async () => {
                try {
                    await adminApi.deleteEvent(selectedEvent.id);
                    toast.success('Event deleted successfully');
                    loadEvents();
                } catch (error) {
                    toast.error('Failed to delete event');
                }
            },
        });
    };

    const formatDateTime = (dateString) => {
        if (!dateString) return '';
        return new Date(dateString).toLocaleString();
    };

    const formatPrice = (price, isFree) => {
        if (isFree || !price) return 'Free';
        return new Intl.NumberFormat('vi-VN', {
            style: 'currency',
            currency: 'VND',
        }).format(price);
    };

    const columns = [
        {
            field: 'title',
            headerName: 'Event',
            flex: 1,
            minWidth: 250,
            renderCell: (params) => (
                <Box>
                    <Typography variant="body2" fontWeight="medium" noWrap>
                        {params.row.title}
                    </Typography>
                    <Typography variant="caption" color="text.secondary">
                        {params.row.organiser?.fullName ||
                         params.row.organiser?.email?.split('@')[0] || 'N/A'}
                    </Typography>
                </Box>
            ),
        },
        {
            field: 'startTime',
            headerName: 'Date',
            width: 110,
            valueGetter: (params) => {
                if (!params.row?.startTime) return '';
                return new Date(params.row.startTime).toLocaleDateString();
            },
        },
        {
            field: 'status',
            headerName: 'Status',
            width: 110,
            renderCell: (params) => (
                <Chip
                    label={params.value}
                    size="small"
                    color={statusColors[params.value] || 'default'}
                />
            ),
        },
        {
            field: 'registrations',
            headerName: 'Regs',
            width: 80,
            align: 'center',
            renderCell: (params) => {
                if (!params.row) return <Typography variant="body2">0</Typography>;
                const current = params.row.approvedCount || params.row.currentRegistrations || 0;
                const capacity = params.row.capacity;
                if (!capacity || capacity === 0) {
                    return (
                        <Typography variant="body2" title="Unlimited capacity">
                            {current}/∞
                        </Typography>
                    );
                }
                return (
                    <Typography variant="body2">
                        {current}/{capacity}
                    </Typography>
                );
            },
        },
        {
            field: 'actions',
            headerName: '',
            width: 50,
            sortable: false,
            renderCell: (params) => (
                <IconButton
                    size="small"
                    onClick={(e) => handleMenuOpen(e, params.row)}
                >
                    <MoreVertIcon />
                </IconButton>
            ),
        },
    ];

    return (
        <Box>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                <Typography variant="h5" fontWeight="bold">
                    Event Management
                </Typography>
                <Button startIcon={<RefreshIcon />} onClick={loadEvents}>
                    Refresh
                </Button>
            </Box>

            <Paper sx={{ p: 2, mb: 2 }}>
                <Box sx={{ display: 'flex', gap: 2 }}>
                    <TextField
                        placeholder="Search events..."
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                        size="small"
                        sx={{ width: 300 }}
                        InputProps={{
                            startAdornment: (
                                <InputAdornment position="start">
                                    <SearchIcon />
                                </InputAdornment>
                            ),
                        }}
                    />
                    <FormControl size="small" sx={{ minWidth: 150 }}>
                        <InputLabel>Status</InputLabel>
                        <Select
                            value={statusFilter}
                            onChange={(e) => setStatusFilter(e.target.value)}
                            label="Status"
                        >
                            <MenuItem value="">All</MenuItem>
                            <MenuItem value="DRAFT">Draft (Pending)</MenuItem>
                            <MenuItem value="PUBLISHED">Published</MenuItem>
                            <MenuItem value="REJECTED">Rejected</MenuItem>
                            <MenuItem value="CANCELLED">Cancelled</MenuItem>
                            <MenuItem value="COMPLETED">Completed</MenuItem>
                        </Select>
                    </FormControl>
                </Box>
            </Paper>

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
                    disableRowSelectionOnClick
                    autoHeight
                />
            </Paper>

            <Menu anchorEl={anchorEl} open={Boolean(anchorEl)} onClose={handleMenuClose}>
                <MenuItem onClick={handleViewDetails}>View Details</MenuItem>
                <Divider />
                {selectedEvent?.status === 'DRAFT' && (
                    <>
                        <MenuItem onClick={handleApprove} sx={{ color: 'success.main' }}>
                            Approve
                        </MenuItem>
                        <MenuItem onClick={handleReject} sx={{ color: 'warning.main' }}>
                            Reject
                        </MenuItem>
                        <Divider />
                    </>
                )}
                <MenuItem onClick={handleDelete} sx={{ color: 'error.main' }}>Delete</MenuItem>
            </Menu>

            <Dialog
                open={detailDialog.open}
                onClose={() => setDetailDialog({ open: false, event: null, loading: false })}
                maxWidth="md"
                fullWidth
            >
                <DialogTitle>
                    Event Details
                </DialogTitle>
                <DialogContent dividers>
                    {detailDialog.loading ? (
                        <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
                            <CircularProgress />
                        </Box>
                    ) : detailDialog.event ? (
                        <Grid container spacing={3}>
                            {detailDialog.event.imageUrl && (
                                <Grid item xs={12}>
                                    <Box
                                        component="img"
                                        src={detailDialog.event.imageUrl}
                                        alt={detailDialog.event.title}
                                        sx={{
                                            width: '100%',
                                            maxHeight: 300,
                                            objectFit: 'cover',
                                            borderRadius: 2,
                                        }}
                                    />
                                </Grid>
                            )}

                            <Grid item xs={12}>
                                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                    <Typography variant="h5" fontWeight="bold">
                                        {detailDialog.event.title}
                                    </Typography>
                                    <Chip
                                        label={detailDialog.event.status}
                                        color={statusColors[detailDialog.event.status] || 'default'}
                                    />
                                </Box>
                            </Grid>

                            <Grid item xs={12}>
                                <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                                    Description
                                </Typography>
                                <Box data-color-mode="light" sx={{
                                    '& .wmde-markdown': {
                                        backgroundColor: 'transparent',
                                        fontSize: '14px',
                                    }
                                }}>
                                    <MDEditor.Markdown
                                        source={detailDialog.event.description || 'No description'}
                                        style={{ backgroundColor: 'transparent' }}
                                    />
                                </Box>
                            </Grid>

                            <Grid item xs={12}>
                                <Divider />
                            </Grid>

                            <Grid item xs={12} md={6}>
                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                                    <EventIcon color="primary" />
                                    <Box>
                                        <Typography variant="caption" color="text.secondary">Date & Time</Typography>
                                        <Typography variant="body2">
                                            {formatDateTime(detailDialog.event.startTime)} - {formatDateTime(detailDialog.event.endTime)}
                                        </Typography>
                                    </Box>
                                </Box>
                            </Grid>

                            <Grid item xs={12} md={6}>
                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                                    <LocationIcon color="primary" />
                                    <Box>
                                        <Typography variant="caption" color="text.secondary">Location</Typography>
                                        <Typography variant="body2">
                                            {detailDialog.event.venue}, {detailDialog.event.address}
                                        </Typography>
                                        <Typography variant="body2" color="text.secondary">
                                            {detailDialog.event.city?.name}
                                        </Typography>
                                    </Box>
                                </Box>
                            </Grid>

                            <Grid item xs={12} md={6}>
                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                                    <CategoryIcon color="primary" />
                                    <Box>
                                        <Typography variant="caption" color="text.secondary">Category</Typography>
                                        <Typography variant="body2">
                                            {detailDialog.event.category?.name}
                                        </Typography>
                                    </Box>
                                </Box>
                            </Grid>

                            <Grid item xs={12} md={6}>
                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                                    <MoneyIcon color="primary" />
                                    <Box>
                                        <Typography variant="caption" color="text.secondary">Price</Typography>
                                        <Typography variant="body2">
                                            {formatPrice(detailDialog.event.ticketPrice, detailDialog.event.isFree)}
                                        </Typography>
                                    </Box>
                                </Box>
                            </Grid>

                            <Grid item xs={12} md={6}>
                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                                    <PeopleIcon color="primary" />
                                    <Box>
                                        <Typography variant="caption" color="text.secondary">Capacity</Typography>
                                        <Typography variant="body2">
                                            {detailDialog.event.approvedCount || 0} / {detailDialog.event.capacity || 'Unlimited'}
                                        </Typography>
                                    </Box>
                                </Box>
                            </Grid>

                            <Grid item xs={12} md={6}>
                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                                    <PersonIcon color="primary" />
                                    <Box>
                                        <Typography variant="caption" color="text.secondary">Organiser</Typography>
                                        <Typography variant="body2">
                                            {detailDialog.event.organiser?.fullName ||
                                             detailDialog.event.organiser?.organizationName ||
                                             (detailDialog.event.organiser?.email &&
                                                detailDialog.event.organiser.email.split('@')[0]
                                                    .split(/[._-]/)
                                                    .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
                                                    .join(' ')
                                             ) || 'N/A'}
                                        </Typography>
                                    </Box>
                                </Box>
                            </Grid>

                            {detailDialog.event.isRecurring && (
                                <Grid item xs={12}>
                                    <Divider sx={{ my: 2 }} />
                                    <Box sx={{
                                        p: 2,
                                        bgcolor: 'primary.50',
                                        borderRadius: 2,
                                        border: '1px solid',
                                        borderColor: 'primary.200'
                                    }}>
                                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                                            <RepeatIcon color="primary" />
                                            <Typography variant="h6" color="primary">
                                                Recurring Event
                                            </Typography>
                                            <Chip
                                                label={`${detailDialog.event.occurrenceIndex || 1}/${detailDialog.event.totalOccurrences || 1}`}
                                                size="small"
                                                color="primary"
                                            />
                                        </Box>
                                        <Grid container spacing={2}>
                                            <Grid item xs={6} md={3}>
                                                <Typography variant="caption" color="text.secondary">Recurrence Type</Typography>
                                                <Typography variant="body2" fontWeight="medium">
                                                    {{
                                                        DAILY: 'Daily',
                                                        WEEKLY: 'Weekly',
                                                        BIWEEKLY: 'Biweekly',
                                                        MONTHLY: 'Monthly',
                                                    }[detailDialog.event.recurrenceType] || detailDialog.event.recurrenceType}
                                                </Typography>
                                            </Grid>
                                            <Grid item xs={6} md={3}>
                                                <Typography variant="caption" color="text.secondary">Interval</Typography>
                                                <Typography variant="body2" fontWeight="medium">
                                                    {detailDialog.event.recurrenceInterval || 1}
                                                </Typography>
                                            </Grid>
                                            {detailDialog.event.recurrenceCount && (
                                                <Grid item xs={6} md={3}>
                                                    <Typography variant="caption" color="text.secondary">Total Occurrences</Typography>
                                                    <Typography variant="body2" fontWeight="medium">
                                                        {detailDialog.event.recurrenceCount} times
                                                    </Typography>
                                                </Grid>
                                            )}
                                            {detailDialog.event.recurrenceEndDate && (
                                                <Grid item xs={6} md={3}>
                                                    <Typography variant="caption" color="text.secondary">End Date</Typography>
                                                    <Typography variant="body2" fontWeight="medium">
                                                        {new Date(detailDialog.event.recurrenceEndDate).toLocaleDateString('en-US')}
                                                    </Typography>
                                                </Grid>
                                            )}
                                            {detailDialog.event.recurrenceDaysOfWeek && detailDialog.event.recurrenceDaysOfWeek.length > 0 && (
                                                <Grid item xs={12}>
                                                    <Typography variant="caption" color="text.secondary">Days of Week</Typography>
                                                    <Box sx={{ display: 'flex', gap: 1, mt: 0.5, flexWrap: 'wrap' }}>
                                                        {detailDialog.event.recurrenceDaysOfWeek.map((day, idx) => {
                                                            const dayLabels = {
                                                                MON: 'Mon', TUE: 'Tue', WED: 'Wed', THU: 'Thu',
                                                                FRI: 'Fri', SAT: 'Sat', SUN: 'Sun',
                                                                MONDAY: 'Mon', TUESDAY: 'Tue', WEDNESDAY: 'Wed', THURSDAY: 'Thu',
                                                                FRIDAY: 'Fri', SATURDAY: 'Sat', SUNDAY: 'Sun'
                                                            };
                                                            return (
                                                                <Chip
                                                                    key={idx}
                                                                    label={dayLabels[day.toUpperCase()] || day}
                                                                    size="small"
                                                                    variant="outlined"
                                                                    color="primary"
                                                                />
                                                            );
                                                        })}
                                                    </Box>
                                                </Grid>
                                            )}
                                            {detailDialog.event.parentEventId && (
                                                <Grid item xs={12}>
                                                    <Typography variant="caption" color="text.secondary">
                                                        This is a child occurrence of the parent event
                                                    </Typography>
                                                </Grid>
                                            )}
                                        </Grid>
                                    </Box>
                                </Grid>
                            )}

                            {detailDialog.event.speakers && detailDialog.event.speakers.length > 0 && (
                                <Grid item xs={12}>
                                    <Divider sx={{ my: 2 }} />
                                    <Typography variant="h6" gutterBottom>Speakers</Typography>
                                    <Grid container spacing={2}>
                                        {detailDialog.event.speakers.map((speaker, index) => (
                                            <Grid item xs={12} sm={6} md={4} key={index}>
                                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                                                    <Avatar src={speaker.imageUrl} sx={{ width: 48, height: 48 }}>
                                                        {speaker.name?.charAt(0)}
                                                    </Avatar>
                                                    <Box>
                                                        <Typography variant="subtitle2">{speaker.name}</Typography>
                                                        <Typography variant="caption" color="text.secondary">
                                                            {speaker.title}
                                                        </Typography>
                                                    </Box>
                                                </Box>
                                            </Grid>
                                        ))}
                                    </Grid>
                                </Grid>
                            )}

                            {detailDialog.event?.status === 'DRAFT' && (
                                <Grid item xs={12}>
                                    <Divider sx={{ my: 2 }} />
                                    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
                                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                            <AIIcon color="secondary" />
                                            <Typography variant="h6">AI Moderation</Typography>
                                        </Box>
                                        <Button
                                            variant="outlined"
                                            color="secondary"
                                            startIcon={aiLoading ? <CircularProgress size={16} /> : <AIIcon />}
                                            onClick={handleAIAnalyze}
                                            disabled={aiLoading}
                                        >
                                            {aiLoading ? 'Analyzing...' : (aiAnalysis ? 'Re-analyze' : 'Analyze Event')}
                                        </Button>
                                    </Box>

                                    {aiAnalysis && (
                                        <Paper sx={{ p: 2, bgcolor: 'grey.50' }}>
                                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 2 }}>
                                                <Chip
                                                    label={aiAnalysis.recommendation}
                                                    color={
                                                        aiAnalysis.recommendation === 'APPROVE' ? 'success' :
                                                        aiAnalysis.recommendation === 'REJECT' ? 'error' : 'warning'
                                                    }
                                                    icon={
                                                        aiAnalysis.recommendation === 'APPROVE' ? <ApproveIcon /> :
                                                        aiAnalysis.recommendation === 'REJECT' ? <RejectIcon /> : <WarningIcon />
                                                    }
                                                />
                                                <Chip
                                                    label={`Quality Score: ${aiAnalysis.qualityScore}/100`}
                                                    variant="outlined"
                                                    color={
                                                        aiAnalysis.qualityScore >= 70 ? 'success' :
                                                        aiAnalysis.qualityScore >= 40 ? 'warning' : 'error'
                                                    }
                                                />
                                            </Box>

                                            <Typography variant="body2" sx={{ mb: 2 }}>
                                                {aiAnalysis.summary}
                                            </Typography>

                                            {aiAnalysis.strengths?.length > 0 && (
                                                <Box sx={{ mb: 1 }}>
                                                    <Typography variant="subtitle2" color="success.main" sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                                                        <ApproveIcon fontSize="small" /> Strengths:
                                                    </Typography>
                                                    <ul style={{ margin: '4px 0', paddingLeft: 20 }}>
                                                        {aiAnalysis.strengths.map((s, i) => (
                                                            <li key={i}><Typography variant="body2">{s}</Typography></li>
                                                        ))}
                                                    </ul>
                                                </Box>
                                            )}

                                            {aiAnalysis.concerns?.length > 0 && (
                                                <Box sx={{ mb: 1 }}>
                                                    <Typography variant="subtitle2" color="warning.main" sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                                                        <WarningIcon fontSize="small" /> Concerns:
                                                    </Typography>
                                                    <ul style={{ margin: '4px 0', paddingLeft: 20 }}>
                                                        {aiAnalysis.concerns.map((c, i) => (
                                                            <li key={i}><Typography variant="body2">{c}</Typography></li>
                                                        ))}
                                                    </ul>
                                                </Box>
                                            )}

                                            <Typography variant="body2" color="text.secondary" sx={{ mt: 1, fontStyle: 'italic' }}>
                                                <TipIcon fontSize="small" sx={{ verticalAlign: 'middle', mr: 0.5 }} />
                                                {aiAnalysis.suggestedAction}
                                            </Typography>
                                        </Paper>
                                    )}
                                </Grid>
                            )}
                        </Grid>
                    ) : null}
                </DialogContent>
                <DialogActions>
                    {detailDialog.event?.status === 'DRAFT' && (
                        <>
                            <Button
                                color="success"
                                onClick={() => {
                                    setDetailDialog({ open: false, event: null, loading: false });
                                    setSelectedEvent(detailDialog.event);
                                    handleApprove();
                                }}
                            >
                                Approve
                            </Button>
                            <Button
                                color="warning"
                                onClick={() => {
                                    setDetailDialog({ open: false, event: null, loading: false });
                                    setSelectedEvent(detailDialog.event);
                                    handleReject();
                                }}
                            >
                                Reject
                            </Button>
                        </>
                    )}
                    <Button onClick={() => setDetailDialog({ open: false, event: null, loading: false })}>
                        Close
                    </Button>
                </DialogActions>
            </Dialog>

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

            <Dialog
                open={rejectDialog.open}
                onClose={() => !rejectDialog.loading && setRejectDialog({ open: false, reason: '', loading: false })}
                maxWidth="sm"
                fullWidth
            >
                <DialogTitle sx={{ pb: 1 }}>
                    Reject Event
                </DialogTitle>
                <DialogContent>
                    <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                        Are you sure you want to reject this event? The organiser will be notified.
                    </Typography>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
                        <Typography variant="body2" color="text.secondary">
                            Reason for Rejection
                        </Typography>
                        <Button
                            size="small"
                            variant="outlined"
                            color="secondary"
                            startIcon={aiReasonLoading ? <CircularProgress size={14} /> : <AIIcon />}
                            onClick={handleAIGenerateReason}
                            disabled={aiReasonLoading || rejectDialog.loading}
                        >
                            {aiReasonLoading ? 'Generating...' : 'AI Generate'}
                        </Button>
                    </Box>
                    <TextField
                        fullWidth
                        placeholder="Please provide a reason for rejection (optional but recommended)"
                        value={rejectDialog.reason}
                        onChange={(e) => setRejectDialog(prev => ({ ...prev, reason: e.target.value }))}
                        multiline
                        rows={3}
                        disabled={rejectDialog.loading}
                    />
                </DialogContent>
                <DialogActions sx={{ px: 3, pb: 2 }}>
                    <Button
                        onClick={() => setRejectDialog({ open: false, reason: '', loading: false })}
                        disabled={rejectDialog.loading}
                    >
                        Cancel
                    </Button>
                    <Button
                        variant="contained"
                        color="warning"
                        onClick={handleRejectSubmit}
                        disabled={rejectDialog.loading}
                    >
                        {rejectDialog.loading ? 'Rejecting...' : 'Reject Event'}
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default Events;

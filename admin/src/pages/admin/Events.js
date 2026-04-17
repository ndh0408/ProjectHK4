import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Typography,
    TextField,
    IconButton,
    Menu,
    MenuItem,
    Button,
    FormControl,
    InputLabel,
    Select,
    Grid,
    Divider,
    Avatar,
    CircularProgress,
    Chip,
    Tooltip,
    Paper,
} from '@mui/material';
import {
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
    EventNote as EventNoteIcon,
} from '@mui/icons-material';
import MDEditor from '@uiw/react-md-editor';
import { adminApi } from '../../api';
import { ConfirmDialog } from '../../components/common';
import {
    PageHeader,
    PageToolbar,
    DataTableCard,
    StatusChip,
    FormDialog,
    LoadingButton,
} from '../../components/ui';
import { toast } from 'react-toastify';

const statusMap = {
    DRAFT: { status: 'neutral', label: 'Draft' },
    PUBLISHED: { status: 'success', label: 'Published' },
    CANCELLED: { status: 'danger', label: 'Cancelled' },
    COMPLETED: { status: 'info', label: 'Completed' },
    REJECTED: { status: 'warning', label: 'Rejected' },
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
            minWidth: 260,
            renderCell: (params) => (
                <Box sx={{ minWidth: 0 }}>
                    <Typography variant="body2" fontWeight={600} noWrap>
                        {params.row.title}
                    </Typography>
                    <Typography variant="caption" color="text.secondary" noWrap sx={{ display: 'block' }}>
                        {params.row.organiser?.fullName ||
                         params.row.organiser?.email?.split('@')[0] || 'N/A'}
                    </Typography>
                </Box>
            ),
        },
        {
            field: 'startTime',
            headerName: 'Date',
            width: 120,
            valueGetter: (params) => {
                if (!params.row?.startTime) return '';
                return new Date(params.row.startTime).toLocaleDateString();
            },
        },
        {
            field: 'status',
            headerName: 'Status',
            width: 130,
            renderCell: (params) => {
                const cfg = statusMap[params.value] || { status: 'neutral', label: params.value };
                return <StatusChip label={cfg.label} status={cfg.status} />;
            },
        },
        {
            field: 'registrations',
            headerName: 'Regs',
            width: 90,
            align: 'center',
            headerAlign: 'center',
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
            width: 60,
            sortable: false,
            align: 'center',
            headerAlign: 'center',
            renderCell: (params) => (
                <Tooltip title="More actions">
                    <IconButton
                        size="small"
                        aria-label="event actions"
                        onClick={(e) => handleMenuOpen(e, params.row)}
                    >
                        <MoreVertIcon fontSize="small" />
                    </IconButton>
                </Tooltip>
            ),
        },
    ];

    return (
        <Box>
            <PageHeader
                title="Event Management"
                subtitle="Review, approve and moderate all events on the platform"
                icon={<EventNoteIcon />}
                actions={
                    <Button
                        variant="outlined"
                        startIcon={<RefreshIcon />}
                        onClick={loadEvents}
                    >
                        Refresh
                    </Button>
                }
            />

            <DataTableCard
                toolbar={
                    <PageToolbar
                        search={search}
                        onSearchChange={setSearch}
                        searchPlaceholder="Search events by title..."
                        filters={
                            <FormControl size="small" sx={{ minWidth: 180 }}>
                                <InputLabel>Status</InputLabel>
                                <Select
                                    value={statusFilter}
                                    onChange={(e) => setStatusFilter(e.target.value)}
                                    label="Status"
                                >
                                    <MenuItem value="">All statuses</MenuItem>
                                    <MenuItem value="DRAFT">Draft (Pending)</MenuItem>
                                    <MenuItem value="PUBLISHED">Published</MenuItem>
                                    <MenuItem value="REJECTED">Rejected</MenuItem>
                                    <MenuItem value="CANCELLED">Cancelled</MenuItem>
                                    <MenuItem value="COMPLETED">Completed</MenuItem>
                                </Select>
                            </FormControl>
                        }
                    />
                }
                rows={events}
                columns={columns}
                loading={loading}
                emptyTitle="No events found"
                emptyDescription="No events match your current search or filter."
                emptyIcon={<EventNoteIcon sx={{ fontSize: 40 }} />}
                dataGridProps={{
                    paginationModel,
                    onPaginationModelChange: setPaginationModel,
                    pageSizeOptions: [10, 25, 50],
                    rowCount: totalRows,
                    paginationMode: 'server',
                }}
            />

            <Menu
                anchorEl={anchorEl}
                open={Boolean(anchorEl)}
                onClose={handleMenuClose}
                slotProps={{ paper: { sx: { minWidth: 180, borderRadius: 2 } } }}
            >
                <MenuItem onClick={handleViewDetails}>View details</MenuItem>
                <Divider sx={{ my: 0.5 }} />
                {selectedEvent?.status === 'DRAFT' && (
                    <>
                        <MenuItem onClick={handleApprove} sx={{ color: 'success.main' }}>
                            Approve
                        </MenuItem>
                        <MenuItem onClick={handleReject} sx={{ color: 'warning.main' }}>
                            Reject
                        </MenuItem>
                        <Divider sx={{ my: 0.5 }} />
                    </>
                )}
                <MenuItem onClick={handleDelete} sx={{ color: 'error.main' }}>
                    Delete
                </MenuItem>
            </Menu>

            <FormDialog
                open={detailDialog.open}
                onClose={() => setDetailDialog({ open: false, event: null, loading: false })}
                title="Event Details"
                subtitle={detailDialog.event?.title}
                icon={<EventNoteIcon />}
                maxWidth="md"
                actions={
                    <>
                        {detailDialog.event?.status === 'DRAFT' && (
                            <>
                                <Button
                                    color="success"
                                    variant="contained"
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
                                    variant="outlined"
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
                    </>
                }
            >
                {detailDialog.loading ? (
                    <Box sx={{ display: 'flex', justifyContent: 'center', py: 6 }}>
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
                            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 2, flexWrap: 'wrap' }}>
                                <Typography variant="h5" fontWeight={700}>
                                    {detailDialog.event.title}
                                </Typography>
                                {(() => {
                                    const cfg = statusMap[detailDialog.event.status] || { status: 'neutral', label: detailDialog.event.status };
                                    return <StatusChip label={cfg.label} status={cfg.status} />;
                                })()}
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
                            <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 1.5 }}>
                                <EventIcon color="primary" fontSize="small" sx={{ mt: 0.5 }} />
                                <Box>
                                    <Typography variant="caption" color="text.secondary">Date & Time</Typography>
                                    <Typography variant="body2">
                                        {formatDateTime(detailDialog.event.startTime)} — {formatDateTime(detailDialog.event.endTime)}
                                    </Typography>
                                </Box>
                            </Box>
                        </Grid>

                        <Grid item xs={12} md={6}>
                            <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 1.5 }}>
                                <LocationIcon color="primary" fontSize="small" sx={{ mt: 0.5 }} />
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
                            <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 1.5 }}>
                                <CategoryIcon color="primary" fontSize="small" sx={{ mt: 0.5 }} />
                                <Box>
                                    <Typography variant="caption" color="text.secondary">Category</Typography>
                                    <Typography variant="body2">
                                        {detailDialog.event.category?.name}
                                    </Typography>
                                </Box>
                            </Box>
                        </Grid>

                        <Grid item xs={12} md={6}>
                            <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 1.5 }}>
                                <MoneyIcon color="primary" fontSize="small" sx={{ mt: 0.5 }} />
                                <Box>
                                    <Typography variant="caption" color="text.secondary">Price</Typography>
                                    <Typography variant="body2">
                                        {formatPrice(detailDialog.event.ticketPrice, detailDialog.event.isFree)}
                                    </Typography>
                                </Box>
                            </Box>
                        </Grid>

                        <Grid item xs={12} md={6}>
                            <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 1.5 }}>
                                <PeopleIcon color="primary" fontSize="small" sx={{ mt: 0.5 }} />
                                <Box>
                                    <Typography variant="caption" color="text.secondary">Capacity</Typography>
                                    <Typography variant="body2">
                                        {detailDialog.event.approvedCount || 0} / {detailDialog.event.capacity || 'Unlimited'}
                                    </Typography>
                                </Box>
                            </Box>
                        </Grid>

                        <Grid item xs={12} md={6}>
                            <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 1.5 }}>
                                <PersonIcon color="primary" fontSize="small" sx={{ mt: 0.5 }} />
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
                                    p: 2.5,
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
                                        <StatusChip
                                            label={`${detailDialog.event.occurrenceIndex || 1}/${detailDialog.event.totalOccurrences || 1}`}
                                            status="primary"
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
                                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2, flexWrap: 'wrap', gap: 2 }}>
                                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                        <AIIcon color="secondary" />
                                        <Typography variant="h6">AI Moderation</Typography>
                                    </Box>
                                    <LoadingButton
                                        variant="outlined"
                                        color="secondary"
                                        startIcon={<AIIcon />}
                                        onClick={handleAIAnalyze}
                                        loading={aiLoading}
                                    >
                                        {aiAnalysis ? 'Re-analyze' : 'Analyze Event'}
                                    </LoadingButton>
                                </Box>

                                {aiAnalysis && (
                                    <Paper variant="outlined" sx={{ p: 2.5, bgcolor: 'grey.50', borderRadius: 2 }}>
                                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 2, flexWrap: 'wrap' }}>
                                            <StatusChip
                                                label={aiAnalysis.recommendation}
                                                status={
                                                    aiAnalysis.recommendation === 'APPROVE' ? 'success' :
                                                    aiAnalysis.recommendation === 'REJECT' ? 'danger' : 'warning'
                                                }
                                                icon={
                                                    aiAnalysis.recommendation === 'APPROVE' ? <ApproveIcon /> :
                                                    aiAnalysis.recommendation === 'REJECT' ? <RejectIcon /> : <WarningIcon />
                                                }
                                            />
                                            <StatusChip
                                                label={`Quality Score: ${aiAnalysis.qualityScore}/100`}
                                                status={
                                                    aiAnalysis.qualityScore >= 70 ? 'success' :
                                                    aiAnalysis.qualityScore >= 40 ? 'warning' : 'danger'
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
            </FormDialog>

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

            <FormDialog
                open={rejectDialog.open}
                onClose={() => !rejectDialog.loading && setRejectDialog({ open: false, reason: '', loading: false })}
                title="Reject Event"
                subtitle="The organiser will be notified of the rejection."
                icon={<RejectIcon />}
                maxWidth="sm"
                actions={
                    <>
                        <Button
                            onClick={() => setRejectDialog({ open: false, reason: '', loading: false })}
                            disabled={rejectDialog.loading}
                        >
                            Cancel
                        </Button>
                        <LoadingButton
                            variant="contained"
                            color="warning"
                            onClick={handleRejectSubmit}
                            loading={rejectDialog.loading}
                        >
                            Reject Event
                        </LoadingButton>
                    </>
                }
            >
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1, flexWrap: 'wrap', gap: 1 }}>
                    <Typography variant="body2" color="text.secondary">
                        Reason for rejection
                    </Typography>
                    <LoadingButton
                        size="small"
                        variant="outlined"
                        color="secondary"
                        startIcon={<AIIcon />}
                        onClick={handleAIGenerateReason}
                        loading={aiReasonLoading}
                        disabled={rejectDialog.loading}
                    >
                        AI Generate
                    </LoadingButton>
                </Box>
                <TextField
                    fullWidth
                    placeholder="Please provide a reason for rejection (optional but recommended)"
                    value={rejectDialog.reason}
                    onChange={(e) => setRejectDialog(prev => ({ ...prev, reason: e.target.value }))}
                    multiline
                    rows={4}
                    disabled={rejectDialog.loading}
                />
            </FormDialog>
        </Box>
    );
};

export default Events;

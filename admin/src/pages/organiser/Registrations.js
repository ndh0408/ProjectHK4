import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Typography,
    Paper,
    TextField,
    Autocomplete,
    Button,
    Chip,
    IconButton,
    Tooltip,
    Tabs,
    Tab,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    List,
    ListItem,
    ListItemText,
    Divider,
    Avatar,
    Card,
    CardContent,
    Grid,
    Badge,
} from '@mui/material';
import { DataGrid } from '@mui/x-data-grid';
import {
    Refresh as RefreshIcon,
    CheckCircle as ApproveIcon,
    Cancel as RejectIcon,
    HowToReg as CheckInIcon,
    Download as DownloadIcon,
    QuestionAnswer as AnswerIcon,
    Email as EmailIcon,
    Phone as PhoneIcon,
    AccessTime as TimeIcon,
} from '@mui/icons-material';
import { organiserApi } from '../../api';
import { ConfirmDialog } from '../../components/common';
import { toast } from 'react-toastify';

const statusColors = {
    PENDING: 'warning',
    APPROVED: 'success',
    REJECTED: 'error',
    CANCELLED: 'default',
    CHECKED_IN: 'info',
    WAITING_LIST: 'secondary',
};

const OrganiserRegistrations = () => {
    const [events, setEvents] = useState([]);
    const [selectedEvent, setSelectedEvent] = useState('');
    const [registrations, setRegistrations] = useState([]);
    const [waitingList, setWaitingList] = useState([]);
    const [loading, setLoading] = useState(false);
    const [paginationModel, setPaginationModel] = useState({ page: 0, pageSize: 10 });
    const [totalRows, setTotalRows] = useState(0);
    const [confirmDialog, setConfirmDialog] = useState({ open: false, title: '', message: '', action: null });
    const [tabValue, setTabValue] = useState(0);
    const [answersDialog, setAnswersDialog] = useState({ open: false, registration: null, answers: [] });
    const [loadingAnswers, setLoadingAnswers] = useState(false);

    useEffect(() => {
        loadEvents();
    }, []);

    const loadEvents = async () => {
        try {
            const response = await organiserApi.getMyEvents({ page: 0, size: 100 });
            setEvents(response.data.data.content || []);
        } catch (error) {
            console.error('Failed to load events:', error);
        }
    };

    const loadRegistrations = useCallback(async () => {
        if (!selectedEvent) return;

        setLoading(true);
        try {
            const response = await organiserApi.getEventRegistrations(selectedEvent, {
                page: paginationModel.page,
                size: paginationModel.pageSize,
            });
            const allRegistrations = response.data.data.content || [];
            const mainRegistrations = allRegistrations.filter(r => r.status !== 'WAITING_LIST');
            setRegistrations(mainRegistrations);
            setTotalRows(response.data.data.totalElements || 0);
        } catch (error) {
            toast.error('Failed to load registrations');
        } finally {
            setLoading(false);
        }
    }, [selectedEvent, paginationModel]);

    const loadWaitingList = useCallback(async () => {
        if (!selectedEvent) return;

        try {
            const response = await organiserApi.getWaitingList(selectedEvent);
            setWaitingList(response.data.data || []);
        } catch (error) {
            console.error('Failed to load waiting list:', error);
        }
    }, [selectedEvent]);

    useEffect(() => {
        loadRegistrations();
        loadWaitingList();
    }, [loadRegistrations, loadWaitingList]);

    const handleViewAnswers = async (registration) => {
        setLoadingAnswers(true);
        setAnswersDialog({ open: true, registration, answers: [] });
        try {
            const response = await organiserApi.getRegistrationAnswers(registration.id);
            setAnswersDialog({ open: true, registration, answers: response.data.data || [] });
        } catch (error) {
            toast.error('Failed to load registration answers');
        } finally {
            setLoadingAnswers(false);
        }
    };

    const handleApprove = (registration) => {
        setConfirmDialog({
            open: true,
            title: 'Approve Registration',
            message: `Approve registration for ${registration.userName}?`,
            action: async () => {
                try {
                    await organiserApi.approveRegistration(registration.id);
                    toast.success('Registration approved');
                    loadRegistrations();
                    loadWaitingList();
                } catch (error) {
                    toast.error('Failed to approve registration');
                }
            },
        });
    };

    const handleReject = (registration) => {
        setConfirmDialog({
            open: true,
            title: 'Reject Registration',
            message: `Reject registration for ${registration.userName}?`,
            confirmColor: 'error',
            action: async () => {
                try {
                    await organiserApi.rejectRegistration(registration.id);
                    toast.success('Registration rejected');
                    loadRegistrations();
                    loadWaitingList();
                } catch (error) {
                    toast.error('Failed to reject registration');
                }
            },
        });
    };

    const handleCheckIn = (registration) => {
        setConfirmDialog({
            open: true,
            title: 'Check In',
            message: `Check in ${registration.userName}?`,
            action: async () => {
                try {
                    await organiserApi.checkInRegistration(registration.id);
                    toast.success('Checked in successfully');
                    loadRegistrations();
                } catch (error) {
                    const errorMsg = error.response?.data?.message || error.message || 'Failed to check in';
                    if (errorMsg.includes('not available yet')) {
                        toast.error('Check-in is not available yet. Opens 2 hours before event.');
                    } else if (errorMsg.includes('period has ended')) {
                        toast.error('Check-in period has ended for this event.');
                    } else if (errorMsg.includes('already been checked in')) {
                        toast.error('This registration has already been checked in.');
                    } else {
                        toast.error(errorMsg);
                    }
                }
            },
        });
    };

    const handleExport = async () => {
        if (!selectedEvent) return;

        try {
            const response = await organiserApi.exportAttendees(selectedEvent);
            const url = window.URL.createObjectURL(new Blob([response.data]));
            const link = document.createElement('a');
            link.href = url;
            link.setAttribute('download', `attendees_${selectedEvent}.xlsx`);
            document.body.appendChild(link);
            link.click();
            link.remove();
            toast.success('Export successful');
        } catch (error) {
            toast.error('Failed to export attendees');
        }
    };

    const columns = [
        {
            field: 'userName',
            headerName: 'Name',
            flex: 1,
            minWidth: 150,
            renderCell: (params) => (
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <Avatar src={params.row.userAvatarUrl} sx={{ width: 32, height: 32 }}>
                        {params.row.userName?.charAt(0)}
                    </Avatar>
                    <Typography variant="body2">{params.row.userName || ''}</Typography>
                </Box>
            ),
        },
        {
            field: 'userEmail',
            headerName: 'Email',
            flex: 1,
            minWidth: 200,
            valueGetter: (params) => params.row.userEmail || '',
        },
        {
            field: 'status',
            headerName: 'Status',
            width: 130,
            renderCell: (params) => (
                <Chip
                    label={params.value}
                    size="small"
                    color={statusColors[params.value] || 'default'}
                />
            ),
        },
        {
            field: 'createdAt',
            headerName: 'Registered At',
            width: 150,
            valueFormatter: (params) => {
                if (!params.value) return '';
                return new Date(params.value).toLocaleDateString();
            },
        },
        {
            field: 'actions',
            headerName: 'Actions',
            width: 180,
            sortable: false,
            renderCell: (params) => (
                <Box>
                    <Tooltip title="View Answers">
                        <IconButton
                            size="small"
                            color="info"
                            onClick={() => handleViewAnswers(params.row)}
                        >
                            <AnswerIcon />
                        </IconButton>
                    </Tooltip>
                    {params.row.status === 'PENDING' && (
                        <>
                            <Tooltip title="Approve">
                                <IconButton
                                    size="small"
                                    color="success"
                                    onClick={() => handleApprove(params.row)}
                                >
                                    <ApproveIcon />
                                </IconButton>
                            </Tooltip>
                            <Tooltip title="Reject">
                                <IconButton
                                    size="small"
                                    color="error"
                                    onClick={() => handleReject(params.row)}
                                >
                                    <RejectIcon />
                                </IconButton>
                            </Tooltip>
                        </>
                    )}
                    {params.row.status === 'APPROVED' && !params.row.checkedInAt && (
                        <Tooltip title="Check In">
                            <IconButton
                                size="small"
                                color="primary"
                                onClick={() => handleCheckIn(params.row)}
                            >
                                <CheckInIcon />
                            </IconButton>
                        </Tooltip>
                    )}
                </Box>
            ),
        },
    ];

    const waitingListColumns = [
        {
            field: 'waitingListPosition',
            headerName: '#',
            width: 60,
            valueGetter: (params) => params.row.waitingListPosition || '-',
        },
        {
            field: 'userName',
            headerName: 'Name',
            flex: 1,
            minWidth: 150,
            renderCell: (params) => (
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <Avatar src={params.row.userAvatarUrl} sx={{ width: 32, height: 32 }}>
                        {params.row.userName?.charAt(0)}
                    </Avatar>
                    <Typography variant="body2">{params.row.userName || ''}</Typography>
                </Box>
            ),
        },
        {
            field: 'userEmail',
            headerName: 'Email',
            flex: 1,
            minWidth: 200,
            valueGetter: (params) => params.row.userEmail || '',
        },
        {
            field: 'createdAt',
            headerName: 'Joined At',
            width: 150,
            valueFormatter: (params) => {
                if (!params.value) return '';
                return new Date(params.value).toLocaleDateString();
            },
        },
        {
            field: 'actions',
            headerName: 'Actions',
            width: 120,
            sortable: false,
            renderCell: (params) => (
                <Box>
                    <Tooltip title="View Answers">
                        <IconButton
                            size="small"
                            color="info"
                            onClick={() => handleViewAnswers(params.row)}
                        >
                            <AnswerIcon />
                        </IconButton>
                    </Tooltip>
                    <Tooltip title="Approve (Move to Registered)">
                        <IconButton
                            size="small"
                            color="success"
                            onClick={() => handleApprove(params.row)}
                        >
                            <ApproveIcon />
                        </IconButton>
                    </Tooltip>
                </Box>
            ),
        },
    ];

    const selectedEventData = events.find(e => e.id === selectedEvent);

    return (
        <Box>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                <Typography variant="h5" fontWeight="bold">
                    Registrations
                </Typography>
                <Box sx={{ display: 'flex', gap: 1 }}>
                    <Button startIcon={<RefreshIcon />} onClick={() => { loadRegistrations(); loadWaitingList(); }}>
                        Refresh
                    </Button>
                    <Button
                        variant="contained"
                        startIcon={<DownloadIcon />}
                        onClick={handleExport}
                        disabled={!selectedEvent}
                    >
                        Export Excel
                    </Button>
                </Box>
            </Box>

            <Paper sx={{ p: 2, mb: 2 }}>
                <Autocomplete
                    options={events}
                    getOptionLabel={(option) => option.title || ''}
                    value={events.find(e => e.id === selectedEvent) || null}
                    onChange={(_, newValue) => {
                        setSelectedEvent(newValue?.id || '');
                        setTabValue(0);
                    }}
                    renderInput={(params) => (
                        <TextField {...params} label="Search Event" placeholder="Type to search events..." />
                    )}
                    renderOption={(props, option) => (
                        <li {...props} key={option.id}>
                            <Box sx={{ width: '100%' }}>
                                <Typography variant="body1" noWrap>{option.title}</Typography>
                                <Typography variant="caption" color="text.secondary">
                                    {option.startTime ? new Date(option.startTime).toLocaleDateString() : ''} • {option.currentRegistrations || 0}/{option.capacity || '∞'} registrations
                                </Typography>
                            </Box>
                        </li>
                    )}
                    isOptionEqualToValue={(option, value) => option.id === value.id}
                    sx={{ minWidth: 400 }}
                    noOptionsText="No events found"
                />
            </Paper>

            {selectedEvent ? (
                <>
                    {selectedEventData && (
                        <Paper sx={{ p: 2, mb: 2 }}>
                            <Grid container spacing={2}>
                                <Grid item xs={12} md={4}>
                                    <Card variant="outlined">
                                        <CardContent sx={{ textAlign: 'center' }}>
                                            <Typography color="text.secondary" gutterBottom>
                                                Total Registrations
                                            </Typography>
                                            <Typography variant="h4">
                                                {selectedEventData.currentRegistrations || 0}
                                            </Typography>
                                        </CardContent>
                                    </Card>
                                </Grid>
                                <Grid item xs={12} md={4}>
                                    <Card variant="outlined">
                                        <CardContent sx={{ textAlign: 'center' }}>
                                            <Typography color="text.secondary" gutterBottom>
                                                Capacity
                                            </Typography>
                                            <Typography variant="h4">
                                                {selectedEventData.capacity || '∞'}
                                            </Typography>
                                        </CardContent>
                                    </Card>
                                </Grid>
                                <Grid item xs={12} md={4}>
                                    <Card variant="outlined">
                                        <CardContent sx={{ textAlign: 'center' }}>
                                            <Typography color="text.secondary" gutterBottom>
                                                Waiting List
                                            </Typography>
                                            <Typography variant="h4" color="warning.main">
                                                {waitingList.length}
                                            </Typography>
                                        </CardContent>
                                    </Card>
                                </Grid>
                            </Grid>
                        </Paper>
                    )}

                    <Paper>
                        <Tabs
                            value={tabValue}
                            onChange={(_, newValue) => setTabValue(newValue)}
                            sx={{ borderBottom: 1, borderColor: 'divider', px: 2 }}
                        >
                            <Tab
                                label={
                                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                        <span>All Registrations</span>
                                        <Chip label={registrations.length} size="small" />
                                    </Box>
                                }
                            />
                            <Tab
                                label={
                                    <Badge badgeContent={waitingList.length} color="warning">
                                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, pr: 2 }}>
                                            <span>Waiting List</span>
                                        </Box>
                                    </Badge>
                                }
                            />
                        </Tabs>

                        {tabValue === 0 && (
                            <DataGrid
                                rows={registrations}
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
                        )}

                        {tabValue === 1 && (
                            <DataGrid
                                rows={waitingList}
                                columns={waitingListColumns}
                                loading={loading}
                                pageSizeOptions={[10, 25, 50]}
                                disableRowSelectionOnClick
                                autoHeight
                                initialState={{
                                    sorting: {
                                        sortModel: [{ field: 'waitingListPosition', sort: 'asc' }],
                                    },
                                }}
                            />
                        )}
                    </Paper>
                </>
            ) : (
                <Paper sx={{ p: 4, textAlign: 'center' }}>
                    <Typography color="text.secondary">
                        Please select an event to view registrations
                    </Typography>
                </Paper>
            )}

            <Dialog
                open={answersDialog.open}
                onClose={() => setAnswersDialog({ open: false, registration: null, answers: [] })}
                maxWidth="sm"
                fullWidth
            >
                <DialogTitle>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                        <Avatar src={answersDialog.registration?.userAvatarUrl} sx={{ width: 48, height: 48 }}>
                            {answersDialog.registration?.userName?.charAt(0)}
                        </Avatar>
                        <Box>
                            <Typography variant="h6">{answersDialog.registration?.userName}</Typography>
                            <Typography variant="caption" color="text.secondary">
                                Registration Details
                            </Typography>
                        </Box>
                    </Box>
                </DialogTitle>
                <DialogContent dividers>
                    <Box sx={{ mb: 3 }}>
                        <Typography variant="subtitle2" color="primary" gutterBottom>
                            Contact Information
                        </Typography>
                        <List dense>
                            <ListItem>
                                <EmailIcon sx={{ mr: 2, color: 'text.secondary' }} />
                                <ListItemText
                                    primary={answersDialog.registration?.userEmail || 'N/A'}
                                    secondary="Email"
                                />
                            </ListItem>
                            <ListItem>
                                <PhoneIcon sx={{ mr: 2, color: 'text.secondary' }} />
                                <ListItemText
                                    primary={answersDialog.registration?.userPhone || 'N/A'}
                                    secondary="Phone"
                                />
                            </ListItem>
                            <ListItem>
                                <TimeIcon sx={{ mr: 2, color: 'text.secondary' }} />
                                <ListItemText
                                    primary={answersDialog.registration?.createdAt
                                        ? new Date(answersDialog.registration.createdAt).toLocaleString()
                                        : 'N/A'}
                                    secondary="Registered At"
                                />
                            </ListItem>
                        </List>
                    </Box>

                    <Divider sx={{ my: 2 }} />

                    <Box>
                        <Typography variant="subtitle2" color="primary" gutterBottom>
                            Registration Form Answers
                        </Typography>
                        {loadingAnswers ? (
                            <Typography color="text.secondary">Loading answers...</Typography>
                        ) : answersDialog.answers.length > 0 ? (
                            <List>
                                {answersDialog.answers.map((answer, index) => (
                                    <React.Fragment key={answer.id || index}>
                                        <ListItem sx={{ flexDirection: 'column', alignItems: 'flex-start' }}>
                                            <Typography variant="body2" color="text.secondary" sx={{ fontWeight: 500 }}>
                                                {answer.questionText}
                                            </Typography>
                                            <Typography variant="body1" sx={{ mt: 0.5 }}>
                                                {answer.answer || 'No answer provided'}
                                            </Typography>
                                        </ListItem>
                                        {index < answersDialog.answers.length - 1 && <Divider />}
                                    </React.Fragment>
                                ))}
                            </List>
                        ) : (
                            <Typography color="text.secondary" sx={{ fontStyle: 'italic' }}>
                                No custom questions were answered for this registration.
                            </Typography>
                        )}
                    </Box>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setAnswersDialog({ open: false, registration: null, answers: [] })}>
                        Close
                    </Button>
                    {answersDialog.registration?.status === 'PENDING' && (
                        <>
                            <Button
                                color="error"
                                onClick={() => {
                                    setAnswersDialog({ open: false, registration: null, answers: [] });
                                    handleReject(answersDialog.registration);
                                }}
                            >
                                Reject
                            </Button>
                            <Button
                                variant="contained"
                                color="success"
                                onClick={() => {
                                    setAnswersDialog({ open: false, registration: null, answers: [] });
                                    handleApprove(answersDialog.registration);
                                }}
                            >
                                Approve
                            </Button>
                        </>
                    )}
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
        </Box>
    );
};

export default OrganiserRegistrations;

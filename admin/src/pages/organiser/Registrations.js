import React, { useState, useEffect, useCallback, useMemo, useRef } from 'react';
import {
    Box,
    Typography,
    Paper,
    TextField,
    InputAdornment,
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
    Star as StarIcon,
    LocalOffer as OfferIcon,
    Timer as TimerIcon,
    Search as SearchIcon,
    QrCodeScanner as QrCodeScannerIcon,
    Close as CloseIcon,
    Block as BanIcon,
    VolumeOff as MuteIcon,
} from '@mui/icons-material';
import { Html5Qrcode } from 'html5-qrcode';
import { organiserApi } from '../../api';
import { ConfirmDialog } from '../../components/common';
import {
    PageHeader,
    StatusChip,
    FormDialog,
    SectionCard,
    StatCard,
    EmptyState,
    LoadingButton,
} from '../../components/ui';
import HowToRegIcon from '@mui/icons-material/HowToReg';
import EventBusyIcon from '@mui/icons-material/EventBusy';
import { toast } from 'react-toastify';

const statusMap = {
    PENDING: 'warning',
    APPROVED: 'success',
    CONFIRMED: 'success',
    CHECKED_IN: 'info',
    REJECTED: 'danger',
    CANCELLED: 'neutral',
    WAITING_LIST: 'primary',
    NO_SHOW: 'danger',
};

// Helper functions for fit level display
const getFitLabel = (fitLevel) => {
    if (!fitLevel) return 'N/A';
    const level = fitLevel.toUpperCase();
    if (level === 'HIGH') return 'HIGH';
    if (level === 'MEDIUM') return 'MEDIUM';
    if (level === 'LOW') return 'LOW';
    return fitLevel;
};

const getFitColor = (fitLevel) => {
    if (!fitLevel) return 'text.secondary';
    const level = fitLevel.toUpperCase();
    if (level === 'HIGH') return 'success.main';
    if (level === 'MEDIUM') return 'warning.main';
    if (level === 'LOW') return 'error.main';
    return 'text.secondary';
};

// Helper function to format question type
const formatQuestionType = (type) => {
    if (!type) return '';
    return type.replace(/_/g, ' ');
};

// Map raw backend check-in errors to friendlier copy. The code field is
// hidden when it's just a UUID that doesn't help the organiser act.
const describeScanError = (rawMessage) => {
    const msg = (rawMessage || '').toString();
    const lower = msg.toLowerCase();

    if (lower.includes('not available yet') || lower.includes('opens 2 hours')) {
        return {
            emoji: '⏰',
            title: 'Check-in not open yet',
            detail: 'Check-in opens 2 hours before the event starts.',
            hideCode: true,
        };
    }
    if (lower.includes('check-in period has ended') || lower.includes('period has ended')) {
        return {
            emoji: '⌛',
            title: 'Check-in window closed',
            detail: 'The event has ended, no more check-ins allowed.',
            hideCode: true,
        };
    }
    if (lower.includes('already been checked in') || lower.includes('already checked')) {
        return {
            emoji: '✅',
            title: 'Already checked in',
            detail: 'This ticket has already been scanned.',
            hideCode: false,
        };
    }
    if (lower.includes('only approved') || lower.includes('must be approved')) {
        return {
            emoji: '⛔',
            title: 'Registration not approved',
            detail: 'This registration is still pending — approve it before check-in.',
            hideCode: false,
        };
    }
    if (lower.includes('does not belong') || lower.includes('not belong')) {
        return {
            emoji: '🎟️',
            title: 'Ticket is for another event',
            detail: 'This ticket belongs to a different event — double-check the selected event.',
            hideCode: false,
        };
    }
    if (lower.includes('no registration found') || lower.includes('not found')) {
        return {
            emoji: '❓',
            title: 'Ticket not found',
            detail: 'The scanned code doesn\'t match any registration. Ask the guest to reopen the ticket in the app.',
            hideCode: true,
        };
    }
    return {
        emoji: '✗',
        title: 'Check-in failed',
        detail: msg || 'Unknown error.',
        hideCode: false,
    };
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
    const [waitlistOffers, setWaitlistOffers] = useState([]);
    const [quickSearch, setQuickSearch] = useState('');
    const [scanDialog, setScanDialog] = useState(false);
    const [scanManualCode, setScanManualCode] = useState('');
    // eslint-disable-next-line no-unused-vars
    const [scanError, setScanError] = useState('');
    // eslint-disable-next-line no-unused-vars
    const [scanSuccess, setScanSuccess] = useState('');
    const [scanBusy, setScanBusy] = useState(false);
    const [scanHistory, setScanHistory] = useState([]);
    const [lastScanResult, setLastScanResult] = useState(null);
    const qrRegionRef = useRef(null);
    const qrInstanceRef = useRef(null);
    const lastScannedCodeRef = useRef({ code: null, at: 0 });

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

    const selectedEventData = useMemo(() => events.find(e => e.id === selectedEvent), [events, selectedEvent]);

    const filteredRegistrations = useMemo(() => {
        const q = quickSearch.trim().toLowerCase();
        if (!q) return registrations;
        return registrations.filter((r) => {
            return (
                (r.userName || '').toLowerCase().includes(q) ||
                (r.userEmail || '').toLowerCase().includes(q) ||
                (r.userPhone || '').toLowerCase().includes(q) ||
                (r.ticketCode || '').toLowerCase().includes(q) ||
                (r.ticketTypeName || '').toLowerCase().includes(q)
            );
        });
    }, [registrations, quickSearch]);

    const performCheckInByCode = useCallback(async (code) => {
        if (!selectedEvent || !code) return;
        const trimmed = code.trim();
        if (!trimmed) return;

        const now = Date.now();
        if (lastScannedCodeRef.current.code === trimmed && (now - lastScannedCodeRef.current.at) < 2500) {
            return;
        }
        lastScannedCodeRef.current = { code: trimmed, at: now };

        setScanBusy(true);
        setScanError('');
        setScanSuccess('');
        try {
            const response = await organiserApi.checkInByCode(selectedEvent, trimmed);
            const r = response.data.data;
            const result = {
                status: 'success',
                at: new Date(),
                code: trimmed,
                name: r.userName || '(no name)',
                email: r.userEmail || '',
                phone: r.userPhone || '',
                avatarUrl: r.userAvatarUrl || null,
                ticketTypeName: r.ticketTypeName || null,
                quantity: r.quantity || 1,
                ticketTypePrice: r.ticketTypePrice,
                eventTitle: selectedEventData?.title || '',
                message: `Checked in successfully`,
            };
            setLastScanResult(result);
            setScanHistory((prev) => [result, ...prev].slice(0, 10));
            setScanSuccess(`${result.name} checked in`);
            setScanManualCode('');
            loadRegistrations();
            toast.success(`✓ ${result.name} checked in${result.ticketTypeName ? ' · ' + result.ticketTypeName : ''}`);
        } catch (error) {
            const msg = error.response?.data?.message || error.message || 'Check-in failed';
            const friendly = describeScanError(msg);
            const result = {
                status: 'error',
                at: new Date(),
                code: trimmed,
                message: msg,
                eventTitle: selectedEventData?.title || '',
            };
            setLastScanResult(result);
            setScanHistory((prev) => [result, ...prev].slice(0, 10));
            setScanError(msg);
            toast.error(`${friendly.emoji} ${friendly.title}`);
        } finally {
            setScanBusy(false);
        }
    }, [selectedEvent, selectedEventData, loadRegistrations]);

    const startCameraScan = useCallback(async () => {
        setScanError('');
        try {
            if (!qrInstanceRef.current) {
                qrInstanceRef.current = new Html5Qrcode('qr-scan-region');
            }
            const cameras = await Html5Qrcode.getCameras();
            if (!cameras || cameras.length === 0) {
                setScanError('No camera found on this device');
                return;
            }
            const cam = cameras.find((c) => /back|rear|environment/i.test(c.label)) || cameras[0];
            await qrInstanceRef.current.start(
                cam.id,
                { fps: 10, qrbox: { width: 240, height: 240 } },
                (decodedText) => {
                    performCheckInByCode(decodedText);
                },
                () => {}
            );
        } catch (e) {
            setScanError('Camera error: ' + (e.message || e));
        }
    }, [performCheckInByCode]);

    const stopCameraScan = useCallback(async () => {
        try {
            if (qrInstanceRef.current && qrInstanceRef.current.isScanning) {
                await qrInstanceRef.current.stop();
                qrInstanceRef.current.clear();
            }
        } catch (_) {}
    }, []);

    useEffect(() => {
        if (scanDialog) {
            const t = setTimeout(() => startCameraScan(), 200);
            return () => clearTimeout(t);
        } else {
            stopCameraScan();
            setScanManualCode('');
            setScanError('');
            setScanSuccess('');
        }
    }, [scanDialog, startCameraScan, stopCameraScan]);

    const loadWaitlistOffers = useCallback(async () => {
        if (!selectedEvent) return;

        try {
            const response = await organiserApi.getWaitlistOffers(selectedEvent);
            setWaitlistOffers(response.data.data || []);
        } catch (error) {
            console.error('Failed to load waitlist offers:', error);
        }
    }, [selectedEvent]);

    useEffect(() => {
        loadRegistrations();
        loadWaitingList();
        loadWaitlistOffers();
    }, [loadRegistrations, loadWaitingList, loadWaitlistOffers]);

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

    const handleMuteAttendee = async (registration) => {
        if (!window.confirm(`Mute ${registration.userName} in event chat?`)) return;
        try {
            toast.info('Feature is being wired to event chat...');
        } catch (error) {
            toast.error('Failed to mute attendee');
        }
    };

    const handleBanAttendee = async (registration) => {
        if (!window.confirm(`BAN ${registration.userName} from this event and chat?`)) return;
        try {
            toast.info('Feature is being wired to event chat...');
        } catch (error) {
            toast.error('Failed to ban attendee');
        }
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
            headerName: 'Applicant',
            flex: 1.5,
            minWidth: 200,
            renderCell: (params) => (
                <Box sx={{ py: 1 }}>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Avatar src={params.row.userAvatarUrl} sx={{ width: 32, height: 32 }}>
                            {params.row.userName?.charAt(0)}
                        </Avatar>
                        <Typography variant="body2" fontWeight="bold">{params.row.userName || ''}</Typography>
                    </Box>
                    {(params.row.jobTitle || params.row.company) && (
                        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', ml: 5 }}>
                            {params.row.jobTitle || 'Attendee'}{params.row.company ? ` @ ${params.row.company}` : ''}
                        </Typography>
                    )}
                </Box>
            ),
        },
        {
            field: 'totalScore',
            headerName: 'Signals',
            width: 130,
            renderCell: (params) => {
                const score = params.row.totalScore ?? 0;
                const color = score >= 70 ? 'success' : score >= 40 ? 'warning' : 'error';
                const warnings = params.row.warningFlags || [];
                const reasons = params.row.scoreReasons || [];

                return (
                    <Tooltip
                        title={
                            <Box sx={{ p: 0.5 }}>
                                {reasons.length > 0 && (
                                    <Box sx={{ mb: 1 }}>
                                        <Typography variant="caption" fontWeight="bold" color="inherit">Strengths:</Typography>
                                        {reasons.map((r, i) => <Typography key={i} variant="caption" sx={{ display: 'block' }}>• {r}</Typography>)}
                                    </Box>
                                )}
                                {warnings.length > 0 && (
                                    <Box>
                                        <Typography variant="caption" fontWeight="bold" color="error.light">Warnings:</Typography>
                                        {warnings.map((w, i) => <Typography key={i} variant="caption" sx={{ display: 'block', color: 'error.light' }}>• {w}</Typography>)}
                                    </Box>
                                )}
                                {reasons.length === 0 && warnings.length === 0 && (
                                    <Typography variant="caption">No signals detected</Typography>
                                )}
                            </Box>
                        }
                        arrow
                    >
                        <Chip
                            label={`Score: ${score}`}
                            color={color}
                            size="small"
                            variant="outlined"
                            sx={{ fontWeight: 'bold' }}
                        />
                    </Tooltip>
                );
            },
        },
        {
            field: 'history',
            headerName: 'Reputation',
            width: 120,
            renderCell: (params) => (
                <Box>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                        <Typography variant="caption" color="text.secondary">Attend:</Typography>
                        <Typography variant="caption" fontWeight="bold" color="success.main">
                            {params.row.pastEventsAttended || 0}
                        </Typography>
                    </Box>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                        <Typography variant="caption" color="text.secondary">No-show:</Typography>
                        <Typography variant="caption" fontWeight="bold" color={params.row.pastNoShows > 0 ? "error.main" : "text.secondary"}>
                            {params.row.pastNoShows || 0}
                        </Typography>
                    </Box>
                </Box>
            ),
        },
        {
            field: 'status',
            headerName: 'Status',
            width: 120,
            renderCell: (params) => (
                <StatusChip
                    label={params.value}
                    status={statusMap[params.value] || 'neutral'}
                />
            ),
        },
        {
            field: 'actions',
            headerName: 'Actions',
            width: 160,
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
                    {(params.row.status === 'APPROVED' || params.row.status === 'CONFIRMED') && !params.row.checkedInAt && (
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
                    {(params.row.status === 'APPROVED' || params.row.status === 'CONFIRMED') && (
                        <>
                            <Tooltip title="Mute in Chat">
                                <IconButton
                                    size="small"
                                    onClick={() => handleMuteAttendee(params.row)}
                                >
                                    <MuteIcon fontSize="small" />
                                </IconButton>
                            </Tooltip>
                            <Tooltip title="Ban from Event">
                                <IconButton
                                    size="small"
                                    color="error"
                                    onClick={() => handleBanAttendee(params.row)}
                                >
                                    <BanIcon fontSize="small" />
                                </IconButton>
                            </Tooltip>
                        </>
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
            field: 'priorityScore',
            headerName: 'Priority',
            width: 100,
            renderCell: (params) => {
                const score = params.row.priorityScore || 0;
                const color = score >= 60 ? 'success' : score >= 30 ? 'warning' : 'default';
                return (
                    <Chip
                        icon={<StarIcon sx={{ fontSize: 16 }} />}
                        label={score}
                        size="small"
                        color={color}
                        variant="outlined"
                    />
                );
            },
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

    const offerStatusColors = {
        PENDING: 'warning',
        ACCEPTED: 'success',
        DECLINED: 'error',
        EXPIRED: 'default',
    };

    const waitlistOfferColumns = [
        {
            field: 'userName',
            headerName: 'User',
            flex: 1,
            minWidth: 150,
        },
        {
            field: 'status',
            headerName: 'Status',
            width: 120,
            renderCell: (params) => (
                <Chip
                    label={params.value}
                    size="small"
                    color={offerStatusColors[params.value] || 'default'}
                />
            ),
        },
        {
            field: 'priorityScore',
            headerName: 'Priority',
            width: 90,
            renderCell: (params) => (
                <Chip
                    icon={<StarIcon sx={{ fontSize: 16 }} />}
                    label={params.value || 0}
                    size="small"
                    variant="outlined"
                />
            ),
        },
        {
            field: 'remainingMinutes',
            headerName: 'Time Left',
            width: 120,
            renderCell: (params) => {
                if (params.row.status !== 'PENDING') return '-';
                const mins = params.value;
                if (mins <= 0) return <Chip label="Expired" size="small" color="error" />;
                return (
                    <Chip
                        icon={<TimerIcon sx={{ fontSize: 16 }} />}
                        label={`${mins} min`}
                        size="small"
                        color={mins <= 5 ? 'error' : mins <= 15 ? 'warning' : 'info'}
                    />
                );
            },
        },
        {
            field: 'createdAt',
            headerName: 'Offered At',
            width: 160,
            valueFormatter: (params) => {
                if (!params.value) return '';
                return new Date(params.value).toLocaleString();
            },
        },
        {
            field: 'expiresAt',
            headerName: 'Expires At',
            width: 160,
            valueFormatter: (params) => {
                if (!params.value) return '';
                return new Date(params.value).toLocaleString();
            },
        },
    ];

    return (
        <Box>
            <PageHeader
                title="Registrations"
                subtitle="Approve attendees, run QR check-in and manage waiting-list offers."
                icon={<HowToRegIcon />}
                actions={[
                    <Button key="refresh" startIcon={<RefreshIcon />} onClick={() => { loadRegistrations(); loadWaitingList(); loadWaitlistOffers(); }}>
                        Refresh
                    </Button>,
                    <Button
                        key="export"
                        variant="contained"
                        startIcon={<DownloadIcon />}
                        onClick={handleExport}
                        disabled={!selectedEvent}
                    >
                        Export Excel
                    </Button>,
                ]}
            />

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
                        <Grid container spacing={2} sx={{ mb: 2 }}>
                            <Grid item xs={12} md={4}>
                                <StatCard
                                    label="Total Registrations"
                                    value={selectedEventData.currentRegistrations || 0}
                                    icon={<HowToRegIcon />}
                                    iconColor="primary"
                                />
                            </Grid>
                            <Grid item xs={12} md={4}>
                                <StatCard
                                    label="Capacity"
                                    value={selectedEventData.capacity || '∞'}
                                    icon={<StarIcon />}
                                    iconColor="info"
                                />
                            </Grid>
                            <Grid item xs={12} md={4}>
                                <StatCard
                                    label="Waiting List"
                                    value={waitingList.length}
                                    icon={<TimerIcon />}
                                    iconColor="warning"
                                />
                            </Grid>
                        </Grid>
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
                            <Tab
                                label={
                                    <Badge badgeContent={waitlistOffers.filter(o => o.status === 'PENDING').length} color="info">
                                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, pr: 2 }}>
                                            <OfferIcon sx={{ fontSize: 18 }} />
                                            <span>Waitlist Offers</span>
                                        </Box>
                                    </Badge>
                                }
                            />
                        </Tabs>

                        {tabValue === 0 && (
                            <>
                                <Box sx={{ display: 'flex', gap: 1, p: 2, pb: 0, flexWrap: 'wrap' }}>
                                    <TextField
                                        size="small"
                                        placeholder="Search name / email / phone / ticket code..."
                                        value={quickSearch}
                                        onChange={(e) => setQuickSearch(e.target.value)}
                                        sx={{ flex: 1, minWidth: 260 }}
                                        InputProps={{
                                            startAdornment: (
                                                <InputAdornment position="start">
                                                    <SearchIcon fontSize="small" />
                                                </InputAdornment>
                                            ),
                                            endAdornment: quickSearch ? (
                                                <InputAdornment position="end">
                                                    <IconButton size="small" onClick={() => setQuickSearch('')}>
                                                        <CloseIcon fontSize="small" />
                                                    </IconButton>
                                                </InputAdornment>
                                            ) : null,
                                        }}
                                    />
                                    <Button
                                        variant="contained"
                                        color="primary"
                                        startIcon={<QrCodeScannerIcon />}
                                        onClick={() => setScanDialog(true)}
                                    >
                                        Scan QR / Check-in
                                    </Button>
                                </Box>
                                {quickSearch && (
                                    <Box sx={{ px: 2, pt: 1 }}>
                                        <Typography variant="caption" color="text.secondary">
                                            Showing {filteredRegistrations.length} of {registrations.length} matching "{quickSearch}"
                                        </Typography>
                                    </Box>
                                )}
                                <DataGrid
                                    rows={filteredRegistrations}
                                    columns={columns}
                                    loading={loading}
                                    paginationModel={paginationModel}
                                    onPaginationModelChange={setPaginationModel}
                                    pageSizeOptions={[10, 25, 50]}
                                    rowCount={quickSearch ? filteredRegistrations.length : totalRows}
                                    paginationMode={quickSearch ? 'client' : 'server'}
                                    disableRowSelectionOnClick
                                    autoHeight
                                />
                            </>
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

                        {tabValue === 2 && (
                            <Box>
                                {waitlistOffers.length > 0 ? (
                                    <DataGrid
                                        rows={waitlistOffers}
                                        columns={waitlistOfferColumns}
                                        pageSizeOptions={[10, 25]}
                                        disableRowSelectionOnClick
                                        autoHeight
                                        initialState={{
                                            sorting: {
                                                sortModel: [{ field: 'createdAt', sort: 'desc' }],
                                            },
                                        }}
                                    />
                                ) : (
                                    <Box sx={{ p: 4, textAlign: 'center' }}>
                                        <OfferIcon sx={{ fontSize: 48, color: 'text.disabled', mb: 1 }} />
                                        <Typography color="text.secondary">
                                            No waitlist offers yet. Offers are automatically created when a spot opens up.
                                        </Typography>
                                    </Box>
                                )}
                            </Box>
                        )}
                    </Paper>
                </>
            ) : (
                <SectionCard noPadding>
                    <EmptyState
                        title="Select an event"
                        description="Please select an event above to view its registrations."
                        icon={<EventBusyIcon sx={{ fontSize: 40 }} />}
                    />
                </SectionCard>
            )}

            <FormDialog
                open={answersDialog.open}
                onClose={() => setAnswersDialog({ open: false, registration: null, answers: [] })}
                maxWidth="md"
                title={answersDialog.registration?.userName || 'Registration'}
                subtitle="Registration details & decision support"
                icon={
                    <Avatar src={answersDialog.registration?.userAvatarUrl} sx={{ width: 40, height: 40 }}>
                        {answersDialog.registration?.userName?.charAt(0)}
                    </Avatar>
                }
                actions={
                    <>
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
                                <LoadingButton
                                    variant="contained"
                                    color="success"
                                    onClick={() => {
                                        setAnswersDialog({ open: false, registration: null, answers: [] });
                                        handleApprove(answersDialog.registration);
                                    }}
                                >
                                    Approve
                                </LoadingButton>
                            </>
                        )}
                    </>
                }
            >
                {/* Decision Support Dashboard */}
                <Box sx={{ mb: 3 }}>
                    <Typography variant="h6" fontWeight="bold" gutterBottom sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        🎯 Decision Support Dashboard
                    </Typography>
                    <Paper variant="outlined" sx={{ p: 2.5, bgcolor: 'linear-gradient(135deg, rgba(103,58,183,0.05) 0%, rgba(63,81,181,0.05) 100%)', borderRadius: 3 }}>
                        <Grid container spacing={3}>
                            {/* Overall Score */}
                            <Grid item xs={12} sm={4}>
                                <Box sx={{ textAlign: 'center', p: 2, bgcolor: 'background.paper', borderRadius: 2, boxShadow: 1 }}>
                                    <Typography variant="caption" color="text.secondary" fontWeight={500}>
                                        RELIABILITY SCORE
                                    </Typography>
                                    <Box sx={{ display: 'flex', alignItems: 'baseline', justifyContent: 'center', gap: 1, mt: 1 }}>
                                        <Typography 
                                            variant="h2" 
                                            fontWeight="bold" 
                                            sx={{ 
                                                color: (answersDialog.registration?.totalScore || 0) >= 70 ? "success.main" :
                                                       (answersDialog.registration?.totalScore || 0) >= 40 ? "warning.main" : "error.main"
                                            }}
                                        >
                                            {answersDialog.registration?.totalScore || 0}
                                        </Typography>
                                        <Typography variant="h6" color="text.secondary">/ 100</Typography>
                                    </Box>
                                    <Chip 
                                        label={(answersDialog.registration?.totalScore || 0) >= 70 ? "Excellent" : 
                                               (answersDialog.registration?.totalScore || 0) >= 40 ? "Good" : "Caution"}
                                        size="small"
                                        color={(answersDialog.registration?.totalScore || 0) >= 70 ? "success" : 
                                              (answersDialog.registration?.totalScore || 0) >= 40 ? "warning" : "error"}
                                        sx={{ mt: 1 }}
                                    />
                                </Box>
                            </Grid>

                            {/* Key Metrics */}
                            <Grid item xs={12} sm={8}>
                                <Grid container spacing={2}>
                                    <Grid item xs={6}>
                                        <Box sx={{ p: 2, bgcolor: 'background.paper', borderRadius: 2, boxShadow: 1 }}>
                                            <Typography variant="caption" color="text.secondary">📊 Event History</Typography>
                                            <Typography variant="h5" fontWeight="bold" color="success.main">
                                                {answersDialog.registration?.pastEventsAttended || 0}
                                            </Typography>
                                            <Typography variant="body2" color="text.secondary">events checked-in</Typography>
                                        </Box>
                                    </Grid>
                                    <Grid item xs={6}>
                                        <Box sx={{ p: 2, bgcolor: 'background.paper', borderRadius: 2, boxShadow: 1 }}>
                                            <Typography variant="caption" color="text.secondary">⚠️ No-Show Record</Typography>
                                            <Typography 
                                                variant="h5" 
                                                fontWeight="bold" 
                                                color={(answersDialog.registration?.pastNoShows || 0) > 0 ? "error.main" : "success.main"}
                                            >
                                                {answersDialog.registration?.pastNoShows || 0}
                                            </Typography>
                                            <Typography variant="body2" color="text.secondary">
                                                {(answersDialog.registration?.pastNoShows || 0) > 0 ? "previous no-shows" : "clean record ✓"}
                                            </Typography>
                                        </Box>
                                    </Grid>
                                    <Grid item xs={6}>
                                        <Box sx={{ p: 2, bgcolor: 'background.paper', borderRadius: 2, boxShadow: 1 }}>
                                            <Typography variant="caption" color="text.secondary">🎯 Fit Level</Typography>
                                            <Typography 
                                                variant="h5" 
                                                fontWeight="bold"
                                                sx={{ color: getFitColor(answersDialog.registration?.fitLevel) }}
                                            >
                                                {getFitLabel(answersDialog.registration?.fitLevel)}
                                            </Typography>
                                            <Typography variant="body2" color="text.secondary">with this event</Typography>
                                        </Box>
                                    </Grid>
                                    <Grid item xs={6}>
                                        <Box sx={{ p: 2, bgcolor: 'background.paper', borderRadius: 2, boxShadow: 1 }}>
                                            <Typography variant="caption" color="text.secondary">✓ Verified</Typography>
                                            <Typography variant="h5" fontWeight="bold" color="primary.main">
                                                {answersDialog.registration?.isVerified ? "YES" : "NO"}
                                            </Typography>
                                            <Typography variant="body2" color="text.secondary">
                                                {answersDialog.registration?.isVerified ? "profile verified" : "not verified"}
                                            </Typography>
                                        </Box>
                                    </Grid>
                                </Grid>
                            </Grid>
                        </Grid>

                        {/* Score Breakdown & Warnings */}
                        {(answersDialog.registration?.scoreReasons?.length > 0 || 
                          answersDialog.registration?.warningFlags?.length > 0 ||
                          answersDialog.registration?.scoreBreakdown) && (
                            <Box sx={{ mt: 2, pt: 2, borderTop: '1px dashed', borderColor: 'divider' }}>
                                <Grid container spacing={2}>
                                    <Grid item xs={6}>
                                        <Typography variant="subtitle2" color="success.main" gutterBottom fontWeight={600}>
                                            ✓ Positive Signals
                                        </Typography>
                                        {answersDialog.registration?.scoreReasons?.length > 0 ? (
                                            answersDialog.registration?.scoreReasons?.map((r, i) => (
                                                <Typography 
                                                    key={i} 
                                                    variant="body2" 
                                                    sx={{ 
                                                        display: 'flex', 
                                                        alignItems: 'flex-start',
                                                        gap: 1,
                                                        py: 0.5,
                                                        color: 'success.dark'
                                                    }}
                                                >
                                                    <span>•</span>{r}
                                                </Typography>
                                            ))
                                        ) : (
                                            <Typography variant="body2" color="text.secondary" fontStyle="italic">No specific reasons</Typography>
                                        )}
                                    </Grid>
                                    <Grid item xs={6}>
                                        <Typography variant="subtitle2" color="error.main" gutterBottom fontWeight={600}>
                                            ⚠️ Warning Flags
                                        </Typography>
                                        {answersDialog.registration?.warningFlags?.length > 0 ? (
                                            answersDialog.registration?.warningFlags?.map((w, i) => (
                                                <Typography 
                                                    key={i} 
                                                    variant="body2" 
                                                    sx={{ 
                                                        display: 'flex', 
                                                        alignItems: 'flex-start',
                                                        gap: 1,
                                                        py: 0.5,
                                                        color: 'error.main'
                                                    }}
                                                >
                                                    <span>⚠</span>{w}
                                                </Typography>
                                            ))
                                        ) : (
                                            <Typography variant="body2" color="text.secondary" fontStyle="italic">No warnings ✓</Typography>
                                        )}
                                    </Grid>
                                </Grid>
                            </Box>
                        )}
                    </Paper>
                </Box>

                {/* Professional Profile */}
                <Box sx={{ mb: 3 }}>
                    <Typography variant="h6" fontWeight="bold" gutterBottom sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        💼 Professional Profile
                    </Typography>
                    <Paper variant="outlined" sx={{ p: 2.5, borderRadius: 2 }}>
                        <Grid container spacing={2.5}>
                            <Grid item xs={12} sm={6}>
                                <Typography variant="subtitle2" color="text.secondary">Job Title</Typography>
                                <Typography variant="body1" fontWeight={600}>
                                    {answersDialog.registration?.jobTitle || 'N/A'}
                                </Typography>
                            </Grid>
                            <Grid item xs={12} sm={6}>
                                <Typography variant="subtitle2" color="text.secondary">Company</Typography>
                                <Typography variant="body1" fontWeight={600}>
                                    {answersDialog.registration?.company || 'N/A'}
                                </Typography>
                            </Grid>
                            <Grid item xs={12} sm={6}>
                                <Typography variant="subtitle2" color="text.secondary">Industry</Typography>
                                <Typography variant="body1" fontWeight={600}>
                                    {answersDialog.registration?.industry || 'N/A'}
                                </Typography>
                            </Grid>
                            <Grid item xs={12} sm={6}>
                                <Typography variant="subtitle2" color="text.secondary">Experience Level</Typography>
                                <Typography variant="body1" fontWeight={600}>
                                    {answersDialog.registration?.experienceLevel || 'N/A'}
                                </Typography>
                            </Grid>
                            {answersDialog.registration?.linkedinUrl && (
                                <Grid item xs={12}>
                                    <Button
                                        variant="outlined"
                                        startIcon={<Avatar src="/static/linkedin-icon.png" sx={{ width: 20, height: 20 }}/>}
                                        href={answersDialog.registration.linkedinUrl}
                                        target="_blank"
                                        size="small"
                                    >
                                        View LinkedIn Profile
                                    </Button>
                                </Grid>
                            )}
                        </Grid>
                    </Paper>
                </Box>

                {/* Registration Goals & Compatibility */}
                <Box sx={{ mb: 3 }}>
                    <Typography variant="h6" fontWeight="bold" gutterBottom sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        🎯 Registration Goals & Compatibility
                    </Typography>
                    <Paper variant="outlined" sx={{ p: 2.5, borderRadius: 2 }}>
                        <Grid container spacing={2}>
                            {answersDialog.registration?.registrationGoals && (
                                <Grid item xs={12}>
                                    <Typography variant="subtitle2" color="text.secondary">Goals for attending</Typography>
                                    <Typography variant="body1" sx={{ mt: 0.5 }}>
                                        {answersDialog.registration?.registrationGoals}
                                    </Typography>
                                </Grid>
                            )}
                            {answersDialog.registration?.expectations && (
                                <Grid item xs={12}>
                                    <Typography variant="subtitle2" color="text.secondary">Expectations</Typography>
                                    <Typography variant="body1" sx={{ mt: 0.5 }}>
                                        {answersDialog.registration?.expectations}
                                    </Typography>
                                </Grid>
                            )}
                            {answersDialog.registration?.compatibilityNotes && (
                                <Grid item xs={12}>
                                    <Typography variant="subtitle2" color="text.secondary">Compatibility Notes</Typography>
                                    <Typography variant="body1" sx={{ mt: 0.5 }} fontStyle="italic">
                                        {answersDialog.registration?.compatibilityNotes}
                                    </Typography>
                                </Grid>
                            )}
                        </Grid>
                    </Paper>
                </Box>

                {/* Contact Information */}
                <Box sx={{ mb: 3 }}>
                    <Typography variant="h6" fontWeight="bold" gutterBottom sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        📧 Contact Information
                    </Typography>
                    <Paper variant="outlined" sx={{ p: 2.5, borderRadius: 2 }}>
                        <List dense sx={{ p: 0 }}>
                            <ListItem sx={{ px: 0 }}>
                                <EmailIcon sx={{ mr: 2, color: 'primary.main' }} />
                                <ListItemText
                                    primary={answersDialog.registration?.userEmail || 'N/A'}
                                    secondary="Email"
                                    primaryTypographyProps={{ fontWeight: 500 }}
                                />
                            </ListItem>
                            {answersDialog.registration?.userPhone && (
                                <ListItem sx={{ px: 0 }}>
                                    <PhoneIcon sx={{ mr: 2, color: 'primary.main' }} />
                                    <ListItemText
                                        primary={answersDialog.registration?.userPhone || 'N/A'}
                                        secondary="Phone"
                                        primaryTypographyProps={{ fontWeight: 500 }}
                                    />
                                </ListItem>
                            )}
                            <ListItem sx={{ px: 0 }}>
                                <TimeIcon sx={{ mr: 2, color: 'primary.main' }} />
                                <ListItemText
                                    primary={answersDialog.registration?.createdAt
                                        ? new Date(answersDialog.registration.createdAt).toLocaleString()
                                        : 'N/A'}
                                    secondary="Registered At"
                                    primaryTypographyProps={{ fontWeight: 500 }}
                                />
                            </ListItem>
                        </List>
                    </Paper>
                </Box>

                {/* Registration Answers (Custom Questions) */}
                <Box sx={{ mb: 3 }}>
                    <Typography variant="h6" fontWeight="bold" gutterBottom sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        📝 Registration Answers (Event-Specific Questions)
                    </Typography>
                    <Paper variant="outlined" sx={{ p: 2.5, borderRadius: 2, bgcolor: 'rgba(103,58,183,0.03)' }}>
                        {loadingAnswers ? (
                            <Box sx={{ textAlign: 'center', py: 4 }}>
                                <Typography color="text.secondary">Loading answers...</Typography>
                            </Box>
                        ) : answersDialog.answers.length > 0 ? (
                            <List sx={{ p: 0 }}>
                                {answersDialog.answers.map((answer, index) => (
                                    <React.Fragment key={answer.id || index}>
                                        {index > 0 && <Divider />}
                                        <ListItem sx={{ px: 0, py: 2.5 }}>
                                            <ListItemText
                                                primary={
                                                    <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 1, mb: 1 }}>
                                                        <Typography variant="subtitle2" fontWeight={600} color="primary.main">
                                                            Q{index + 1}. {answer.questionText || 'Question'}
                                                        </Typography>
                                                        {answer.isRequired && (
                                                            <Chip 
                                                                label="Required" 
                                                                size="small" 
                                                                sx={{ height: 20, fontSize: '0.7rem' }}
                                                            />
                                                        )}
                                                    </Box>
                                                }
                                                secondary={
                                                    <Box>
                                                        <Typography variant="body1" fontWeight={500} sx={{ whiteSpace: 'pre-wrap' }}>
                                                            {answer.answer || answer.answerText || 'No answer provided'}
                                                        </Typography>
                                                        {answer.questionType && (
                                                            <Chip 
                                                                label={formatQuestionType(answer.questionType)}
                                                                size="small"
                                                                sx={{ mt: 1 }}
                                                                variant="outlined"
                                                            />
                                                        )}
                                                    </Box>
                                                }
                                            />
                                        </ListItem>
                                    </React.Fragment>
                                ))}
                            </List>
                        ) : (
                            <Box sx={{ textAlign: 'center', py: 4 }}>
                                <Typography variant="body2" color="text.secondary">
                                    No custom questions for this event
                                </Typography>
                                <Typography variant="caption" color="text.secondary">
                                    User only filled in their profile information (Job Title, Company, etc.)
                                </Typography>
                            </Box>
                        )}
                    </Paper>
                </Box>
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

            <Dialog open={scanDialog} onClose={() => setScanDialog(false)} maxWidth="md" fullWidth>
                <DialogTitle sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <QrCodeScannerIcon color="primary" />
                        <Box>
                            <Typography variant="h6" sx={{ lineHeight: 1.2 }}>Quick Check-in</Typography>
                            {selectedEventData && (
                                <Typography variant="caption" color="text.secondary">
                                    Event: {selectedEventData.title}
                                </Typography>
                            )}
                        </Box>
                    </Box>
                    <IconButton onClick={() => setScanDialog(false)} size="small">
                        <CloseIcon />
                    </IconButton>
                </DialogTitle>
                <DialogContent>
                    <Grid container spacing={2}>
                        <Grid item xs={12} md={6}>
                            <Typography variant="subtitle2" gutterBottom>📷 Camera Scan</Typography>
                            <Box
                                id="qr-scan-region"
                                ref={qrRegionRef}
                                sx={{
                                    width: '100%',
                                    mb: 2,
                                    border: '2px dashed',
                                    borderColor: 'divider',
                                    borderRadius: 2,
                                    minHeight: 280,
                                    overflow: 'hidden',
                                    bgcolor: 'black',
                                }}
                            />

                            <Typography variant="subtitle2" gutterBottom>⌨️ Manual / USB scanner</Typography>
                            <TextField
                                fullWidth
                                autoFocus
                                size="small"
                                placeholder="Paste/scan code + Enter"
                                value={scanManualCode}
                                onChange={(e) => setScanManualCode(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter' && scanManualCode.trim()) {
                                        performCheckInByCode(scanManualCode);
                                    }
                                }}
                                disabled={scanBusy}
                                InputProps={{
                                    endAdornment: (
                                        <InputAdornment position="end">
                                            <Button
                                                size="small"
                                                variant="contained"
                                                disabled={scanBusy || !scanManualCode.trim()}
                                                onClick={() => performCheckInByCode(scanManualCode)}
                                            >
                                                Check-in
                                            </Button>
                                        </InputAdornment>
                                    ),
                                }}
                            />
                        </Grid>

                        <Grid item xs={12} md={6}>
                            <Typography variant="subtitle2" gutterBottom>🎫 Last scan</Typography>
                            {!lastScanResult ? (
                                <Paper variant="outlined" sx={{ p: 3, textAlign: 'center', color: 'text.secondary', minHeight: 180 }}>
                                    <QrCodeScannerIcon sx={{ fontSize: 48, opacity: 0.3 }} />
                                    <Typography variant="body2" sx={{ mt: 1 }}>
                                        Waiting for first scan...
                                    </Typography>
                                </Paper>
                            ) : lastScanResult.status === 'success' ? (
                                <Paper variant="outlined" sx={{ p: 2, borderLeft: '4px solid', borderLeftColor: 'success.main', bgcolor: 'success.light', minHeight: 180 }}>
                                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 1 }}>
                                        <Avatar src={lastScanResult.avatarUrl} sx={{ width: 48, height: 48, bgcolor: 'success.main' }}>
                                            {lastScanResult.name?.charAt(0) || '?'}
                                        </Avatar>
                                        <Box sx={{ flex: 1 }}>
                                            <Typography variant="body1" fontWeight="bold" color="success.dark">
                                                ✓ {lastScanResult.name}
                                            </Typography>
                                            <Typography variant="caption" color="success.dark">
                                                Checked in at {lastScanResult.at.toLocaleTimeString()}
                                            </Typography>
                                        </Box>
                                    </Box>
                                    <Divider sx={{ my: 1 }} />
                                    {lastScanResult.email && (
                                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                                            <EmailIcon sx={{ fontSize: 14 }} />
                                            <Typography variant="caption">{lastScanResult.email}</Typography>
                                        </Box>
                                    )}
                                    {lastScanResult.phone && (
                                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, mt: 0.5 }}>
                                            <PhoneIcon sx={{ fontSize: 14 }} />
                                            <Typography variant="caption">{lastScanResult.phone}</Typography>
                                        </Box>
                                    )}
                                    {lastScanResult.ticketTypeName && (
                                        <Box sx={{ mt: 1 }}>
                                            <Chip
                                                size="small"
                                                color="primary"
                                                label={`${lastScanResult.ticketTypeName} × ${lastScanResult.quantity}${lastScanResult.ticketTypePrice ? ' · $' + Number(lastScanResult.ticketTypePrice).toFixed(2) : ''}`}
                                            />
                                        </Box>
                                    )}
                                    <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 1, fontFamily: 'monospace' }}>
                                        Code: {lastScanResult.code}
                                    </Typography>
                                </Paper>
                            ) : (() => {
                                const err = describeScanError(lastScanResult.message);
                                return (
                                    <Paper variant="outlined" sx={{ p: 2, borderLeft: '4px solid', borderLeftColor: 'error.main', bgcolor: 'error.light', minHeight: 180 }}>
                                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                            <Typography sx={{ fontSize: 22 }}>{err.emoji}</Typography>
                                            <Typography variant="body1" fontWeight="bold" color="error.dark">
                                                {err.title}
                                            </Typography>
                                        </Box>
                                        <Typography variant="caption" color="error.dark" sx={{ display: 'block', mt: 0.5 }}>
                                            {lastScanResult.at.toLocaleTimeString()}
                                        </Typography>
                                        <Divider sx={{ my: 1 }} />
                                        <Typography variant="body2" color="error.dark">
                                            {err.detail}
                                        </Typography>
                                        {!err.hideCode && (
                                            <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 1, fontFamily: 'monospace', wordBreak: 'break-all' }}>
                                                Code: {lastScanResult.code}
                                            </Typography>
                                        )}
                                    </Paper>
                                );
                            })()}
                        </Grid>

                        {scanHistory.length > 0 && (
                            <Grid item xs={12}>
                                <Divider sx={{ my: 1 }} />
                                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
                                    <Typography variant="subtitle2">
                                        Scan History ({scanHistory.length}) —
                                        <Box component="span" sx={{ color: 'success.main', ml: 1 }}>
                                            ✓ {scanHistory.filter(s => s.status === 'success').length} ok
                                        </Box>
                                        <Box component="span" sx={{ color: 'error.main', ml: 1 }}>
                                            ✗ {scanHistory.filter(s => s.status === 'error').length} failed
                                        </Box>
                                    </Typography>
                                    <Button size="small" onClick={() => { setScanHistory([]); setLastScanResult(null); }}>
                                        Clear
                                    </Button>
                                </Box>
                                <Box sx={{ maxHeight: 180, overflow: 'auto' }}>
                                    {scanHistory.map((s, i) => (
                                        <Box key={i} sx={{
                                            display: 'flex', alignItems: 'center', gap: 1, py: 0.5, px: 1,
                                            borderRadius: 1,
                                            bgcolor: s.status === 'success' ? 'success.light' : 'error.light',
                                            mb: 0.5,
                                        }}>
                                            <Typography sx={{ fontSize: 16 }}>
                                                {s.status === 'success' ? '✓' : '✗'}
                                            </Typography>
                                            <Typography variant="caption" sx={{ fontFamily: 'monospace', minWidth: 70 }}>
                                                {s.at.toLocaleTimeString()}
                                            </Typography>
                                            <Typography variant="body2" sx={{ flex: 1 }} noWrap>
                                                {s.status === 'success'
                                                    ? `${s.name}${s.ticketTypeName ? ' · ' + s.ticketTypeName + '×' + s.quantity : ''}`
                                                    : describeScanError(s.message).title}
                                            </Typography>
                                            {(s.status === 'success' || !describeScanError(s.message).hideCode) && (
                                                <Typography variant="caption" color="text.secondary" sx={{ fontFamily: 'monospace' }} noWrap>
                                                    {s.code}
                                                </Typography>
                                            )}
                                        </Box>
                                    ))}
                                </Box>
                            </Grid>
                        )}
                    </Grid>
                </DialogContent>
                <DialogActions>
                    <Typography variant="caption" color="text.secondary" sx={{ flex: 1, pl: 2 }}>
                        Keep open to scan multiple guests · Duplicates within 2.5s are auto-ignored
                    </Typography>
                    <Button onClick={() => setScanDialog(false)}>Close</Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default OrganiserRegistrations;

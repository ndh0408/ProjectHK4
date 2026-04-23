import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Typography,
    Button,
    Avatar,
    Menu,
    MenuItem,
    ListItemIcon,
    ListItemText,
    IconButton,
    Tooltip,
    Tabs,
    Tab,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    Chip,
    Stack,
    Grid,
    TextField,
    Link,
    Divider,
    Alert,
    Badge,
} from '@mui/material';
import {
    Refresh as RefreshIcon,
    Verified as VerifiedIcon,
    MoreVert as MoreVertIcon,
    CheckCircle as ActiveIcon,
    Block as LockIcon,
    Business as BusinessIcon,
    CheckCircle as ApproveIcon,
    Cancel as RejectIcon,
    OpenInNew as OpenIcon,
    Close as CloseIcon,
    Description as LicenseIcon,
    Badge as IdIcon,
    AutoAwesome as AIIcon,
    Warning as WarningIcon,
} from '@mui/icons-material';
import { adminApi } from '../../api';
import { ConfirmDialog } from '../../components/common';
import {
    PageHeader,
    PageToolbar,
    DataTableCard,
    StatusChip,
    LoadingButton,
} from '../../components/ui';
import { toast } from 'react-toastify';

const AI_CHIP_COLOR = {
    VALID: 'success',
    SUSPICIOUS: 'warning',
    INVALID: 'error',
    UNAVAILABLE: 'default',
};

const DOC_LABEL = {
    BUSINESS_LICENSE: 'Business License',
    CITIZEN_ID: 'Citizen ID',
};

const STATUS_CHIP_VARIANT = {
    PENDING: 'warning',
    APPROVED: 'success',
    REJECTED: 'error',
};

const Organisers = () => {
    const [tab, setTab] = useState(0);
    const [stats, setStats] = useState({ pendingApplications: 0, pendingBadgeRequests: 0 });

    const loadStats = useCallback(async () => {
        try {
            const response = await adminApi.getVerificationStats();
            setStats({
                pendingApplications: response.data.data?.pendingApplications || 0,
                pendingBadgeRequests: response.data.data?.pendingBadgeRequests || 0,
            });
        } catch {
            // non-fatal
        }
    }, []);

    useEffect(() => {
        loadStats();
    }, [loadStats]);

    return (
        <Box>
            <PageHeader
                title="Organisers"
                subtitle="Review applications, badge requests and manage all organiser accounts"
                icon={<BusinessIcon />}
            />

            <Tabs
                value={tab}
                onChange={(_, v) => setTab(v)}
                textColor="primary"
                indicatorColor="primary"
                sx={{ mb: 2.5, borderBottom: '1px solid', borderColor: 'divider' }}
            >
                <Tab
                    label={(
                        <Stack direction="row" alignItems="center" spacing={1}>
                            <span>Pending Applications</span>
                            {stats.pendingApplications > 0 && (
                                <Badge badgeContent={stats.pendingApplications} color="warning" max={99} />
                            )}
                        </Stack>
                    )}
                />
                <Tab
                    label={(
                        <Stack direction="row" alignItems="center" spacing={1}>
                            <span>Badge Requests</span>
                            {stats.pendingBadgeRequests > 0 && (
                                <Badge badgeContent={stats.pendingBadgeRequests} color="info" max={99} />
                            )}
                        </Stack>
                    )}
                />
                <Tab label="All Organisers" />
            </Tabs>

            {tab === 0 && <VerificationQueue isApplication={true} onChange={loadStats} />}
            {tab === 1 && <VerificationQueue isApplication={false} onChange={loadStats} />}
            {tab === 2 && <AllOrganisersList />}
        </Box>
    );
};

// ==========================================
// TAB 1 + 2: Verification Queue (Applications / Badge Requests)
// ==========================================

const VerificationQueue = ({ isApplication, onChange }) => {
    const [statusFilter, setStatusFilter] = useState('PENDING');
    const [requests, setRequests] = useState([]);
    const [loading, setLoading] = useState(true);
    const [paginationModel, setPaginationModel] = useState({ page: 0, pageSize: 10 });
    const [totalRows, setTotalRows] = useState(0);

    const [selected, setSelected] = useState(null);
    const [reviewOpen, setReviewOpen] = useState(false);
    const [rejectReason, setRejectReason] = useState('');
    const [reviewingAction, setReviewingAction] = useState(null);
    const [previewUrl, setPreviewUrl] = useState(null);

    const load = useCallback(async () => {
        setLoading(true);
        try {
            const response = await adminApi.getVerificationRequests({
                page: paginationModel.page,
                size: paginationModel.pageSize,
                status: statusFilter || undefined,
                isApplication,
            });
            const data = response.data.data;
            setRequests(data.content || []);
            setTotalRows(data.totalElements || 0);
        } catch {
            toast.error('Failed to load');
        } finally {
            setLoading(false);
        }
    }, [paginationModel, statusFilter, isApplication]);

    useEffect(() => {
        load();
    }, [load]);

    const openReview = (row) => {
        setSelected(row);
        setRejectReason('');
        setReviewOpen(true);
    };

    const closeReview = () => {
        if (reviewingAction) return;
        setReviewOpen(false);
        setSelected(null);
        setRejectReason('');
    };

    const handleApprove = async (grantBadge) => {
        if (!selected) return;
        setReviewingAction(grantBadge ? 'approve-badge' : 'approve');
        try {
            await adminApi.reviewVerification(selected.id, {
                approve: true,
                grantVerifiedBadge: Boolean(grantBadge),
            });
            toast.success(
                grantBadge
                    ? 'Approved with Verified Badge'
                    : (selected.isApplication ? 'Applicant approved as organiser' : 'Approved')
            );
            setReviewOpen(false);
            setSelected(null);
            load();
            onChange?.();
        } catch (e) {
            toast.error(e.response?.data?.message || 'Failed to approve');
        } finally {
            setReviewingAction(null);
        }
    };

    const handleReject = async () => {
        if (!selected) return;
        if (!rejectReason.trim()) {
            toast.error('Please provide a reason for rejection');
            return;
        }
        setReviewingAction('reject');
        try {
            await adminApi.reviewVerification(selected.id, {
                approve: false,
                grantVerifiedBadge: false,
                rejectReason: rejectReason.trim(),
            });
            toast.success('Rejected');
            setReviewOpen(false);
            setSelected(null);
            setRejectReason('');
            load();
            onChange?.();
        } catch (e) {
            toast.error(e.response?.data?.message || 'Failed to reject');
        } finally {
            setReviewingAction(null);
        }
    };

    const columns = [
        {
            field: 'organiser',
            headerName: 'Applicant',
            flex: 1.4,
            minWidth: 220,
            sortable: false,
            renderCell: (params) => (
                <Stack direction="row" spacing={1.5} alignItems="center" sx={{ minWidth: 0 }}>
                    <Avatar src={params.row.organiserAvatarUrl} sx={{ width: 36, height: 36 }}>
                        {params.row.organiserName?.charAt(0)}
                    </Avatar>
                    <Box sx={{ minWidth: 0 }}>
                        <Typography variant="body2" fontWeight={600} noWrap>
                            {params.row.organisationName || params.row.organiserName}
                        </Typography>
                        <Typography variant="caption" color="text.secondary" noWrap>
                            {params.row.organiserEmail}
                        </Typography>
                    </Box>
                </Stack>
            ),
        },
        ...(isApplication ? [] : [{
            field: 'documentType',
            headerName: 'Document',
            minWidth: 170,
            sortable: false,
            renderCell: (params) => params.row.documentType ? (
                <Stack direction="row" alignItems="center" spacing={1}>
                    {params.row.documentType === 'BUSINESS_LICENSE'
                        ? <LicenseIcon fontSize="small" />
                        : <IdIcon fontSize="small" />}
                    <Typography variant="body2">{DOC_LABEL[params.row.documentType]}</Typography>
                </Stack>
            ) : <Typography variant="caption" color="text.disabled">—</Typography>,
        }, {
            field: 'aiStatus',
            headerName: 'AI',
            width: 150,
            sortable: false,
            renderCell: (params) => {
                if (!params.row.aiStatus) return <Typography variant="caption" color="text.disabled">—</Typography>;
                return (
                    <Tooltip title={params.row.aiReason || ''} arrow>
                        <Chip
                            size="small"
                            icon={<AIIcon sx={{ fontSize: 14 }} />}
                            label={`${params.row.aiStatus}${params.row.aiConfidence != null ? ` ${params.row.aiConfidence}%` : ''}`}
                            color={AI_CHIP_COLOR[params.row.aiStatus] || 'default'}
                            variant="outlined"
                        />
                    </Tooltip>
                );
            },
        }]),
        {
            field: 'submittedAt',
            headerName: 'Submitted',
            minWidth: 160,
            renderCell: (params) => (
                <Typography variant="body2" color="text.secondary">
                    {params.row.submittedAt ? new Date(params.row.submittedAt).toLocaleString() : '—'}
                </Typography>
            ),
        },
        {
            field: 'status',
            headerName: 'Status',
            width: 130,
            renderCell: (params) => (
                <StatusChip label={params.row.status} status={STATUS_CHIP_VARIANT[params.row.status] || 'neutral'} />
            ),
        },
        {
            field: 'actions',
            headerName: 'Actions',
            width: 120,
            sortable: false,
            renderCell: (params) => (
                <Button size="small" variant="outlined" onClick={() => openReview(params.row)}>
                    Review
                </Button>
            ),
        },
    ];

    const STATUS_TABS = [
        { value: 'PENDING', label: 'Pending' },
        { value: 'APPROVED', label: 'Approved' },
        { value: 'REJECTED', label: 'Rejected' },
        { value: '', label: 'All' },
    ];

    return (
        <>
            <PageToolbar
                filters={(
                    <Tabs
                        value={statusFilter}
                        onChange={(_, v) => {
                            setStatusFilter(v);
                            setPaginationModel((p) => ({ ...p, page: 0 }));
                        }}
                        textColor="primary"
                        indicatorColor="primary"
                    >
                        {STATUS_TABS.map((t) => (
                            <Tab key={t.value || 'all'} value={t.value} label={t.label} />
                        ))}
                    </Tabs>
                )}
                actions={(
                    <Tooltip title="Refresh">
                        <IconButton onClick={load}>
                            <RefreshIcon />
                        </IconButton>
                    </Tooltip>
                )}
            />

            <DataTableCard
                rows={requests}
                columns={columns}
                loading={loading}
                emptyTitle={isApplication ? 'No pending applications' : 'No badge requests'}
                emptyDescription={
                    statusFilter === 'PENDING'
                        ? 'The queue is empty. Nice work!'
                        : 'No requests match this filter.'
                }
                emptyIcon={<BusinessIcon />}
                dataGridProps={{
                    paginationMode: 'server',
                    rowCount: totalRows,
                    paginationModel,
                    onPaginationModelChange: setPaginationModel,
                    getRowId: (row) => row.id,
                    onRowClick: (params) => openReview(params.row),
                }}
            />

            <ReviewDialog
                open={reviewOpen}
                selected={selected}
                rejectReason={rejectReason}
                setRejectReason={setRejectReason}
                reviewingAction={reviewingAction}
                onClose={closeReview}
                onApprove={handleApprove}
                onReject={handleReject}
                onPreview={setPreviewUrl}
            />

            <Dialog
                open={!!previewUrl}
                onClose={() => setPreviewUrl(null)}
                maxWidth="lg"
                PaperProps={{ sx: { bgcolor: 'black' } }}
            >
                <IconButton
                    onClick={() => setPreviewUrl(null)}
                    sx={{ position: 'absolute', top: 8, right: 8, color: 'white', zIndex: 1 }}
                >
                    <CloseIcon />
                </IconButton>
                {previewUrl && (
                    <img
                        src={previewUrl}
                        alt="document-preview"
                        style={{ maxWidth: '100%', maxHeight: '90vh', display: 'block' }}
                    />
                )}
            </Dialog>
        </>
    );
};

const ReviewDialog = ({
    open,
    selected,
    rejectReason,
    setRejectReason,
    reviewingAction,
    onClose,
    onApprove,
    onReject,
    onPreview,
}) => {
    if (!selected) return null;
    const isApp = selected.isApplication;

    return (
        <Dialog
            open={open}
            onClose={onClose}
            maxWidth="md"
            fullWidth
            PaperProps={{ sx: { borderRadius: 3 } }}
        >
            <DialogTitle sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', pr: 2 }}>
                <Stack direction="row" alignItems="center" spacing={1.5}>
                    <BusinessIcon color="primary" />
                    <Box>
                        <Typography variant="h6" sx={{ lineHeight: 1.2 }}>
                            {isApp ? 'Review organiser application' : 'Review Verified badge request'}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                            Submitted {new Date(selected.submittedAt).toLocaleString()}
                        </Typography>
                    </Box>
                </Stack>
                <IconButton onClick={onClose} disabled={!!reviewingAction}>
                    <CloseIcon />
                </IconButton>
            </DialogTitle>
            <DialogContent dividers>
                <Grid container spacing={3}>
                    <Grid item xs={12} md={isApp ? 12 : 6}>
                        <Typography variant="subtitle2" sx={{ mb: 1 }}>Applicant</Typography>
                        <Stack direction="row" spacing={2} alignItems="center" sx={{ mb: 2 }}>
                            <Avatar src={selected.organiserAvatarUrl} sx={{ width: 48, height: 48 }}>
                                {selected.organiserName?.charAt(0)}
                            </Avatar>
                            <Box>
                                <Typography variant="body1" fontWeight={600}>
                                    {selected.organisationName || selected.organiserName}
                                </Typography>
                                <Typography variant="caption" color="text.secondary">
                                    {selected.organiserEmail}
                                </Typography>
                            </Box>
                        </Stack>

                        {isApp ? (
                            <Alert severity="info" sx={{ mb: 2 }}>
                                <Typography variant="body2" fontWeight={600} sx={{ mb: 0.5 }}>
                                    New organiser application
                                </Typography>
                                <Typography variant="caption" component="div">
                                    Approving grants the ORGANISER role so they can publish events.
                                    The Verified badge is evaluated separately when the organiser submits
                                    identity documents from their profile.
                                </Typography>
                            </Alert>
                        ) : (
                            <Alert severity="info" icon={<VerifiedIcon />} sx={{ mb: 2 }}>
                                <Typography variant="body2" fontWeight={600} sx={{ mb: 0.5 }}>
                                    Verified Badge request
                                </Typography>
                                <Typography variant="caption" component="div">
                                    Grant the badge only if the organiser meets the trust criteria
                                    (business licence, public presence, track record).
                                </Typography>
                            </Alert>
                        )}

                        {isApp && (
                            <>
                                <InfoRow label="Bio" value={selected.organisationBio} />
                                <InfoRow
                                    label="Website"
                                    value={selected.organisationWebsite
                                        ? <Link href={selected.organisationWebsite} target="_blank" rel="noopener">{selected.organisationWebsite}</Link>
                                        : null}
                                />
                                <InfoRow label="Contact email" value={selected.organisationContactEmail} />
                                <InfoRow label="Contact phone" value={selected.organisationContactPhone} />
                            </>
                        )}

                        {!isApp && (
                            <>
                                <InfoRow label="Document type" value={DOC_LABEL[selected.documentType]} />
                                <InfoRow label="Legal name" value={selected.legalName} />
                                <InfoRow label="Document number" value={selected.documentNumber} />

                                {selected.documentType === 'CITIZEN_ID' && (
                                    <Alert severity="warning" icon={<WarningIcon />} sx={{ mt: 1 }}>
                                        <Typography variant="caption">
                                            Document is a <strong>Citizen ID</strong>. Granting the Verified
                                            badge to individuals is unusual — prefer business licences.
                                        </Typography>
                                    </Alert>
                                )}

                                <Divider sx={{ my: 2 }} />
                                <Typography variant="subtitle2" sx={{ mb: 1 }}>
                                    <AIIcon sx={{ fontSize: 16, mr: 0.5, verticalAlign: 'middle' }} />
                                    AI pre-check
                                </Typography>
                                {selected.aiStatus ? (
                                    <Box
                                        sx={{
                                            p: 1.5,
                                            borderRadius: 2,
                                            bgcolor: 'grey.50',
                                            border: '1px solid',
                                            borderColor: 'divider',
                                        }}
                                    >
                                        <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 1 }}>
                                            <Chip
                                                size="small"
                                                label={selected.aiStatus}
                                                color={AI_CHIP_COLOR[selected.aiStatus] || 'default'}
                                            />
                                            {selected.aiConfidence != null && (
                                                <Typography variant="caption" color="text.secondary">
                                                    Confidence: {selected.aiConfidence}%
                                                </Typography>
                                            )}
                                        </Stack>
                                        <Typography variant="body2" color="text.secondary">
                                            {selected.aiReason || 'No reason provided.'}
                                        </Typography>
                                        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 1 }}>
                                            AI is a hint only — your manual review is authoritative.
                                        </Typography>
                                    </Box>
                                ) : (
                                    <Typography variant="body2" color="text.secondary">
                                        AI pre-check was not available.
                                    </Typography>
                                )}
                            </>
                        )}
                    </Grid>

                    {!isApp && (
                        <Grid item xs={12} md={6}>
                            <Typography variant="subtitle2" sx={{ mb: 1 }}>
                                Uploaded documents ({selected.documentUrls?.length || 0})
                            </Typography>
                            <Stack spacing={2}>
                                {(selected.documentUrls || []).map((url, i) => (
                                    <Box
                                        key={`${url}-${i}`}
                                        sx={{
                                            position: 'relative',
                                            borderRadius: 2,
                                            overflow: 'hidden',
                                            border: '1px solid',
                                            borderColor: 'divider',
                                            cursor: 'zoom-in',
                                        }}
                                        onClick={() => onPreview(url)}
                                    >
                                        <img
                                            src={url}
                                            alt={`document-${i}`}
                                            style={{ width: '100%', display: 'block' }}
                                        />
                                        <IconButton
                                            size="small"
                                            component="a"
                                            href={url}
                                            target="_blank"
                                            rel="noopener"
                                            onClick={(e) => e.stopPropagation()}
                                            sx={{
                                                position: 'absolute',
                                                top: 8,
                                                right: 8,
                                                bgcolor: 'rgba(0,0,0,0.6)',
                                                color: 'white',
                                                '&:hover': { bgcolor: 'rgba(0,0,0,0.8)' },
                                            }}
                                        >
                                            <OpenIcon fontSize="small" />
                                        </IconButton>
                                    </Box>
                                ))}
                            </Stack>
                        </Grid>
                    )}

                    {selected.status !== 'PENDING' && (
                        <Grid item xs={12}>
                            <Divider />
                            <Stack direction="row" spacing={1.5} alignItems="center" sx={{ mt: 2 }}>
                                <StatusChip
                                    label={selected.status}
                                    status={STATUS_CHIP_VARIANT[selected.status] || 'neutral'}
                                />
                                {selected.reviewedByName && (
                                    <Typography variant="body2" color="text.secondary">
                                        Reviewed by <strong>{selected.reviewedByName}</strong> on {new Date(selected.reviewedAt).toLocaleString()}
                                    </Typography>
                                )}
                            </Stack>
                            {selected.status === 'REJECTED' && selected.rejectReason && (
                                <Alert severity="error" sx={{ mt: 1.5 }}>
                                    {selected.rejectReason}
                                </Alert>
                            )}
                        </Grid>
                    )}

                    {selected.status === 'PENDING' && (
                        <Grid item xs={12}>
                            <Divider sx={{ mb: 2 }} />
                            <Typography variant="subtitle2" sx={{ mb: 1 }}>
                                Reject reason (required only if rejecting)
                            </Typography>
                            <TextField
                                fullWidth
                                multiline
                                rows={3}
                                placeholder="Explain why this is being rejected..."
                                value={rejectReason}
                                onChange={(e) => setRejectReason(e.target.value)}
                                disabled={!!reviewingAction}
                            />
                        </Grid>
                    )}
                </Grid>
            </DialogContent>
            {selected.status === 'PENDING' && (
                <DialogActions sx={{ px: 3, py: 2, flexWrap: 'wrap', gap: 1, justifyContent: 'space-between' }}>
                    <Button onClick={onClose} disabled={!!reviewingAction}>
                        Cancel
                    </Button>
                    <Stack direction="row" spacing={1} flexWrap="wrap" sx={{ rowGap: 1 }}>
                        <LoadingButton
                            variant="outlined"
                            color="error"
                            startIcon={<RejectIcon />}
                            onClick={onReject}
                            loading={reviewingAction === 'reject'}
                            disabled={!!reviewingAction && reviewingAction !== 'reject'}
                        >
                            Reject
                        </LoadingButton>
                        {isApp && (
                            <LoadingButton
                                variant="contained"
                                color="primary"
                                startIcon={<ApproveIcon />}
                                onClick={() => onApprove(false)}
                                loading={reviewingAction === 'approve'}
                                disabled={!!reviewingAction && reviewingAction !== 'approve'}
                            >
                                Approve
                            </LoadingButton>
                        )}
                        {!isApp && (
                            <LoadingButton
                                variant="contained"
                                color="success"
                                startIcon={<VerifiedIcon />}
                                onClick={() => onApprove(true)}
                                loading={reviewingAction === 'approve-badge'}
                                disabled={!!reviewingAction && reviewingAction !== 'approve-badge'}
                            >
                                Grant Verified Badge
                            </LoadingButton>
                        )}
                    </Stack>
                </DialogActions>
            )}
        </Dialog>
    );
};

const InfoRow = ({ label, value }) => (
    <Stack direction="row" spacing={1.5} sx={{ mb: 1 }}>
        <Typography variant="caption" color="text.secondary" sx={{ minWidth: 120, pt: 0.25 }}>
            {label}
        </Typography>
        <Typography variant="body2" sx={{ flex: 1, wordBreak: 'break-word' }}>
            {value || <span style={{ color: 'rgba(0,0,0,0.38)' }}>—</span>}
        </Typography>
    </Stack>
);

// ==========================================
// TAB 3: All organisers list
// ==========================================

const AllOrganisersList = () => {
    const [organisers, setOrganisers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');
    const [paginationModel, setPaginationModel] = useState({ page: 0, pageSize: 10 });
    const [totalRows, setTotalRows] = useState(0);
    const [confirmDialog, setConfirmDialog] = useState({ open: false, title: '', message: '', action: null });
    const [anchorEl, setAnchorEl] = useState(null);
    const [selectedOrganiser, setSelectedOrganiser] = useState(null);

    const load = useCallback(async () => {
        setLoading(true);
        try {
            const response = await adminApi.getOrganisers({
                page: paginationModel.page,
                size: paginationModel.pageSize,
                search: search || undefined,
            });
            setOrganisers(response.data.data.content || []);
            setTotalRows(response.data.data.totalElements || 0);
        } catch {
            toast.error('Failed to load organisers');
        } finally {
            setLoading(false);
        }
    }, [paginationModel, search]);

    useEffect(() => {
        load();
    }, [load]);

    const handleMenuOpen = (event, organiser) => {
        setAnchorEl(event.currentTarget);
        setSelectedOrganiser(organiser);
    };

    const handleMenuClose = () => {
        setAnchorEl(null);
        setSelectedOrganiser(null);
    };

    const handleVerify = (organiser) => {
        handleMenuClose();
        setConfirmDialog({
            open: true,
            title: 'Grant Verified Badge (manual override)',
            message: `Grant the Verified badge to "${organiser.displayName || organiser.fullName}" without a document review?\n\nThis BYPASSES the normal verification flow. Prefer the Badge Requests tab when the organiser has submitted documents. Use this override only for trusted partners or legacy accounts.`,
            action: async () => {
                try {
                    await adminApi.verifyOrganiser(organiser.id);
                    toast.success('Verified badge granted');
                    load();
                } catch {
                    toast.error('Failed to grant badge');
                }
            },
        });
    };

    const handleUnverify = (organiser) => {
        handleMenuClose();
        setConfirmDialog({
            open: true,
            title: 'Revoke Verified Badge',
            message: `Remove the Verified badge from "${organiser.displayName || organiser.fullName}"?\n\nThe organiser will keep their account and can continue to publish events, but the blue Verified tick will be removed from their profile.`,
            action: async () => {
                try {
                    await adminApi.unverifyOrganiser(organiser.id);
                    toast.success('Verified badge revoked');
                    load();
                } catch {
                    toast.error('Failed to revoke badge');
                }
            },
        });
    };

    const handleActivate = (organiser) => {
        handleMenuClose();
        setConfirmDialog({
            open: true,
            title: 'Activate Account',
            message: `Are you sure you want to activate "${organiser.displayName || organiser.fullName}"?`,
            action: async () => {
                try {
                    await adminApi.updateOrganiserStatus(organiser.id, 'ACTIVE');
                    toast.success('Account activated');
                    load();
                } catch {
                    toast.error('Failed to activate account');
                }
            },
        });
    };

    const handleLock = (organiser) => {
        handleMenuClose();
        setConfirmDialog({
            open: true,
            title: 'Lock Account',
            message: `Lock "${organiser.displayName || organiser.fullName}"?\n\nThey will not be able to login until you re-activate the account.`,
            action: async () => {
                try {
                    await adminApi.updateOrganiserStatus(organiser.id, 'LOCKED');
                    toast.success('Account locked');
                    load();
                } catch {
                    toast.error('Failed to lock account');
                }
            },
        });
    };

    const columns = [
        {
            field: 'displayName',
            headerName: 'Organisation',
            flex: 1.3,
            minWidth: 240,
            renderCell: (params) => {
                const name = params.row.displayName || params.row.fullName;
                return (
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, minWidth: 0 }}>
                        <Avatar
                            src={params.row.logoUrl || params.row.avatarUrl || params.row.coverUrl}
                            alt={name}
                            sx={{ width: 38, height: 38, fontSize: '0.9rem', fontWeight: 600 }}
                        >
                            {name?.charAt(0)?.toUpperCase()}
                        </Avatar>
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, minWidth: 0 }}>
                            <Typography variant="body2" fontWeight={600} noWrap>
                                {name}
                            </Typography>
                            {params.row.verified && (
                                <VerifiedIcon sx={{ color: 'primary.main', fontSize: 16, flexShrink: 0 }} />
                            )}
                        </Box>
                    </Box>
                );
            },
        },
        {
            field: 'email',
            headerName: 'Email',
            flex: 1,
            minWidth: 200,
            renderCell: (params) => (
                <Typography variant="body2" color="text.secondary" noWrap>
                    {params.value}
                </Typography>
            ),
        },
        {
            field: 'totalEvents',
            headerName: 'Events',
            width: 90,
            align: 'center',
            headerAlign: 'center',
        },
        {
            field: 'totalFollowers',
            headerName: 'Followers',
            width: 100,
            align: 'center',
            headerAlign: 'center',
        },
        {
            field: 'status',
            headerName: 'Account',
            width: 120,
            renderCell: (params) => (
                <StatusChip
                    label={params.value === 'ACTIVE' ? 'Active' : 'Locked'}
                    status={params.value === 'ACTIVE' ? 'success' : 'danger'}
                />
            ),
        },
        {
            field: 'verified',
            headerName: 'Badge',
            width: 130,
            renderCell: (params) => (
                <StatusChip
                    label={params.value ? 'Verified' : 'No badge'}
                    status={params.value ? 'info' : 'neutral'}
                    icon={params.value ? <VerifiedIcon sx={{ fontSize: 14 }} /> : undefined}
                />
            ),
        },
        {
            field: 'actions',
            headerName: '',
            width: 70,
            sortable: false,
            align: 'center',
            headerAlign: 'center',
            renderCell: (params) => (
                <Tooltip title="More actions">
                    <IconButton
                        size="small"
                        aria-label="organiser actions"
                        onClick={(e) => handleMenuOpen(e, params.row)}
                    >
                        <MoreVertIcon fontSize="small" />
                    </IconButton>
                </Tooltip>
            ),
        },
    ];

    return (
        <>
            <DataTableCard
                toolbar={
                    <PageToolbar
                        search={search}
                        onSearchChange={setSearch}
                        searchPlaceholder="Search organisers by name or email..."
                        actions={
                            <Button variant="outlined" startIcon={<RefreshIcon />} onClick={load}>
                                Refresh
                            </Button>
                        }
                    />
                }
                rows={organisers}
                columns={columns}
                loading={loading}
                emptyTitle="No organisers found"
                emptyDescription="No organisers match your current search."
                emptyIcon={<BusinessIcon sx={{ fontSize: 40 }} />}
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
                slotProps={{ paper: { sx: { minWidth: 230, borderRadius: 2 } } }}
            >
                {selectedOrganiser?.status === 'ACTIVE' ? (
                    <MenuItem onClick={() => handleLock(selectedOrganiser)}>
                        <ListItemIcon>
                            <LockIcon fontSize="small" color="error" />
                        </ListItemIcon>
                        <ListItemText>Lock Account</ListItemText>
                    </MenuItem>
                ) : (
                    <MenuItem onClick={() => handleActivate(selectedOrganiser)}>
                        <ListItemIcon>
                            <ActiveIcon fontSize="small" color="success" />
                        </ListItemIcon>
                        <ListItemText>Activate Account</ListItemText>
                    </MenuItem>
                )}
                <Divider sx={{ my: 0.5 }} />
                {selectedOrganiser?.verified ? (
                    <MenuItem onClick={() => handleUnverify(selectedOrganiser)}>
                        <ListItemIcon>
                            <VerifiedIcon fontSize="small" color="warning" />
                        </ListItemIcon>
                        <ListItemText
                            primary="Revoke Verified Badge"
                            secondary="Remove the blue tick"
                            secondaryTypographyProps={{ variant: 'caption' }}
                        />
                    </MenuItem>
                ) : (
                    <MenuItem onClick={() => handleVerify(selectedOrganiser)}>
                        <ListItemIcon>
                            <VerifiedIcon fontSize="small" color="primary" />
                        </ListItemIcon>
                        <ListItemText
                            primary="Grant Verified Badge (manual)"
                            secondary="Bypasses document review"
                            secondaryTypographyProps={{ variant: 'caption' }}
                        />
                    </MenuItem>
                )}
            </Menu>

            <ConfirmDialog
                open={confirmDialog.open}
                title={confirmDialog.title}
                message={confirmDialog.message}
                onConfirm={() => {
                    confirmDialog.action?.();
                    setConfirmDialog({ ...confirmDialog, open: false });
                }}
                onCancel={() => setConfirmDialog({ ...confirmDialog, open: false })}
            />
        </>
    );
};

export default Organisers;

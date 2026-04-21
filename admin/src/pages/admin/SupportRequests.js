import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Button,
    Chip,
    Dialog,
    DialogActions,
    DialogContent,
    DialogTitle,
    Divider,
    FormControl,
    InputLabel,
    MenuItem,
    Paper,
    Select,
    Stack,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TablePagination,
    TableRow,
    TextField,
    Typography,
    Tooltip,
    CircularProgress,
} from '@mui/material';
import {
    Refresh as RefreshIcon,
    SupportAgent as SupportIcon,
    Visibility as ViewIcon,
    OpenInNew as OpenInNewIcon,
} from '@mui/icons-material';
import { adminApi } from '../../api';
import { PageHeader } from '../../components/ui';
import { toast } from 'react-toastify';

const STATUS_OPTIONS = [
    { value: 'OPEN', label: 'Open', color: 'warning' },
    { value: 'IN_PROGRESS', label: 'In Progress', color: 'info' },
    { value: 'RESOLVED', label: 'Resolved', color: 'success' },
    { value: 'CLOSED', label: 'Closed', color: 'default' },
];

const CATEGORY_LABELS = {
    PAYMENT_ISSUE: 'Payment issue',
    REFUND: 'Refund',
    TICKET_MISSING: 'Ticket missing',
    ACCOUNT: 'Account',
    EVENT_INFO: 'Event info',
    OTHER: 'Other',
};

const statusChip = (status) => {
    const opt = STATUS_OPTIONS.find((o) => o.value === status);
    return (
        <Chip
            size="small"
            label={opt ? opt.label : status}
            color={opt ? opt.color : 'default'}
            variant={opt && opt.color === 'default' ? 'outlined' : 'filled'}
        />
    );
};

const formatDateTime = (iso) => {
    if (!iso) return '—';
    try {
        return new Date(iso).toLocaleString();
    } catch (_) {
        return iso;
    }
};

const TranscriptViewer = ({ transcript }) => {
    if (!Array.isArray(transcript) || transcript.length === 0) {
        return (
            <Typography variant="body2" color="text.secondary">
                No transcript attached.
            </Typography>
        );
    }
    return (
        <Stack spacing={1}>
            {transcript.map((turn, i) => (
                <Box
                    key={i}
                    sx={{
                        p: 1.25,
                        borderRadius: 1,
                        bgcolor: turn.role === 'user' ? 'primary.50' : 'grey.50',
                        borderLeft: 3,
                        borderColor: turn.role === 'user' ? 'primary.main' : 'grey.400',
                    }}
                >
                    <Typography variant="caption" color="text.secondary" fontWeight={600}>
                        {turn.role === 'user' ? 'User' : 'Assistant'}
                    </Typography>
                    <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap', mt: 0.5 }}>
                        {turn.content}
                    </Typography>
                </Box>
            ))}
        </Stack>
    );
};

const SupportRequests = () => {
    const [rows, setRows] = useState([]);
    const [total, setTotal] = useState(0);
    const [page, setPage] = useState(0);
    const [size, setSize] = useState(20);
    const [status, setStatus] = useState('OPEN');
    const [loading, setLoading] = useState(true);
    const [counts, setCounts] = useState({ open: 0, inProgress: 0, resolved: 0, closed: 0 });

    const [detailOpen, setDetailOpen] = useState(false);
    const [detail, setDetail] = useState(null);
    const [detailLoading, setDetailLoading] = useState(false);
    const [updating, setUpdating] = useState(false);
    const [editStatus, setEditStatus] = useState('OPEN');
    const [editNote, setEditNote] = useState('');

    const loadList = useCallback(async () => {
        setLoading(true);
        try {
            const [listRes, countRes] = await Promise.all([
                adminApi.getSupportRequests({ status, page, size }),
                adminApi.getSupportRequestCounts(),
            ]);
            const payload = listRes.data?.data;
            setRows(payload?.content || []);
            setTotal(payload?.totalElements || 0);
            setCounts(countRes.data?.data || counts);
        } catch (err) {
            toast.error('Failed to load support requests');
        } finally {
            setLoading(false);
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [status, page, size]);

    useEffect(() => {
        loadList();
    }, [loadList]);

    const openDetail = async (id) => {
        setDetailOpen(true);
        setDetailLoading(true);
        setDetail(null);
        try {
            const res = await adminApi.getSupportRequestById(id);
            const data = res.data?.data;
            setDetail(data);
            setEditStatus(data?.status || 'OPEN');
            setEditNote(data?.resolutionNote || '');
        } catch (err) {
            toast.error('Failed to load request');
        } finally {
            setDetailLoading(false);
        }
    };

    const saveStatus = async () => {
        if (!detail) return;
        setUpdating(true);
        try {
            const res = await adminApi.updateSupportRequest(detail.id, {
                status: editStatus,
                resolutionNote: editNote,
            });
            setDetail(res.data?.data);
            toast.success('Support request updated');
            loadList();
        } catch (err) {
            toast.error('Failed to update request');
        } finally {
            setUpdating(false);
        }
    };

    const StatCard = ({ label, value, color }) => (
        <Paper
            elevation={0}
            sx={{
                p: 2,
                flex: 1,
                border: 1,
                borderColor: 'divider',
                borderRadius: 2,
            }}
        >
            <Typography variant="caption" color="text.secondary">
                {label}
            </Typography>
            <Typography variant="h5" fontWeight={700} color={`${color}.main`}>
                {value}
            </Typography>
        </Paper>
    );

    return (
        <Box>
            <PageHeader
                icon={<SupportIcon />}
                title="Support Requests"
                subtitle="Triage issues escalated from the AI assistant"
            />

            <Stack direction="row" spacing={2} sx={{ mb: 3 }}>
                <StatCard label="Open" value={counts.open} color="warning" />
                <StatCard label="In progress" value={counts.inProgress} color="info" />
                <StatCard label="Resolved" value={counts.resolved} color="success" />
                <StatCard label="Closed" value={counts.closed} color="primary" />
            </Stack>

            <Stack direction="row" spacing={2} alignItems="center" sx={{ mb: 2 }}>
                <FormControl size="small" sx={{ minWidth: 160 }}>
                    <InputLabel>Status</InputLabel>
                    <Select
                        label="Status"
                        value={status}
                        onChange={(e) => {
                            setStatus(e.target.value);
                            setPage(0);
                        }}
                    >
                        <MenuItem value="ALL">All</MenuItem>
                        {STATUS_OPTIONS.map((s) => (
                            <MenuItem key={s.value} value={s.value}>
                                {s.label}
                            </MenuItem>
                        ))}
                    </Select>
                </FormControl>
                <Button startIcon={<RefreshIcon />} onClick={loadList} disabled={loading}>
                    Refresh
                </Button>
            </Stack>

            <TableContainer component={Paper} variant="outlined">
                <Table size="small">
                    <TableHead>
                        <TableRow>
                            <TableCell>Created</TableCell>
                            <TableCell>User</TableCell>
                            <TableCell>Category</TableCell>
                            <TableCell>Message</TableCell>
                            <TableCell>Related</TableCell>
                            <TableCell>Status</TableCell>
                            <TableCell align="right">Actions</TableCell>
                        </TableRow>
                    </TableHead>
                    <TableBody>
                        {loading ? (
                            <TableRow>
                                <TableCell colSpan={7} align="center" sx={{ py: 5 }}>
                                    <CircularProgress size={28} />
                                </TableCell>
                            </TableRow>
                        ) : rows.length === 0 ? (
                            <TableRow>
                                <TableCell colSpan={7} align="center" sx={{ py: 5, color: 'text.secondary' }}>
                                    No support requests for this filter.
                                </TableCell>
                            </TableRow>
                        ) : (
                            rows.map((r) => (
                                <TableRow key={r.id} hover>
                                    <TableCell>{formatDateTime(r.createdAt)}</TableCell>
                                    <TableCell>
                                        <Typography variant="body2" fontWeight={600}>
                                            {r.userName || '—'}
                                        </Typography>
                                        <Typography variant="caption" color="text.secondary">
                                            {r.userEmail}
                                        </Typography>
                                    </TableCell>
                                    <TableCell>{CATEGORY_LABELS[r.category] || r.category}</TableCell>
                                    <TableCell sx={{ maxWidth: 320 }}>
                                        <Tooltip title={r.message || ''} placement="top">
                                            <Typography
                                                variant="body2"
                                                sx={{
                                                    overflow: 'hidden',
                                                    textOverflow: 'ellipsis',
                                                    whiteSpace: 'nowrap',
                                                    maxWidth: 320,
                                                }}
                                            >
                                                {r.message || '—'}
                                            </Typography>
                                        </Tooltip>
                                    </TableCell>
                                    <TableCell>
                                        {r.relatedEventTitle && (
                                            <Typography variant="caption" display="block">
                                                Event: {r.relatedEventTitle}
                                            </Typography>
                                        )}
                                        {r.relatedTicketCode && (
                                            <Typography variant="caption" color="text.secondary" display="block">
                                                Ticket: {r.relatedTicketCode}
                                            </Typography>
                                        )}
                                        {!r.relatedEventTitle && !r.relatedTicketCode && '—'}
                                    </TableCell>
                                    <TableCell>{statusChip(r.status)}</TableCell>
                                    <TableCell align="right">
                                        <Tooltip title="View transcript">
                                            <Button
                                                size="small"
                                                startIcon={<ViewIcon />}
                                                onClick={() => openDetail(r.id)}
                                            >
                                                Open
                                            </Button>
                                        </Tooltip>
                                    </TableCell>
                                </TableRow>
                            ))
                        )}
                    </TableBody>
                </Table>
                <TablePagination
                    component="div"
                    count={total}
                    page={page}
                    onPageChange={(_, p) => setPage(p)}
                    rowsPerPage={size}
                    onRowsPerPageChange={(e) => {
                        setSize(parseInt(e.target.value, 10));
                        setPage(0);
                    }}
                    rowsPerPageOptions={[10, 20, 50]}
                />
            </TableContainer>

            <Dialog
                open={detailOpen}
                onClose={() => setDetailOpen(false)}
                maxWidth="md"
                fullWidth
            >
                <DialogTitle>
                    Support request
                    {detail && (
                        <Typography variant="caption" display="block" color="text.secondary">
                            {detail.id}
                        </Typography>
                    )}
                </DialogTitle>
                <DialogContent dividers>
                    {detailLoading || !detail ? (
                        <Box sx={{ textAlign: 'center', py: 5 }}>
                            <CircularProgress />
                        </Box>
                    ) : (
                        <Stack spacing={2}>
                            <Stack direction="row" spacing={2}>
                                <Box flex={1}>
                                    <Typography variant="caption" color="text.secondary">
                                        User
                                    </Typography>
                                    <Typography variant="body2" fontWeight={600}>
                                        {detail.userName || '—'}
                                    </Typography>
                                    <Typography variant="caption" color="text.secondary">
                                        {detail.userEmail}
                                    </Typography>
                                </Box>
                                <Box flex={1}>
                                    <Typography variant="caption" color="text.secondary">
                                        Category
                                    </Typography>
                                    <Typography variant="body2" fontWeight={600}>
                                        {CATEGORY_LABELS[detail.category] || detail.category}
                                    </Typography>
                                </Box>
                                <Box flex={1}>
                                    <Typography variant="caption" color="text.secondary">
                                        Created
                                    </Typography>
                                    <Typography variant="body2">{formatDateTime(detail.createdAt)}</Typography>
                                </Box>
                            </Stack>

                            {(detail.relatedEventTitle || detail.relatedTicketCode) && (
                                <Box>
                                    <Typography variant="caption" color="text.secondary">
                                        Related
                                    </Typography>
                                    {detail.relatedEventTitle && (
                                        <Typography variant="body2">
                                            Event: {detail.relatedEventTitle}
                                        </Typography>
                                    )}
                                    {detail.relatedTicketCode && (
                                        <Typography variant="body2">
                                            Ticket: {detail.relatedTicketCode}
                                        </Typography>
                                    )}
                                </Box>
                            )}

                            <Divider />

                            <Box>
                                <Typography variant="caption" color="text.secondary">
                                    User message
                                </Typography>
                                <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap', mt: 0.5 }}>
                                    {detail.message || '—'}
                                </Typography>
                            </Box>

                            <Box>
                                <Typography variant="caption" color="text.secondary" gutterBottom>
                                    Chat transcript
                                </Typography>
                                <TranscriptViewer transcript={detail.transcript} />
                            </Box>

                            <Divider />

                            <Stack direction="row" spacing={2} alignItems="center">
                                <FormControl size="small" sx={{ minWidth: 160 }}>
                                    <InputLabel>Status</InputLabel>
                                    <Select
                                        label="Status"
                                        value={editStatus}
                                        onChange={(e) => setEditStatus(e.target.value)}
                                    >
                                        {STATUS_OPTIONS.map((s) => (
                                            <MenuItem key={s.value} value={s.value}>
                                                {s.label}
                                            </MenuItem>
                                        ))}
                                    </Select>
                                </FormControl>
                                <TextField
                                    size="small"
                                    fullWidth
                                    label="Resolution note"
                                    placeholder="What did you do?"
                                    value={editNote}
                                    onChange={(e) => setEditNote(e.target.value)}
                                />
                            </Stack>

                            {detail.resolvedByName && (
                                <Typography variant="caption" color="text.secondary">
                                    Resolved by {detail.resolvedByName} · {formatDateTime(detail.resolvedAt)}
                                </Typography>
                            )}
                        </Stack>
                    )}
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setDetailOpen(false)}>Close</Button>
                    <Button
                        variant="contained"
                        onClick={saveStatus}
                        disabled={updating || detailLoading || !detail}
                        startIcon={updating ? <CircularProgress size={16} /> : <OpenInNewIcon />}
                    >
                        Save
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default SupportRequests;

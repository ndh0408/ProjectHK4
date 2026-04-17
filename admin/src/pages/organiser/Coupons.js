import React, { useState, useEffect } from 'react';
import {
    Box,
    Typography,
    Button,
    TextField,
    Grid,
    Select,
    MenuItem,
    FormControl,
    InputLabel,
    IconButton,
    Tooltip,
    Alert,
    Collapse,
    Stack,
    Autocomplete,
} from '@mui/material';
import {
    Add as AddIcon,
    Refresh as RefreshIcon,
    Block as DisableIcon,
    LocalOffer as CouponIcon,
    AutoAwesome as AIIcon,
} from '@mui/icons-material';
import { organiserApi } from '../../api';
import { toast } from 'react-toastify';
import { ConfirmDialog } from '../../components/common';
import {
    PageHeader,
    DataTableCard,
    StatusChip,
    FormDialog,
    FormSection,
    LoadingButton,
} from '../../components/ui';

const OrganiserCoupons = () => {
    const [coupons, setCoupons] = useState([]);
    const [loading, setLoading] = useState(false);
    const [createDialog, setCreateDialog] = useState(false);
    const [createSubmitting, setCreateSubmitting] = useState(false);
    const [paginationModel, setPaginationModel] = useState({ page: 0, pageSize: 10 });
    const [totalRows, setTotalRows] = useState(0);
    const [confirmDialog, setConfirmDialog] = useState({ open: false, title: '', message: '', action: null });
    const [form, setForm] = useState({
        code: '', description: '', discountType: 'PERCENTAGE', discountValue: '',
        maxDiscountAmount: '', minOrderAmount: '', maxUsageCount: 0, maxUsagePerUser: '',
        validFrom: '', validUntil: '',
    });

    // Organiser's events for the "Scope" picker in the Create dialog. Leaving
    // the selection blank means the coupon applies to every event this
    // organiser runs (the Option B "shop coupon" behaviour).
    const [events, setEvents] = useState([]);
    const [selectedEvent, setSelectedEvent] = useState(null);
    const [eventsLoading, setEventsLoading] = useState(false);
    // Separate selection for the AI Generate dialog so the picker doesn't
    // clash with the Create dialog state. On "Apply to form" this selection
    // is forwarded to `selectedEvent` so the scope carries over.
    const [aiSelectedEvent, setAiSelectedEvent] = useState(null);

    const [aiDialog, setAiDialog] = useState(false);
    const [aiLoading, setAiLoading] = useState(false);
    const [aiResult, setAiResult] = useState(null);
    const [aiForm, setAiForm] = useState({
        description: '', eventName: '', discountType: 'PERCENTAGE', discountValue: '',
        maxDiscountAmount: '', minOrderAmount: '', maxUsageCount: '', maxUsagePerUser: '',
        validFrom: '', validUntil: '', language: 'vi',
    });

    const loadCoupons = async () => {
        setLoading(true);
        try {
            const res = await organiserApi.getCoupons({ page: paginationModel.page, size: paginationModel.pageSize });
            setCoupons(res.data.data.content || []);
            setTotalRows(res.data.data.totalElements || 0);
        } catch { toast.error('Failed to load coupons'); }
        finally { setLoading(false); }
    };

    // eslint-disable-next-line react-hooks/exhaustive-deps
    useEffect(() => { loadCoupons(); }, [paginationModel]);

    const loadEvents = async () => {
        setEventsLoading(true);
        try {
            const res = await organiserApi.getMyEvents({ page: 0, size: 100 });
            setEvents(res.data?.data?.content || []);
        } catch {
            // Non-blocking: user can still create an organiser-wide coupon.
            setEvents([]);
        } finally {
            setEventsLoading(false);
        }
    };

    const openCreateDialog = () => {
        setSelectedEvent(null);
        if (events.length === 0) loadEvents();
        setCreateDialog(true);
    };

    const closeCreateDialog = () => {
        setCreateDialog(false);
        setSelectedEvent(null);
    };

    const openAiDialog = () => {
        setAiResult(null);
        setAiSelectedEvent(null);
        if (events.length === 0) loadEvents();
        setAiDialog(true);
    };

    const closeAiDialog = () => {
        setAiDialog(false);
        setAiSelectedEvent(null);
    };

    const handleCreate = async () => {
        if (createSubmitting) return;
        if (!form.code.trim()) { toast.error('Coupon code is required'); return; }
        const dv = parseFloat(form.discountValue);
        if (!dv || dv <= 0) { toast.error('Discount value must be greater than 0'); return; }
        if (form.discountType === 'PERCENTAGE' && dv > 100) { toast.error('Percentage cannot exceed 100%'); return; }
        if (form.validFrom && form.validUntil && new Date(form.validFrom) >= new Date(form.validUntil)) {
            toast.error('Valid From must be before Valid Until'); return;
        }
        setCreateSubmitting(true);
        try {
            const data = { ...form, discountValue: dv };
            if (form.maxDiscountAmount) data.maxDiscountAmount = parseFloat(form.maxDiscountAmount);
            if (form.minOrderAmount) data.minOrderAmount = parseFloat(form.minOrderAmount);
            if (form.maxUsagePerUser) data.maxUsagePerUser = parseInt(form.maxUsagePerUser);
            if (form.validFrom) data.validFrom = new Date(form.validFrom).toISOString();
            if (form.validUntil) data.validUntil = new Date(form.validUntil).toISOString();
            if (selectedEvent?.id) data.eventId = selectedEvent.id;
            await organiserApi.createCoupon(data);
            toast.success('Coupon created!');
            closeCreateDialog();
            setForm({ code: '', description: '', discountType: 'PERCENTAGE', discountValue: '', maxDiscountAmount: '', minOrderAmount: '', maxUsageCount: 0, maxUsagePerUser: '', validFrom: '', validUntil: '' });
            loadCoupons();
        } catch (e) { toast.error(e.response?.data?.message || 'Failed to create coupon'); }
        finally { setCreateSubmitting(false); }
    };

    const requestDisable = (id, code) => {
        setConfirmDialog({
            open: true,
            title: 'Disable coupon?',
            message: `Coupon "${code}" will no longer be usable. This cannot be undone.`,
            action: () => doDisable(id),
        });
    };

    const doDisable = async (id) => {
        try { await organiserApi.disableCoupon(id); toast.success('Coupon disabled'); loadCoupons(); }
        catch { toast.error('Failed'); }
    };

    const handleAIGenerate = async () => {
        setAiLoading(true);
        try {
            // Auto-fill eventName from the picked event if user didn't type
            // one manually. Gives the AI richer context for copy generation.
            const data = {
                ...aiForm,
                eventName: aiForm.eventName?.trim() || aiSelectedEvent?.title || '',
            };
            if (aiForm.discountValue) data.discountValue = parseFloat(aiForm.discountValue);
            if (aiForm.maxDiscountAmount) data.maxDiscountAmount = parseFloat(aiForm.maxDiscountAmount);
            if (aiForm.minOrderAmount) data.minOrderAmount = parseFloat(aiForm.minOrderAmount);
            if (aiForm.maxUsageCount) data.maxUsageCount = parseInt(aiForm.maxUsageCount);
            if (aiForm.maxUsagePerUser) data.maxUsagePerUser = parseInt(aiForm.maxUsagePerUser);
            if (aiForm.validFrom) data.validFrom = new Date(aiForm.validFrom).toISOString();
            if (aiForm.validUntil) data.validUntil = new Date(aiForm.validUntil).toISOString();

            const res = await organiserApi.generateCouponAI(data);
            setAiResult(res.data.data);
            toast.success('AI generated coupon suggestions!');
        } catch (e) {
            const errorMsg = e.response?.data?.message
                || e.response?.data?.error
                || e.message
                || 'Failed to generate coupon with AI';
            toast.error(errorMsg);
        } finally {
            setAiLoading(false);
        }
    };

    const applyAIGenerated = () => {
        if (!aiResult) return;
        const formatDateTime = (dateStr) => {
            if (!dateStr) return '';
            try {
                const date = new Date(dateStr);
                if (isNaN(date.getTime())) return '';
                const year = date.getFullYear();
                const month = String(date.getMonth() + 1).padStart(2, '0');
                const day = String(date.getDate()).padStart(2, '0');
                const hours = String(date.getHours()).padStart(2, '0');
                const minutes = String(date.getMinutes()).padStart(2, '0');
                return `${year}-${month}-${day}T${hours}:${minutes}`;
            } catch { return ''; }
        };

        let validFrom = aiResult.suggestedValidFrom || '';
        let validUntil = aiResult.suggestedValidUntil || '';
        if (!validFrom && !validUntil && aiResult.suggestedValidDays) {
            const now = new Date();
            validFrom = formatDateTime(now.toISOString());
            const future = new Date(now);
            future.setDate(future.getDate() + parseInt(aiResult.suggestedValidDays));
            validUntil = formatDateTime(future.toISOString());
        } else {
            validFrom = formatDateTime(validFrom);
            validUntil = formatDateTime(validUntil);
        }

        setForm({
            ...form,
            code: (aiResult.code || form.code || '').toUpperCase(),
            description: aiResult.description || form.description,
            discountType: aiResult.suggestedDiscountType || form.discountType,
            discountValue: aiResult.suggestedDiscountValue?.toString() || form.discountValue,
            maxDiscountAmount: aiResult.suggestedMaxDiscountAmount?.toString() || form.maxDiscountAmount,
            minOrderAmount: aiResult.suggestedMinOrderAmount?.toString() || form.minOrderAmount,
            maxUsageCount: aiResult.suggestedMaxUsageCount || form.maxUsageCount,
            maxUsagePerUser: aiResult.suggestedMaxUsagePerUser?.toString() || form.maxUsagePerUser,
            validFrom: validFrom || form.validFrom,
            validUntil: validUntil || form.validUntil,
        });
        // Carry the AI-dialog event selection into the Create dialog so the
        // same scope is applied without the user having to pick twice.
        if (aiSelectedEvent) {
            setSelectedEvent(aiSelectedEvent);
        }
        setAiDialog(false);
        setAiResult(null);
        setAiSelectedEvent(null);
        if (events.length === 0) loadEvents();
        setCreateDialog(true);
        toast.success('AI suggestions applied!');
    };

    const statusVariant = (status) => {
        if (status === 'ACTIVE') return 'success';
        if (status === 'DISABLED') return 'neutral';
        if (status === 'EXPIRED') return 'danger';
        if (status === 'USED_UP') return 'warning';
        return 'neutral';
    };

    const columns = [
        {
            field: 'code',
            headerName: 'Code',
            width: 160,
            renderCell: (p) => (
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.75, fontFamily: 'monospace' }}>
                    <CouponIcon sx={{ fontSize: 14, color: 'primary.500' }} />
                    <Typography variant="body2" sx={{ fontWeight: 600 }}>
                        {p.value}
                    </Typography>
                </Box>
            ),
        },
        {
            field: 'discountType',
            headerName: 'Discount',
            width: 120,
            renderCell: (p) => (
                <Typography variant="body2" sx={{ fontWeight: 600 }}>
                    {p.value === 'PERCENTAGE' ? `${p.row.discountValue}%` : `$${p.row.discountValue}`}
                </Typography>
            ),
        },
        {
            field: 'status',
            headerName: 'Status',
            width: 120,
            renderCell: (p) => (
                <StatusChip label={p.value || 'N/A'} status={statusVariant(p.value)} />
            ),
        },
        {
            field: 'eventTitle',
            headerName: 'Scope',
            flex: 1,
            minWidth: 180,
            renderCell: (p) => p.row.eventTitle ? (
                <Tooltip title={p.row.eventTitle}>
                    <Typography variant="body2" noWrap sx={{ fontWeight: 500 }}>
                        {p.row.eventTitle}
                    </Typography>
                </Tooltip>
            ) : (
                <Typography variant="body2" color="text.secondary" sx={{ fontStyle: 'italic' }}>
                    All my events
                </Typography>
            ),
        },
        {
            field: 'usedCount',
            headerName: 'Usage',
            width: 110,
            renderCell: (p) => (
                <Typography variant="body2">
                    {p.value}{p.row.maxUsageCount > 0 ? ` / ${p.row.maxUsageCount}` : ''}
                </Typography>
            ),
        },
        {
            field: 'validUntil',
            headerName: 'Expires',
            width: 160,
            valueFormatter: (p) => p.value ? new Date(p.value).toLocaleDateString() : 'No expiry',
        },
        {
            field: 'actions',
            headerName: 'Actions',
            width: 100,
            align: 'right',
            headerAlign: 'right',
            sortable: false,
            renderCell: (p) => p.row.status === 'ACTIVE' ? (
                <Tooltip title="Disable coupon">
                    <IconButton size="small" color="error" onClick={() => requestDisable(p.row.id, p.row.code)}>
                        <DisableIcon fontSize="small" />
                    </IconButton>
                </Tooltip>
            ) : null,
        },
    ];

    return (
        <Box>
            <PageHeader
                title="Coupons"
                subtitle="Create and manage discount codes for your events."
                icon={<CouponIcon />}
                actions={[
                    <Button
                        key="refresh"
                        variant="outlined"
                        startIcon={<RefreshIcon fontSize="small" />}
                        onClick={loadCoupons}
                    >
                        Refresh
                    </Button>,
                    <Button
                        key="ai"
                        variant="outlined"
                        color="secondary"
                        startIcon={<AIIcon fontSize="small" />}
                        onClick={openAiDialog}
                    >
                        AI generate
                    </Button>,
                    <Button
                        key="create"
                        variant="contained"
                        startIcon={<AddIcon fontSize="small" />}
                        onClick={openCreateDialog}
                    >
                        Create coupon
                    </Button>,
                ]}
            />

            <DataTableCard
                rows={coupons}
                columns={columns}
                loading={loading}
                emptyTitle="No coupons yet"
                emptyDescription="Create your first coupon or let AI suggest one for you."
                emptyIcon={<CouponIcon sx={{ fontSize: 28 }} />}
                emptyAction={(
                    <Stack direction="row" spacing={1}>
                        <Button
                            variant="outlined"
                            startIcon={<AIIcon fontSize="small" />}
                            onClick={openAiDialog}
                        >
                            AI generate
                        </Button>
                        <Button
                            variant="contained"
                            startIcon={<AddIcon fontSize="small" />}
                            onClick={openCreateDialog}
                        >
                            Create coupon
                        </Button>
                    </Stack>
                )}
                dataGridProps={{
                    paginationModel,
                    onPaginationModelChange: setPaginationModel,
                    pageSizeOptions: [10, 25],
                    rowCount: totalRows,
                    paginationMode: 'server',
                }}
            />

            <FormDialog
                open={createDialog}
                onClose={closeCreateDialog}
                title="Create coupon"
                subtitle="Pick a scope, then configure discount and validity."
                icon={<CouponIcon />}
                maxWidth="md"
                actions={(
                    <>
                        <Button onClick={closeCreateDialog} disabled={createSubmitting}>
                            Cancel
                        </Button>
                        <LoadingButton variant="contained" onClick={handleCreate} loading={createSubmitting}>
                            Create coupon
                        </LoadingButton>
                    </>
                )}
            >
                <FormSection
                    title="Scope"
                    description={selectedEvent
                        ? `This coupon will only work for "${selectedEvent.title}".`
                        : 'Leave blank to make this coupon valid across all your events.'}
                >
                    <Autocomplete
                        options={events}
                        loading={eventsLoading}
                        value={selectedEvent}
                        onChange={(_, v) => setSelectedEvent(v)}
                        getOptionLabel={(o) => o?.title || ''}
                        isOptionEqualToValue={(o, v) => o.id === v.id}
                        noOptionsText={eventsLoading ? 'Loading events…' : 'No events found'}
                        renderInput={(params) => (
                            <TextField
                                {...params}
                                label="Apply to event (optional)"
                                placeholder="All my events"
                                helperText="Leave empty = shop-wide coupon for every event you run."
                            />
                        )}
                    />
                </FormSection>

                <FormSection title="Code & discount" topDivider>
                    <Grid container spacing={2}>
                        <Grid item xs={12} sm={6}>
                            <TextField
                                fullWidth
                                label="Coupon code"
                                value={form.code}
                                onChange={(e) => setForm({ ...form, code: e.target.value.toUpperCase() })}
                                required
                                inputProps={{ style: { fontFamily: 'monospace', letterSpacing: '0.05em' } }}
                            />
                        </Grid>
                        <Grid item xs={12} sm={6}>
                            <FormControl fullWidth size="small">
                                <InputLabel>Discount type</InputLabel>
                                <Select
                                    value={form.discountType}
                                    label="Discount type"
                                    onChange={(e) => setForm({ ...form, discountType: e.target.value })}
                                >
                                    <MenuItem value="PERCENTAGE">Percentage (%)</MenuItem>
                                    <MenuItem value="FIXED_AMOUNT">Fixed amount</MenuItem>
                                </Select>
                            </FormControl>
                        </Grid>
                        <Grid item xs={12} sm={6}>
                            <TextField
                                fullWidth
                                type="number"
                                label={form.discountType === 'PERCENTAGE' ? 'Discount %' : 'Discount amount'}
                                value={form.discountValue}
                                onChange={(e) => setForm({ ...form, discountValue: e.target.value })}
                                required
                            />
                        </Grid>
                        <Grid item xs={12} sm={6}>
                            <TextField
                                fullWidth
                                type="number"
                                label="Max discount amount"
                                value={form.maxDiscountAmount}
                                onChange={(e) => setForm({ ...form, maxDiscountAmount: e.target.value })}
                                helperText="Cap for percentage discounts"
                            />
                        </Grid>
                    </Grid>
                </FormSection>

                <FormSection title="Limits" topDivider>
                    <Grid container spacing={2}>
                        <Grid item xs={12} sm={6}>
                            <TextField
                                fullWidth
                                type="number"
                                label="Minimum order amount"
                                value={form.minOrderAmount}
                                onChange={(e) => setForm({ ...form, minOrderAmount: e.target.value })}
                            />
                        </Grid>
                        <Grid item xs={12} sm={6}>
                            <TextField
                                fullWidth
                                type="number"
                                label="Max usage (0 = unlimited)"
                                value={form.maxUsageCount}
                                onChange={(e) => setForm({ ...form, maxUsageCount: parseInt(e.target.value) || 0 })}
                            />
                        </Grid>
                    </Grid>
                </FormSection>

                <FormSection title="Validity & description" topDivider>
                    <Grid container spacing={2}>
                        <Grid item xs={12} sm={6}>
                            <TextField
                                fullWidth
                                type="datetime-local"
                                label="Valid from"
                                value={form.validFrom}
                                onChange={(e) => setForm({ ...form, validFrom: e.target.value })}
                                InputLabelProps={{ shrink: true }}
                            />
                        </Grid>
                        <Grid item xs={12} sm={6}>
                            <TextField
                                fullWidth
                                type="datetime-local"
                                label="Valid until"
                                value={form.validUntil}
                                onChange={(e) => setForm({ ...form, validUntil: e.target.value })}
                                InputLabelProps={{ shrink: true }}
                            />
                        </Grid>
                        <Grid item xs={12}>
                            <TextField
                                fullWidth
                                label="Description"
                                value={form.description}
                                onChange={(e) => setForm({ ...form, description: e.target.value })}
                                multiline
                                minRows={2}
                            />
                        </Grid>
                    </Grid>
                </FormSection>
            </FormDialog>

            <FormDialog
                open={aiDialog}
                onClose={closeAiDialog}
                title="AI Generate Coupon"
                subtitle="Describe your promotion and let Luma suggest the best code."
                icon={<AIIcon />}
                maxWidth="md"
                actions={(
                    <>
                        <Button onClick={closeAiDialog} disabled={aiLoading}>
                            Cancel
                        </Button>
                        <LoadingButton
                            variant="contained"
                            color={aiResult ? 'primary' : 'secondary'}
                            onClick={aiResult ? applyAIGenerated : handleAIGenerate}
                            loading={aiLoading}
                            startIcon={aiResult ? <AddIcon fontSize="small" /> : <AIIcon fontSize="small" />}
                        >
                            {aiLoading ? 'Generating...' : (aiResult ? 'Apply to form' : 'Generate with AI')}
                        </LoadingButton>
                    </>
                )}
            >
                <FormSection
                    title="Scope"
                    description={aiSelectedEvent
                        ? `Generated coupon will be scoped to "${aiSelectedEvent.title}".`
                        : 'Leave blank to create a coupon valid across all your events.'}
                >
                    <Autocomplete
                        options={events}
                        loading={eventsLoading}
                        value={aiSelectedEvent}
                        onChange={(_, v) => {
                            setAiSelectedEvent(v);
                            // Auto-fill the AI event-name hint the first time
                            // the user picks an event (they can still overwrite).
                            if (v && !aiForm.eventName?.trim()) {
                                setAiForm({ ...aiForm, eventName: v.title });
                            }
                        }}
                        getOptionLabel={(o) => o?.title || ''}
                        isOptionEqualToValue={(o, v) => o.id === v.id}
                        noOptionsText={eventsLoading ? 'Loading events…' : 'No events found'}
                        renderInput={(params) => (
                            <TextField
                                {...params}
                                label="Apply to event (optional)"
                                placeholder="All my events"
                                helperText="Picked event flows through to the Create form after you apply suggestions."
                            />
                        )}
                    />
                </FormSection>

                <FormSection
                    title="Campaign details"
                    description="The more context you give, the better the AI output."
                    topDivider
                >
                    <Grid container spacing={2}>
                        <Grid item xs={12}>
                            <TextField
                                fullWidth
                                multiline
                                minRows={2}
                                label="What is this coupon for?"
                                placeholder="e.g. Early-bird discount for our upcoming tech conference"
                                value={aiForm.description}
                                onChange={(e) => setAiForm({ ...aiForm, description: e.target.value })}
                            />
                        </Grid>
                        <Grid item xs={12} sm={6}>
                            <TextField
                                fullWidth
                                label="Event name hint (optional)"
                                placeholder={aiSelectedEvent?.title || 'Auto-filled when you pick an event above'}
                                value={aiForm.eventName}
                                onChange={(e) => setAiForm({ ...aiForm, eventName: e.target.value })}
                                helperText="Free-text hint sent to the AI for richer copy."
                            />
                        </Grid>
                        <Grid item xs={12} sm={6}>
                            <FormControl fullWidth size="small">
                                <InputLabel>Language</InputLabel>
                                <Select
                                    value={aiForm.language}
                                    label="Language"
                                    onChange={(e) => setAiForm({ ...aiForm, language: e.target.value })}
                                >
                                    <MenuItem value="vi">Vietnamese</MenuItem>
                                    <MenuItem value="en">English</MenuItem>
                                </Select>
                            </FormControl>
                        </Grid>
                    </Grid>
                </FormSection>

                <FormSection title="Preferences" topDivider>
                    <Grid container spacing={2}>
                        <Grid item xs={12} sm={6}>
                            <FormControl fullWidth size="small">
                                <InputLabel>Preferred type</InputLabel>
                                <Select
                                    value={aiForm.discountType}
                                    label="Preferred type"
                                    onChange={(e) => setAiForm({ ...aiForm, discountType: e.target.value })}
                                >
                                    <MenuItem value="PERCENTAGE">Percentage (%)</MenuItem>
                                    <MenuItem value="FIXED_AMOUNT">Fixed amount ($)</MenuItem>
                                </Select>
                            </FormControl>
                        </Grid>
                        <Grid item xs={12} sm={6}>
                            <TextField
                                fullWidth
                                type="number"
                                label="Preferred discount value"
                                value={aiForm.discountValue}
                                onChange={(e) => setAiForm({ ...aiForm, discountValue: e.target.value })}
                            />
                        </Grid>
                        <Grid item xs={12} sm={6}>
                            <TextField
                                fullWidth
                                type="number"
                                label="Min order amount (optional)"
                                value={aiForm.minOrderAmount}
                                onChange={(e) => setAiForm({ ...aiForm, minOrderAmount: e.target.value })}
                            />
                        </Grid>
                        <Grid item xs={12} sm={6}>
                            <TextField
                                fullWidth
                                type="number"
                                label="Max per user (optional)"
                                value={aiForm.maxUsagePerUser}
                                onChange={(e) => setAiForm({ ...aiForm, maxUsagePerUser: e.target.value })}
                            />
                        </Grid>
                        <Grid item xs={12} sm={6}>
                            <TextField
                                fullWidth
                                type="datetime-local"
                                label="Valid from"
                                value={aiForm.validFrom}
                                onChange={(e) => setAiForm({ ...aiForm, validFrom: e.target.value })}
                                InputLabelProps={{ shrink: true }}
                            />
                        </Grid>
                        <Grid item xs={12} sm={6}>
                            <TextField
                                fullWidth
                                type="datetime-local"
                                label="Valid until"
                                value={aiForm.validUntil}
                                onChange={(e) => setAiForm({ ...aiForm, validUntil: e.target.value })}
                                InputLabelProps={{ shrink: true }}
                            />
                        </Grid>
                    </Grid>
                </FormSection>

                <Collapse in={!!aiResult}>
                    <Alert severity="success" sx={{ mt: 2 }}>
                        <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1 }}>
                            AI-generated suggestions
                        </Typography>
                        {aiResult && (
                            <Stack spacing={0.5}>
                                <Typography variant="body2">
                                    <b>Code:</b>{' '}
                                    <Box component="span" sx={{ fontFamily: 'monospace', letterSpacing: '0.05em' }}>
                                        {(aiResult.code || '').toUpperCase()}
                                    </Box>
                                </Typography>
                                <Typography variant="body2"><b>Description:</b> {aiResult.description}</Typography>
                                {aiResult.suggestedDiscountType && (
                                    <Typography variant="body2">
                                        <b>Discount:</b>{' '}
                                        {aiResult.suggestedDiscountType === 'PERCENTAGE'
                                            ? `${aiResult.suggestedDiscountValue}%`
                                            : `$${aiResult.suggestedDiscountValue}`}
                                    </Typography>
                                )}
                                {aiResult.suggestedMaxUsageCount && (
                                    <Typography variant="body2">
                                        <b>Max usage:</b> {aiResult.suggestedMaxUsageCount}
                                    </Typography>
                                )}
                                {(aiResult.suggestedValidFrom || aiResult.suggestedValidUntil) && (
                                    <Typography variant="body2">
                                        <b>Valid period:</b>{' '}
                                        {aiResult.suggestedValidFrom ? new Date(aiResult.suggestedValidFrom).toLocaleString() : 'Now'}
                                        {' – '}
                                        {aiResult.suggestedValidUntil ? new Date(aiResult.suggestedValidUntil).toLocaleString() : 'Unlimited'}
                                    </Typography>
                                )}
                                {!aiResult.suggestedValidFrom && !aiResult.suggestedValidUntil && aiResult.suggestedValidDays && (
                                    <Typography variant="body2">
                                        <b>Valid for:</b> {aiResult.suggestedValidDays} days
                                    </Typography>
                                )}
                                {aiResult.reasoning && (
                                    <Typography variant="body2" sx={{ mt: 1, fontStyle: 'italic', color: 'text.secondary' }}>
                                        {aiResult.reasoning}
                                    </Typography>
                                )}
                            </Stack>
                        )}
                    </Alert>
                </Collapse>
            </FormDialog>

            <ConfirmDialog
                open={confirmDialog.open}
                title={confirmDialog.title}
                message={confirmDialog.message}
                confirmText="Disable"
                confirmColor="error"
                onConfirm={() => {
                    if (confirmDialog.action) confirmDialog.action();
                    setConfirmDialog({ ...confirmDialog, open: false });
                }}
                onCancel={() => setConfirmDialog({ ...confirmDialog, open: false })}
            />
        </Box>
    );
};

export default OrganiserCoupons;

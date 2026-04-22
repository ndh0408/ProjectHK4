import React, { useState, useEffect } from 'react';
import {
    Box,
    Grid,
    Stack,
    Typography,
    TextField,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    Button,
    Switch,
    FormControlLabel,
    IconButton,
    Tooltip,
    InputAdornment,
} from '@mui/material';
import {
    Edit as EditIcon,
    Refresh as RefreshIcon,
    WorkspacePremium as PremiumIcon,
    Add as AddIcon,
    Delete as DeleteIcon,
} from '@mui/icons-material';
import { toast } from 'react-toastify';
import adminApi from '../../api/adminApi';
import {
    PageHeader,
    SectionCard,
    LoadingButton,
    StatusChip,
} from '../../components/ui';
import { tokens } from '../../theme';

const PLAN_ACCENT = {
    FREE: tokens.palette.neutral[500],
    STANDARD: tokens.palette.info[600],
    PREMIUM: tokens.palette.primary[600],
    VIP: tokens.palette.warning[600],
};

const CANONICAL_KEYS = new Set(['FREE', 'STANDARD', 'PREMIUM', 'VIP']);

const AdminSubscriptionPlans = () => {
    const [loading, setLoading] = useState(true);
    const [plans, setPlans] = useState([]);
    const [editDialog, setEditDialog] = useState({ open: false, plan: null, mode: 'edit' });
    const [form, setForm] = useState(null);
    const [newKey, setNewKey] = useState('');
    const [saving, setSaving] = useState(false);
    const [deleteDialog, setDeleteDialog] = useState({ open: false, plan: null });

    const loadData = async () => {
        try {
            setLoading(true);
            const res = await adminApi.getSubscriptionPlans();
            setPlans(res.data.data || []);
        } catch (err) {
            toast.error('Failed to load subscription plans');
            console.error(err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => { loadData(); }, []);

    const openEdit = (plan) => {
        setEditDialog({ open: true, plan, mode: 'edit' });
        setForm({
            displayName: plan.displayName,
            monthlyPriceUsd: plan.monthlyPriceUsd,
            maxEventsPerMonth: plan.maxEventsPerMonth,
            boostDiscountPercent: plan.boostDiscountPercent,
            active: plan.active,
            sortOrder: plan.sortOrder,
        });
    };

    const openCreate = () => {
        setEditDialog({ open: true, plan: null, mode: 'create' });
        setNewKey('');
        setForm({
            displayName: '',
            monthlyPriceUsd: 29.99,
            maxEventsPerMonth: 20,
            boostDiscountPercent: 15,
            active: true,
            sortOrder: 100,
        });
    };

    const closeEdit = () => {
        setEditDialog({ open: false, plan: null, mode: 'edit' });
        setForm(null);
        setNewKey('');
    };

    const handleSave = async () => {
        if (!form) return;
        try {
            setSaving(true);
            const payload = {
                ...form,
                monthlyPriceUsd: Number(form.monthlyPriceUsd),
                maxEventsPerMonth: Number(form.maxEventsPerMonth),
                boostDiscountPercent: Number(form.boostDiscountPercent),
                sortOrder: Number(form.sortOrder),
            };
            if (editDialog.mode === 'create') {
                const key = (newKey || '').trim().toUpperCase();
                if (!/^[A-Z0-9_]{2,40}$/.test(key)) {
                    toast.error('Key must be uppercase letters / digits / underscore (2-40)');
                    setSaving(false);
                    return;
                }
                await adminApi.createSubscriptionPlan(key, payload);
                toast.success(`Plan ${key} created`);
            } else {
                await adminApi.updateSubscriptionPlan(editDialog.plan.planKey, payload);
                toast.success(`${editDialog.plan.planKey} plan updated`);
            }
            closeEdit();
            await loadData();
        } catch (err) {
            toast.error(err.response?.data?.message || 'Failed to save plan');
        } finally {
            setSaving(false);
        }
    };

    const handleDelete = async () => {
        if (!deleteDialog.plan) return;
        try {
            setSaving(true);
            await adminApi.deleteSubscriptionPlan(deleteDialog.plan.planKey);
            toast.success(`Deleted ${deleteDialog.plan.planKey}`);
            setDeleteDialog({ open: false, plan: null });
            await loadData();
        } catch (err) {
            toast.error(err.response?.data?.message || 'Failed to delete plan');
        } finally {
            setSaving(false);
        }
    };

    const field = (key, value) => setForm((f) => ({ ...f, [key]: value }));

    return (
        <Box>
            <PageHeader
                title="Subscription Plans"
                subtitle="Tune monthly price, event quota, and boost discount per tier. Changes apply to new subscriptions immediately."
                icon={<PremiumIcon />}
                actions={
                    <Stack direction="row" spacing={1}>
                        <Button variant="contained" startIcon={<AddIcon />} onClick={openCreate}>
                            Add Plan
                        </Button>
                        <Tooltip title="Refresh">
                            <IconButton onClick={loadData}><RefreshIcon /></IconButton>
                        </Tooltip>
                    </Stack>
                }
            />

            <Grid container spacing={2.5} sx={{ mt: 0.5 }}>
                {plans.map((plan) => {
                    const accent = PLAN_ACCENT[plan.planKey] || tokens.palette.neutral[600];
                    const unlimited = plan.maxEventsPerMonth === -1;
                    return (
                        <Grid item xs={12} sm={6} lg={3} key={plan.planKey}>
                            <SectionCard
                                sx={{
                                    borderTop: `3px solid ${accent}`,
                                    height: '100%',
                                    display: 'flex',
                                    flexDirection: 'column',
                                }}
                            >
                                <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 1.5 }}>
                                    <Typography variant="h6" fontWeight={800} sx={{ color: accent }}>
                                        {plan.planKey}
                                    </Typography>
                                    <StatusChip
                                        label={plan.active ? 'Active' : 'Hidden'}
                                        color={plan.active ? 'success' : 'default'}
                                        size="small"
                                    />
                                </Stack>
                                <Typography variant="body2" color="text.secondary">{plan.displayName}</Typography>

                                <Stack spacing={0.75} sx={{ mt: 2, mb: 2 }}>
                                    <Typography variant="h4" fontWeight={800}>
                                        ${Number(plan.monthlyPriceUsd).toFixed(2)}
                                        <Typography variant="caption" color="text.secondary" sx={{ ml: 0.5 }}>
                                            /month
                                        </Typography>
                                    </Typography>
                                    <Typography variant="caption" color="text.secondary">
                                        {unlimited ? 'Unlimited events' : `${plan.maxEventsPerMonth} events/month`}
                                        {' · '}
                                        {plan.boostDiscountPercent}% boost discount
                                    </Typography>
                                </Stack>

                                <Box sx={{ mt: 'auto' }}>
                                    <Stack direction="row" spacing={1}>
                                        <Button
                                            fullWidth
                                            variant="outlined"
                                            startIcon={<EditIcon />}
                                            onClick={() => openEdit(plan)}
                                            sx={{ borderColor: accent, color: accent }}
                                        >
                                            Edit
                                        </Button>
                                        <Tooltip title={CANONICAL_KEYS.has(plan.planKey)
                                            ? 'Canonical plan — toggle Active to hide instead'
                                            : 'Delete custom plan'}>
                                            <span>
                                                <IconButton
                                                    onClick={() => setDeleteDialog({ open: true, plan })}
                                                    disabled={CANONICAL_KEYS.has(plan.planKey)}
                                                    color="error"
                                                >
                                                    <DeleteIcon />
                                                </IconButton>
                                            </span>
                                        </Tooltip>
                                    </Stack>
                                </Box>
                            </SectionCard>
                        </Grid>
                    );
                })}
            </Grid>

            <Dialog open={editDialog.open} onClose={closeEdit} maxWidth="sm" fullWidth>
                <DialogTitle sx={{ fontWeight: 700 }}>
                    {editDialog.mode === 'create' ? 'Add New Subscription Plan' : `Edit ${editDialog.plan?.planKey} Plan`}
                </DialogTitle>
                <DialogContent dividers>
                    {form && (
                        <Stack spacing={2} sx={{ mt: 1 }}>
                            {editDialog.mode === 'create' && (
                                <TextField
                                    label="Plan Key"
                                    value={newKey}
                                    onChange={(e) => setNewKey(e.target.value.toUpperCase())}
                                    fullWidth
                                    required
                                    helperText="Uppercase code, e.g. TEAM, ENTERPRISE (A-Z, 0-9, _)"
                                    inputProps={{ pattern: '^[A-Z0-9_]{2,40}$' }}
                                />
                            )}
                            <TextField
                                label="Display Name"
                                value={form.displayName}
                                onChange={(e) => field('displayName', e.target.value)}
                                fullWidth
                            />
                            <Grid container spacing={2}>
                                <Grid item xs={6}>
                                    <TextField
                                        label="Monthly Price"
                                        type="number"
                                        inputProps={{ step: 0.01, min: 0 }}
                                        value={form.monthlyPriceUsd}
                                        onChange={(e) => field('monthlyPriceUsd', e.target.value)}
                                        InputProps={{ startAdornment: <InputAdornment position="start">$</InputAdornment> }}
                                        fullWidth
                                    />
                                </Grid>
                                <Grid item xs={6}>
                                    <TextField
                                        label="Max Events / Month"
                                        type="number"
                                        value={form.maxEventsPerMonth}
                                        onChange={(e) => field('maxEventsPerMonth', e.target.value)}
                                        fullWidth
                                        helperText="Use -1 for unlimited"
                                    />
                                </Grid>
                                <Grid item xs={6}>
                                    <TextField
                                        label="Boost Discount"
                                        type="number"
                                        inputProps={{ min: 0, max: 100 }}
                                        value={form.boostDiscountPercent}
                                        onChange={(e) => field('boostDiscountPercent', e.target.value)}
                                        InputProps={{ endAdornment: <InputAdornment position="end">%</InputAdornment> }}
                                        fullWidth
                                    />
                                </Grid>
                                <Grid item xs={6}>
                                    <TextField
                                        label="Sort Order"
                                        type="number"
                                        value={form.sortOrder}
                                        onChange={(e) => field('sortOrder', e.target.value)}
                                        fullWidth
                                    />
                                </Grid>
                            </Grid>
                            <FormControlLabel
                                control={<Switch checked={!!form.active} onChange={(e) => field('active', e.target.checked)} />}
                                label="Active (visible to organisers)"
                            />
                        </Stack>
                    )}
                </DialogContent>
                <DialogActions>
                    <Button onClick={closeEdit} disabled={saving}>Cancel</Button>
                    <LoadingButton variant="contained" onClick={handleSave} loading={saving}>
                        {editDialog.mode === 'create' ? 'Create Plan' : 'Save Changes'}
                    </LoadingButton>
                </DialogActions>
            </Dialog>

            <Dialog open={deleteDialog.open} onClose={() => setDeleteDialog({ open: false, plan: null })}>
                <DialogTitle sx={{ fontWeight: 700 }}>
                    Delete {deleteDialog.plan?.planKey}?
                </DialogTitle>
                <DialogContent dividers>
                    <Typography variant="body2" color="text.secondary">
                        This permanently removes the <b>{deleteDialog.plan?.planKey}</b> custom subscription plan.
                        Organisers currently subscribed continue until their billing period ends; new signups become impossible.
                        This cannot be undone.
                    </Typography>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setDeleteDialog({ open: false, plan: null })} disabled={saving}>
                        Cancel
                    </Button>
                    <LoadingButton variant="contained" color="error" onClick={handleDelete} loading={saving}>
                        Delete
                    </LoadingButton>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default AdminSubscriptionPlans;

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
    Chip,
    IconButton,
    Tooltip,
    InputAdornment,
} from '@mui/material';
import {
    Edit as EditIcon,
    Refresh as RefreshIcon,
    LocalFireDepartment as FireIcon,
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

const TIER_ACCENT = {
    VIP: tokens.palette.warning[600],
    PREMIUM: tokens.palette.primary[600],
    STANDARD: tokens.palette.info[600],
    BASIC: tokens.palette.success[600],
};

const CANONICAL_KEYS = new Set(['VIP', 'PREMIUM', 'STANDARD', 'BASIC']);

const AdminBoostPackages = () => {
    const [loading, setLoading] = useState(true);
    const [packages, setPackages] = useState([]);
    const [editDialog, setEditDialog] = useState({ open: false, pkg: null, mode: 'edit' });
    const [form, setForm] = useState(null);
    const [newKey, setNewKey] = useState('');
    const [saving, setSaving] = useState(false);
    const [deleteDialog, setDeleteDialog] = useState({ open: false, pkg: null });

    const loadData = async () => {
        try {
            setLoading(true);
            const res = await adminApi.getBoostPackages();
            setPackages(res.data.data || []);
        } catch (err) {
            toast.error('Failed to load boost packages');
            console.error(err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => { loadData(); }, []);

    const openEdit = (pkg) => {
        setEditDialog({ open: true, pkg, mode: 'edit' });
        setForm({
            displayName: pkg.displayName,
            priceUsd: pkg.priceUsd,
            durationDays: pkg.durationDays,
            boostMultiplier: pkg.boostMultiplier,
            badgeText: pkg.badgeText,
            featuredInCategory: pkg.featuredInCategory,
            featuredOnHome: pkg.featuredOnHome,
            priorityInSearch: pkg.priorityInSearch,
            homeBanner: pkg.homeBanner,
            active: pkg.active,
            sortOrder: pkg.sortOrder,
        });
    };

    const openCreate = () => {
        setEditDialog({ open: true, pkg: null, mode: 'create' });
        setNewKey('');
        setForm({
            displayName: '',
            priceUsd: 19.99,
            durationDays: 14,
            boostMultiplier: 2.0,
            badgeText: 'BOOSTED',
            featuredInCategory: false,
            featuredOnHome: false,
            priorityInSearch: true,
            homeBanner: false,
            active: true,
            sortOrder: 100,
        });
    };

    const closeEdit = () => {
        setEditDialog({ open: false, pkg: null, mode: 'edit' });
        setForm(null);
        setNewKey('');
    };

    const handleSave = async () => {
        if (!form) return;
        try {
            setSaving(true);
            const payload = {
                ...form,
                priceUsd: Number(form.priceUsd),
                durationDays: Number(form.durationDays),
                boostMultiplier: Number(form.boostMultiplier),
                sortOrder: Number(form.sortOrder),
            };
            if (editDialog.mode === 'create') {
                const key = (newKey || '').trim().toUpperCase();
                if (!/^[A-Z0-9_]{2,40}$/.test(key)) {
                    toast.error('Key must be uppercase letters / digits / underscore (2-40)');
                    setSaving(false);
                    return;
                }
                await adminApi.createBoostPackage(key, payload);
                toast.success(`Package ${key} created`);
            } else {
                await adminApi.updateBoostPackage(editDialog.pkg.packageKey, payload);
                toast.success(`${editDialog.pkg.packageKey} package updated`);
            }
            closeEdit();
            await loadData();
        } catch (err) {
            toast.error(err.response?.data?.message || 'Failed to save package');
        } finally {
            setSaving(false);
        }
    };

    const handleDelete = async () => {
        if (!deleteDialog.pkg) return;
        try {
            setSaving(true);
            await adminApi.deleteBoostPackage(deleteDialog.pkg.packageKey);
            toast.success(`Deleted ${deleteDialog.pkg.packageKey}`);
            setDeleteDialog({ open: false, pkg: null });
            await loadData();
        } catch (err) {
            toast.error(err.response?.data?.message || 'Failed to delete package');
        } finally {
            setSaving(false);
        }
    };

    const field = (key, value) => setForm((f) => ({ ...f, [key]: value }));

    return (
        <Box>
            <PageHeader
                title="Boost Packages"
                subtitle="Tune prices, durations, badges, and visibility flags. Changes apply to new purchases immediately."
                icon={<FireIcon />}
                actions={
                    <Stack direction="row" spacing={1}>
                        <Button variant="contained" startIcon={<AddIcon />} onClick={openCreate}>
                            Add Package
                        </Button>
                        <Tooltip title="Refresh">
                            <IconButton onClick={loadData}><RefreshIcon /></IconButton>
                        </Tooltip>
                    </Stack>
                }
            />

            <Grid container spacing={2.5} sx={{ mt: 0.5 }}>
                {packages.map((pkg) => {
                    const accent = TIER_ACCENT[pkg.packageKey] || tokens.palette.neutral[600];
                    return (
                        <Grid item xs={12} sm={6} lg={3} key={pkg.packageKey}>
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
                                        {pkg.packageKey}
                                    </Typography>
                                    <StatusChip
                                        label={pkg.active ? 'Active' : 'Hidden'}
                                        color={pkg.active ? 'success' : 'default'}
                                        size="small"
                                    />
                                </Stack>
                                <Typography variant="body2" color="text.secondary">{pkg.displayName}</Typography>

                                <Stack spacing={0.75} sx={{ mt: 2, mb: 2 }}>
                                    <Typography variant="h4" fontWeight={800}>
                                        ${Number(pkg.priceUsd).toFixed(2)}
                                        <Typography variant="caption" color="text.secondary" sx={{ ml: 0.5 }}>
                                            / {pkg.durationDays}d
                                        </Typography>
                                    </Typography>
                                    <Typography variant="caption" color="text.secondary">
                                        {pkg.boostMultiplier}× visibility · badge “{pkg.badgeText}”
                                    </Typography>
                                </Stack>

                                <Stack direction="row" flexWrap="wrap" gap={0.5} sx={{ mb: 2 }}>
                                    {pkg.homeBanner && <Chip size="small" label="Home Banner" color="warning" />}
                                    {pkg.featuredOnHome && <Chip size="small" label="Featured Home" color="primary" />}
                                    {pkg.featuredInCategory && <Chip size="small" label="Featured Category" color="info" />}
                                    {pkg.priorityInSearch && <Chip size="small" label="Search Priority" />}
                                </Stack>

                                <Box sx={{ mt: 'auto' }}>
                                    <Stack direction="row" spacing={1}>
                                        <Button
                                            fullWidth
                                            variant="outlined"
                                            startIcon={<EditIcon />}
                                            onClick={() => openEdit(pkg)}
                                            sx={{ borderColor: accent, color: accent }}
                                        >
                                            Edit
                                        </Button>
                                        <Tooltip title={CANONICAL_KEYS.has(pkg.packageKey)
                                            ? 'Canonical tier — toggle Active to hide instead'
                                            : 'Delete custom tier'}>
                                            <span>
                                                <IconButton
                                                    onClick={() => setDeleteDialog({ open: true, pkg })}
                                                    disabled={CANONICAL_KEYS.has(pkg.packageKey)}
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
                    {editDialog.mode === 'create' ? 'Add New Boost Package' : `Edit ${editDialog.pkg?.packageKey} Package`}
                </DialogTitle>
                <DialogContent dividers>
                    {form && (
                        <Stack spacing={2} sx={{ mt: 1 }}>
                            {editDialog.mode === 'create' && (
                                <TextField
                                    label="Package Key"
                                    value={newKey}
                                    onChange={(e) => setNewKey(e.target.value.toUpperCase())}
                                    fullWidth
                                    required
                                    helperText="Uppercase code, e.g. MEGA, ULTRA (A-Z, 0-9, _)"
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
                                        label="Price"
                                        type="number"
                                        value={form.priceUsd}
                                        onChange={(e) => field('priceUsd', e.target.value)}
                                        InputProps={{ startAdornment: <InputAdornment position="start">$</InputAdornment> }}
                                        fullWidth
                                    />
                                </Grid>
                                <Grid item xs={6}>
                                    <TextField
                                        label="Duration"
                                        type="number"
                                        value={form.durationDays}
                                        onChange={(e) => field('durationDays', e.target.value)}
                                        InputProps={{ endAdornment: <InputAdornment position="end">days</InputAdornment> }}
                                        fullWidth
                                    />
                                </Grid>
                                <Grid item xs={6}>
                                    <TextField
                                        label="Visibility Multiplier"
                                        type="number"
                                        inputProps={{ step: 0.1, min: 1 }}
                                        value={form.boostMultiplier}
                                        onChange={(e) => field('boostMultiplier', e.target.value)}
                                        fullWidth
                                        helperText="×1.0 = no boost, ×5.0 = VIP"
                                    />
                                </Grid>
                                <Grid item xs={6}>
                                    <TextField
                                        label="Badge Text"
                                        value={form.badgeText}
                                        onChange={(e) => field('badgeText', e.target.value)}
                                        fullWidth
                                        helperText="Shown on event cards"
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
                            <Box>
                                <Typography variant="subtitle2" sx={{ mb: 1 }}>Visibility flags</Typography>
                                <Stack>
                                    <FormControlLabel
                                        control={<Switch checked={!!form.homeBanner} onChange={(e) => field('homeBanner', e.target.checked)} />}
                                        label="Home VIP banner carousel"
                                    />
                                    <FormControlLabel
                                        control={<Switch checked={!!form.featuredOnHome} onChange={(e) => field('featuredOnHome', e.target.checked)} />}
                                        label="Featured & Boosted section on Home"
                                    />
                                    <FormControlLabel
                                        control={<Switch checked={!!form.featuredInCategory} onChange={(e) => field('featuredInCategory', e.target.checked)} />}
                                        label="Featured in category pages"
                                    />
                                    <FormControlLabel
                                        control={<Switch checked={!!form.priorityInSearch} onChange={(e) => field('priorityInSearch', e.target.checked)} />}
                                        label="Priority in search / listing"
                                    />
                                    <FormControlLabel
                                        control={<Switch checked={!!form.active} onChange={(e) => field('active', e.target.checked)} />}
                                        label="Active (available for purchase)"
                                    />
                                </Stack>
                            </Box>
                        </Stack>
                    )}
                </DialogContent>
                <DialogActions>
                    <Button onClick={closeEdit} disabled={saving}>Cancel</Button>
                    <LoadingButton variant="contained" onClick={handleSave} loading={saving}>
                        {editDialog.mode === 'create' ? 'Create Package' : 'Save Changes'}
                    </LoadingButton>
                </DialogActions>
            </Dialog>

            <Dialog open={deleteDialog.open} onClose={() => setDeleteDialog({ open: false, pkg: null })}>
                <DialogTitle sx={{ fontWeight: 700 }}>
                    Delete {deleteDialog.pkg?.packageKey}?
                </DialogTitle>
                <DialogContent dividers>
                    <Typography variant="body2" color="text.secondary">
                        This permanently removes the <b>{deleteDialog.pkg?.packageKey}</b> custom boost tier.
                        Existing active boosts on this tier continue until expiry; new purchases become impossible.
                        This cannot be undone.
                    </Typography>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setDeleteDialog({ open: false, pkg: null })} disabled={saving}>
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

export default AdminBoostPackages;

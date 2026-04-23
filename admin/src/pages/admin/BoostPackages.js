import React, { useState, useEffect, useMemo } from 'react';
import {
    Box,
    Grid,
    Stack,
    Typography,
    TextField,
    Dialog,
    DialogContent,
    DialogActions,
    Button,
    Switch,
    Chip,
    IconButton,
    Tooltip,
    InputAdornment,
    Divider,
    alpha,
} from '@mui/material';
import {
    Edit as EditIcon,
    Refresh as RefreshIcon,
    LocalFireDepartment as FireIcon,
    Add as AddIcon,
    Delete as DeleteIcon,
    Close as CloseIcon,
    CheckCircleRounded as CheckIcon,
    WorkspacePremiumRounded as CrownIcon,
    AutoAwesomeRounded as SparkleIcon,
    TrendingUpRounded as TrendIcon,
    StarRounded as StarIcon,
    HomeRounded as HomeIcon,
    CampaignRounded as CampaignIcon,
    CategoryRounded as CategoryIcon,
    SearchRounded as SearchIcon,
    VisibilityRounded as VisibilityIcon,
    SellRounded as SellIcon,
    BoltRounded as BoltIcon,
    TuneRounded as TuneIcon,
    LocalOfferRounded as OfferIcon,
} from '@mui/icons-material';
import { toast } from 'react-toastify';
import adminApi from '../../api/adminApi';
import {
    PageHeader,
    LoadingButton,
} from '../../components/ui';
import { tokens } from '../../theme';

const TIER_THEME = {
    VIP: {
        accent: tokens.palette.warning[600],
        accentSoft: tokens.palette.warning[500],
        gradient: `linear-gradient(135deg, ${tokens.palette.warning[500]} 0%, ${tokens.palette.secondary[500]} 100%)`,
        glow: 'rgba(245, 158, 11, 0.35)',
        icon: CrownIcon,
        tagline: 'Maximum exposure — top shelf for premier events',
    },
    PREMIUM: {
        accent: tokens.palette.primary[600],
        accentSoft: tokens.palette.primary[500],
        gradient: `linear-gradient(135deg, ${tokens.palette.primary[500]} 0%, ${tokens.palette.secondary[500]} 100%)`,
        glow: 'rgba(99, 102, 241, 0.35)',
        icon: SparkleIcon,
        tagline: 'Strong placement across home & categories',
    },
    STANDARD: {
        accent: tokens.palette.info[600],
        accentSoft: tokens.palette.info[500],
        gradient: `linear-gradient(135deg, ${tokens.palette.info[500]} 0%, ${tokens.palette.primary[500]} 100%)`,
        glow: 'rgba(59, 130, 246, 0.3)',
        icon: TrendIcon,
        tagline: 'Solid boost — better visibility, lower cost',
    },
    BASIC: {
        accent: tokens.palette.success[600],
        accentSoft: tokens.palette.success[500],
        gradient: `linear-gradient(135deg, ${tokens.palette.success[500]} 0%, ${tokens.palette.info[500]} 100%)`,
        glow: 'rgba(16, 185, 129, 0.3)',
        icon: StarIcon,
        tagline: 'Entry-level lift — great for small events',
    },
};

const DEFAULT_TIER = {
    accent: tokens.palette.neutral[600],
    accentSoft: tokens.palette.neutral[500],
    gradient: `linear-gradient(135deg, ${tokens.palette.neutral[600]} 0%, ${tokens.palette.neutral[800]} 100%)`,
    glow: 'rgba(71, 85, 105, 0.3)',
    icon: BoltIcon,
    tagline: 'Custom boost tier',
};

const CANONICAL_KEYS = new Set(['VIP', 'PREMIUM', 'STANDARD', 'BASIC']);

const FLAG_META = [
    { key: 'homeBanner', label: 'Home VIP banner', description: 'Appears in the hero carousel on Home', icon: CampaignIcon },
    { key: 'featuredOnHome', label: 'Featured on Home', description: 'Featured & Boosted section', icon: HomeIcon },
    { key: 'featuredInCategory', label: 'Featured in category', description: 'Top of category pages', icon: CategoryIcon },
    { key: 'priorityInSearch', label: 'Search priority', description: 'Ranks higher in search / listings', icon: SearchIcon },
    { key: 'active', label: 'Available for purchase', description: 'Organisers can buy this package', icon: VisibilityIcon },
];

const AdminBoostPackages = () => {
    const [packages, setPackages] = useState([]);
    const [editDialog, setEditDialog] = useState({ open: false, pkg: null, mode: 'edit' });
    const [form, setForm] = useState(null);
    const [newKey, setNewKey] = useState('');
    const [saving, setSaving] = useState(false);
    const [deleteDialog, setDeleteDialog] = useState({ open: false, pkg: null });

    const loadData = async () => {
        try {
            const res = await adminApi.getBoostPackages();
            setPackages(res.data.data || []);
        } catch (err) {
            toast.error('Failed to load boost packages');
            console.error(err);
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
            discountEligible: pkg.discountEligible !== false,
            discountPercent: pkg.discountPercent ?? 0,
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
            discountEligible: true,
            discountPercent: 0,
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
        const displayName = (form.displayName || '').trim();
        if (!displayName) {
            toast.error('Display name is required');
            return;
        }
        const badgeText = (form.badgeText || '').trim();
        if (!badgeText) {
            toast.error('Badge text is required');
            return;
        }
        try {
            setSaving(true);
            const discountPct = Math.max(0, Math.min(100, Number(form.discountPercent) || 0));
            const payload = {
                ...form,
                displayName,
                badgeText,
                priceUsd: Number(form.priceUsd),
                durationDays: Number(form.durationDays),
                boostMultiplier: Number(form.boostMultiplier),
                discountPercent: discountPct,
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

    const activeTheme = useMemo(() => {
        if (!editDialog.pkg) return TIER_THEME.PREMIUM || DEFAULT_TIER;
        return TIER_THEME[editDialog.pkg.packageKey] || DEFAULT_TIER;
    }, [editDialog.pkg]);

    return (
        <Box>
            <PageHeader
                title="Boost Packages"
                subtitle="Tune prices, durations, badges, and visibility flags. Changes apply to new purchases immediately."
                icon={<FireIcon />}
                actions={
                    <Stack direction="row" spacing={1}>
                        <Button
                            variant="contained"
                            startIcon={<AddIcon />}
                            onClick={openCreate}
                            sx={{
                                background: tokens.gradient.primary,
                                boxShadow: tokens.shadow.primaryGlow,
                                fontWeight: 600,
                                '&:hover': {
                                    background: tokens.gradient.primary,
                                    filter: 'brightness(1.05)',
                                },
                            }}
                        >
                            Add Package
                        </Button>
                        <Tooltip title="Refresh">
                            <IconButton onClick={loadData} sx={{ border: `1px solid ${tokens.borders.subtle}` }}>
                                <RefreshIcon />
                            </IconButton>
                        </Tooltip>
                    </Stack>
                }
            />

            <Grid container spacing={3} sx={{ mt: 0.5 }}>
                {packages.map((pkg) => {
                    const theme = TIER_THEME[pkg.packageKey] || DEFAULT_TIER;
                    const TierIcon = theme.icon;
                    const featureList = FLAG_META.filter((f) => f.key !== 'active' && pkg[f.key]);
                    const hasSale = pkg.discountPercent > 0;
                    const salePrice = hasSale
                        ? Number(pkg.priceUsd) * (1 - pkg.discountPercent / 100)
                        : null;

                    return (
                        <Grid item xs={12} sm={6} lg={3} key={pkg.packageKey}>
                            <Box
                                sx={{
                                    position: 'relative',
                                    height: '100%',
                                    borderRadius: 3,
                                    overflow: 'hidden',
                                    background: tokens.surfaces.card,
                                    border: `1px solid ${tokens.borders.subtle}`,
                                    boxShadow: tokens.shadow.sm,
                                    transition: `transform ${tokens.motion.base}, box-shadow ${tokens.motion.base}`,
                                    display: 'flex',
                                    flexDirection: 'column',
                                    '&:hover': {
                                        transform: 'translateY(-4px)',
                                        boxShadow: `0 20px 40px -16px ${theme.glow}, ${tokens.shadow.lg}`,
                                    },
                                }}
                            >
                                {/* Gradient header band */}
                                <Box
                                    sx={{
                                        position: 'relative',
                                        p: 2.5,
                                        pb: 2,
                                        background: theme.gradient,
                                        color: '#fff',
                                        overflow: 'hidden',
                                        '&::after': {
                                            content: '""',
                                            position: 'absolute',
                                            top: -40,
                                            right: -40,
                                            width: 160,
                                            height: 160,
                                            borderRadius: '50%',
                                            background: 'rgba(255,255,255,0.12)',
                                            pointerEvents: 'none',
                                        },
                                    }}
                                >
                                    <Stack direction="row" alignItems="flex-start" justifyContent="space-between">
                                        <Stack direction="row" spacing={1.25} alignItems="center">
                                            <Box
                                                sx={{
                                                    width: 40,
                                                    height: 40,
                                                    borderRadius: 2,
                                                    bgcolor: 'rgba(255,255,255,0.2)',
                                                    backdropFilter: 'blur(8px)',
                                                    display: 'flex',
                                                    alignItems: 'center',
                                                    justifyContent: 'center',
                                                    border: '1px solid rgba(255,255,255,0.3)',
                                                }}
                                            >
                                                <TierIcon sx={{ fontSize: 22, color: '#fff' }} />
                                            </Box>
                                            <Box>
                                                <Typography
                                                    sx={{
                                                        fontWeight: 800,
                                                        fontSize: '1.125rem',
                                                        letterSpacing: '0.04em',
                                                        lineHeight: 1.1,
                                                    }}
                                                >
                                                    {pkg.packageKey}
                                                </Typography>
                                                <Typography
                                                    sx={{
                                                        fontSize: '0.7rem',
                                                        opacity: 0.85,
                                                        fontWeight: 500,
                                                        letterSpacing: '0.02em',
                                                    }}
                                                >
                                                    {pkg.active ? 'LIVE' : 'HIDDEN'}
                                                </Typography>
                                            </Box>
                                        </Stack>

                                        {hasSale && (
                                            <Chip
                                                size="small"
                                                icon={<OfferIcon sx={{ fontSize: 14, color: '#fff !important' }} />}
                                                label={`-${pkg.discountPercent}%`}
                                                sx={{
                                                    bgcolor: 'rgba(255,255,255,0.25)',
                                                    color: '#fff',
                                                    fontWeight: 700,
                                                    height: 24,
                                                    border: '1px solid rgba(255,255,255,0.4)',
                                                    backdropFilter: 'blur(8px)',
                                                    '& .MuiChip-label': { px: 0.75 },
                                                }}
                                            />
                                        )}
                                    </Stack>

                                    <Typography
                                        sx={{
                                            mt: 1.5,
                                            fontSize: '0.75rem',
                                            opacity: 0.92,
                                            minHeight: 32,
                                            lineHeight: 1.4,
                                        }}
                                    >
                                        {theme.tagline}
                                    </Typography>
                                </Box>

                                {/* Body */}
                                <Box sx={{ p: 2.5, pt: 2.25, display: 'flex', flexDirection: 'column', flex: 1 }}>
                                    <Typography
                                        sx={{
                                            fontSize: '0.95rem',
                                            fontWeight: 600,
                                            color: pkg.displayName ? tokens.text.primary : tokens.palette.danger[600],
                                        }}
                                    >
                                        {pkg.displayName || '(No display name — edit to set one)'}
                                    </Typography>

                                    {/* Price block */}
                                    <Box sx={{ mt: 1.75, mb: 2 }}>
                                        <Stack direction="row" alignItems="flex-end" spacing={0.5}>
                                            {hasSale ? (
                                                <>
                                                    <Typography
                                                        sx={{
                                                            fontSize: '2rem',
                                                            fontWeight: 800,
                                                            color: theme.accent,
                                                            lineHeight: 1,
                                                            letterSpacing: '-0.02em',
                                                        }}
                                                    >
                                                        ${salePrice.toFixed(2)}
                                                    </Typography>
                                                    <Typography
                                                        sx={{
                                                            fontSize: '0.875rem',
                                                            color: tokens.text.muted,
                                                            textDecoration: 'line-through',
                                                            pb: 0.25,
                                                        }}
                                                    >
                                                        ${Number(pkg.priceUsd).toFixed(2)}
                                                    </Typography>
                                                </>
                                            ) : (
                                                <Typography
                                                    sx={{
                                                        fontSize: '2rem',
                                                        fontWeight: 800,
                                                        color: theme.accent,
                                                        lineHeight: 1,
                                                        letterSpacing: '-0.02em',
                                                    }}
                                                >
                                                    ${Number(pkg.priceUsd).toFixed(2)}
                                                </Typography>
                                            )}
                                            <Typography
                                                sx={{
                                                    fontSize: '0.8125rem',
                                                    color: tokens.text.muted,
                                                    pb: 0.4,
                                                    ml: 0.25,
                                                }}
                                            >
                                                / {pkg.durationDays}d
                                            </Typography>
                                        </Stack>

                                        <Stack direction="row" spacing={0.75} sx={{ mt: 1.25 }}>
                                            <Box
                                                sx={{
                                                    display: 'inline-flex',
                                                    alignItems: 'center',
                                                    gap: 0.5,
                                                    px: 1,
                                                    py: 0.375,
                                                    borderRadius: 999,
                                                    bgcolor: alpha(theme.accent, 0.1),
                                                    color: theme.accent,
                                                    fontSize: '0.7rem',
                                                    fontWeight: 700,
                                                    letterSpacing: '0.02em',
                                                }}
                                            >
                                                <BoltIcon sx={{ fontSize: 13 }} />
                                                {pkg.boostMultiplier}× visibility
                                            </Box>
                                            <Box
                                                sx={{
                                                    display: 'inline-flex',
                                                    alignItems: 'center',
                                                    px: 1,
                                                    py: 0.375,
                                                    borderRadius: 999,
                                                    bgcolor: tokens.palette.neutral[100],
                                                    color: tokens.text.secondary,
                                                    fontSize: '0.7rem',
                                                    fontWeight: 700,
                                                    letterSpacing: '0.02em',
                                                }}
                                            >
                                                “{pkg.badgeText}”
                                            </Box>
                                        </Stack>
                                    </Box>

                                    <Divider sx={{ mb: 1.5 }} />

                                    {/* Included features with checkmarks */}
                                    <Stack spacing={0.875} sx={{ mb: 2 }}>
                                        {featureList.length > 0 ? featureList.map((f) => {
                                            const FIcon = f.icon;
                                            return (
                                                <Stack key={f.key} direction="row" alignItems="center" spacing={1}>
                                                    <Box
                                                        sx={{
                                                            width: 22,
                                                            height: 22,
                                                            borderRadius: '50%',
                                                            bgcolor: alpha(theme.accent, 0.12),
                                                            color: theme.accent,
                                                            display: 'flex',
                                                            alignItems: 'center',
                                                            justifyContent: 'center',
                                                            flexShrink: 0,
                                                        }}
                                                    >
                                                        <CheckIcon sx={{ fontSize: 16 }} />
                                                    </Box>
                                                    <Typography sx={{ fontSize: '0.8125rem', color: tokens.text.primary }}>
                                                        {f.label}
                                                    </Typography>
                                                    <FIcon sx={{ fontSize: 14, color: tokens.text.muted, ml: 'auto' }} />
                                                </Stack>
                                            );
                                        }) : (
                                            <Typography variant="caption" color="text.secondary" sx={{ fontStyle: 'italic' }}>
                                                No visibility flags enabled
                                            </Typography>
                                        )}
                                        {pkg.discountEligible === false && (
                                            <Stack direction="row" alignItems="center" spacing={1}>
                                                <Box
                                                    sx={{
                                                        width: 22,
                                                        height: 22,
                                                        borderRadius: '50%',
                                                        bgcolor: alpha(tokens.palette.danger[500], 0.12),
                                                        color: tokens.palette.danger[600],
                                                        display: 'flex',
                                                        alignItems: 'center',
                                                        justifyContent: 'center',
                                                        flexShrink: 0,
                                                        fontSize: 14,
                                                        fontWeight: 800,
                                                    }}
                                                >
                                                    ×
                                                </Box>
                                                <Typography sx={{ fontSize: '0.8125rem', color: tokens.palette.danger[700] }}>
                                                    No subscription discount
                                                </Typography>
                                            </Stack>
                                        )}
                                    </Stack>

                                    {/* Footer actions */}
                                    <Box sx={{ mt: 'auto' }}>
                                        <Stack direction="row" spacing={1}>
                                            <Button
                                                fullWidth
                                                variant="contained"
                                                disableElevation
                                                startIcon={<EditIcon />}
                                                onClick={() => openEdit(pkg)}
                                                sx={{
                                                    background: theme.gradient,
                                                    fontWeight: 600,
                                                    textTransform: 'none',
                                                    py: 1,
                                                    '&:hover': {
                                                        background: theme.gradient,
                                                        filter: 'brightness(1.08)',
                                                        boxShadow: `0 8px 20px -8px ${theme.glow}`,
                                                    },
                                                }}
                                            >
                                                Edit Package
                                            </Button>
                                            <Tooltip
                                                title={CANONICAL_KEYS.has(pkg.packageKey)
                                                    ? 'Canonical tier — toggle Active to hide instead'
                                                    : 'Delete custom tier'}
                                            >
                                                <span>
                                                    <IconButton
                                                        onClick={() => setDeleteDialog({ open: true, pkg })}
                                                        disabled={CANONICAL_KEYS.has(pkg.packageKey)}
                                                        sx={{
                                                            border: `1px solid ${tokens.borders.subtle}`,
                                                            color: tokens.palette.danger[500],
                                                            '&:hover': {
                                                                bgcolor: alpha(tokens.palette.danger[500], 0.08),
                                                                borderColor: tokens.palette.danger[300],
                                                            },
                                                            '&.Mui-disabled': {
                                                                color: tokens.text.disabled,
                                                            },
                                                        }}
                                                    >
                                                        <DeleteIcon fontSize="small" />
                                                    </IconButton>
                                                </span>
                                            </Tooltip>
                                        </Stack>
                                    </Box>
                                </Box>
                            </Box>
                        </Grid>
                    );
                })}
            </Grid>

            {/* Edit / Create dialog */}
            <Dialog
                open={editDialog.open}
                onClose={closeEdit}
                maxWidth="sm"
                fullWidth
                PaperProps={{
                    sx: {
                        borderRadius: 3,
                        overflow: 'hidden',
                        boxShadow: tokens.shadow.xl,
                    },
                }}
            >
                {/* Gradient header */}
                <Box
                    sx={{
                        position: 'relative',
                        px: 3,
                        pt: 2.75,
                        pb: 2.5,
                        background: activeTheme.gradient,
                        color: '#fff',
                        overflow: 'hidden',
                        '&::after': {
                            content: '""',
                            position: 'absolute',
                            top: -60,
                            right: -60,
                            width: 200,
                            height: 200,
                            borderRadius: '50%',
                            background: 'rgba(255,255,255,0.12)',
                            pointerEvents: 'none',
                        },
                    }}
                >
                    <Stack direction="row" alignItems="center" justifyContent="space-between">
                        <Stack direction="row" spacing={1.5} alignItems="center">
                            <Box
                                sx={{
                                    width: 44,
                                    height: 44,
                                    borderRadius: 2,
                                    bgcolor: 'rgba(255,255,255,0.22)',
                                    backdropFilter: 'blur(8px)',
                                    display: 'flex',
                                    alignItems: 'center',
                                    justifyContent: 'center',
                                    border: '1px solid rgba(255,255,255,0.35)',
                                }}
                            >
                                {editDialog.mode === 'create'
                                    ? <AddIcon sx={{ fontSize: 24 }} />
                                    : <EditIcon sx={{ fontSize: 22 }} />}
                            </Box>
                            <Box>
                                <Typography sx={{ fontWeight: 700, fontSize: '1.125rem', lineHeight: 1.2 }}>
                                    {editDialog.mode === 'create'
                                        ? 'Add New Boost Package'
                                        : `Edit ${editDialog.pkg?.packageKey} Package`}
                                </Typography>
                                <Typography sx={{ fontSize: '0.8125rem', opacity: 0.9, mt: 0.25 }}>
                                    {editDialog.mode === 'create'
                                        ? 'Define a custom boost tier for organisers'
                                        : 'Changes apply to new purchases only'}
                                </Typography>
                            </Box>
                        </Stack>
                        <IconButton
                            onClick={closeEdit}
                            sx={{
                                color: '#fff',
                                bgcolor: 'rgba(255,255,255,0.15)',
                                '&:hover': { bgcolor: 'rgba(255,255,255,0.25)' },
                            }}
                            size="small"
                        >
                            <CloseIcon fontSize="small" />
                        </IconButton>
                    </Stack>
                </Box>

                <DialogContent sx={{ px: 3, pt: 3, pb: 2 }}>
                    {form && (
                        <Stack spacing={3}>
                            {/* Section: Identity */}
                            <Box>
                                <SectionTitle icon={<TuneIcon sx={{ fontSize: 16 }} />} accent={activeTheme.accent}>
                                    Basics
                                </SectionTitle>
                                <Stack spacing={2}>
                                    {editDialog.mode === 'create' && (
                                        <TextField
                                            label="Package Key"
                                            value={newKey}
                                            onChange={(e) => setNewKey(e.target.value.toUpperCase())}
                                            fullWidth
                                            size="small"
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
                                        size="small"
                                        required
                                        error={!form.displayName?.trim()}
                                        helperText={!form.displayName?.trim() ? 'Required — shown on the boost card' : ' '}
                                    />
                                </Stack>
                            </Box>

                            {/* Section: Pricing & mechanics */}
                            <Box>
                                <SectionTitle icon={<SellIcon sx={{ fontSize: 16 }} />} accent={activeTheme.accent}>
                                    Pricing & mechanics
                                </SectionTitle>
                                <Grid container spacing={2}>
                                    <Grid item xs={6}>
                                        <TextField
                                            label="Price"
                                            type="number"
                                            value={form.priceUsd}
                                            size="small"
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
                                            size="small"
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
                                            size="small"
                                            onChange={(e) => field('boostMultiplier', e.target.value)}
                                            fullWidth
                                            helperText="×1.0 = no boost · ×5.0 = VIP"
                                        />
                                    </Grid>
                                    <Grid item xs={6}>
                                        <TextField
                                            label="Badge Text"
                                            value={form.badgeText}
                                            size="small"
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
                                            size="small"
                                            onChange={(e) => field('sortOrder', e.target.value)}
                                            fullWidth
                                            helperText="Lower appears first"
                                        />
                                    </Grid>
                                </Grid>
                            </Box>

                            {/* Section: Visibility flags as toggle rows */}
                            <Box>
                                <SectionTitle icon={<VisibilityIcon sx={{ fontSize: 16 }} />} accent={activeTheme.accent}>
                                    Where this boost shows up
                                </SectionTitle>
                                <Stack
                                    sx={{
                                        border: `1px solid ${tokens.borders.subtle}`,
                                        borderRadius: 2,
                                        overflow: 'hidden',
                                        bgcolor: tokens.palette.neutral[50],
                                    }}
                                >
                                    {FLAG_META.map((f, idx) => {
                                        const FIcon = f.icon;
                                        const on = !!form[f.key];
                                        return (
                                            <Stack
                                                key={f.key}
                                                direction="row"
                                                alignItems="center"
                                                spacing={1.5}
                                                onClick={() => field(f.key, !on)}
                                                sx={{
                                                    px: 1.75,
                                                    py: 1.25,
                                                    cursor: 'pointer',
                                                    bgcolor: on ? alpha(activeTheme.accent, 0.06) : 'transparent',
                                                    borderBottom: idx === FLAG_META.length - 1
                                                        ? 'none'
                                                        : `1px solid ${tokens.borders.subtle}`,
                                                    transition: `background ${tokens.motion.fast}`,
                                                    '&:hover': {
                                                        bgcolor: on
                                                            ? alpha(activeTheme.accent, 0.1)
                                                            : tokens.palette.neutral[100],
                                                    },
                                                }}
                                            >
                                                <Box
                                                    sx={{
                                                        width: 32,
                                                        height: 32,
                                                        borderRadius: 1.5,
                                                        display: 'flex',
                                                        alignItems: 'center',
                                                        justifyContent: 'center',
                                                        bgcolor: on
                                                            ? alpha(activeTheme.accent, 0.15)
                                                            : tokens.palette.neutral[200],
                                                        color: on ? activeTheme.accent : tokens.text.muted,
                                                        transition: `all ${tokens.motion.fast}`,
                                                    }}
                                                >
                                                    <FIcon sx={{ fontSize: 18 }} />
                                                </Box>
                                                <Box sx={{ flex: 1, minWidth: 0 }}>
                                                    <Typography
                                                        sx={{
                                                            fontSize: '0.875rem',
                                                            fontWeight: 600,
                                                            color: tokens.text.primary,
                                                            lineHeight: 1.3,
                                                        }}
                                                    >
                                                        {f.label}
                                                    </Typography>
                                                    <Typography
                                                        sx={{ fontSize: '0.75rem', color: tokens.text.muted }}
                                                    >
                                                        {f.description}
                                                    </Typography>
                                                </Box>
                                                <Switch
                                                    checked={on}
                                                    onClick={(e) => e.stopPropagation()}
                                                    onChange={(e) => field(f.key, e.target.checked)}
                                                    sx={{
                                                        '& .MuiSwitch-switchBase.Mui-checked': {
                                                            color: activeTheme.accent,
                                                        },
                                                        '& .MuiSwitch-switchBase.Mui-checked + .MuiSwitch-track': {
                                                            bgcolor: activeTheme.accent,
                                                        },
                                                    }}
                                                />
                                            </Stack>
                                        );
                                    })}
                                </Stack>
                            </Box>

                            {/* Section: Promotions */}
                            <Box>
                                <SectionTitle icon={<OfferIcon sx={{ fontSize: 16 }} />} accent={activeTheme.accent}>
                                    Promotions
                                </SectionTitle>
                                <TextField
                                    label="Package sale (%)"
                                    type="number"
                                    size="small"
                                    value={form.discountPercent ?? 0}
                                    onChange={(e) => field('discountPercent', e.target.value)}
                                    inputProps={{ min: 0, max: 100, step: 1 }}
                                    InputProps={{ endAdornment: <InputAdornment position="end">%</InputAdornment> }}
                                    fullWidth
                                    helperText="Sale applied to everyone buying this package (0 = no sale)"
                                    sx={{ mb: 1.5 }}
                                />
                                <Box
                                    onClick={() => field('discountEligible', !(form.discountEligible !== false))}
                                    sx={{
                                        cursor: 'pointer',
                                        p: 1.5,
                                        border: `1px solid ${tokens.borders.subtle}`,
                                        borderRadius: 2,
                                        bgcolor: tokens.palette.neutral[50],
                                        transition: `all ${tokens.motion.fast}`,
                                        '&:hover': { bgcolor: tokens.palette.neutral[100] },
                                    }}
                                >
                                    <Stack direction="row" alignItems="center" spacing={1.5}>
                                        <Switch
                                            checked={form.discountEligible !== false}
                                            onClick={(e) => e.stopPropagation()}
                                            onChange={(e) => field('discountEligible', e.target.checked)}
                                            sx={{
                                                '& .MuiSwitch-switchBase.Mui-checked': { color: activeTheme.accent },
                                                '& .MuiSwitch-switchBase.Mui-checked + .MuiSwitch-track': {
                                                    bgcolor: activeTheme.accent,
                                                },
                                            }}
                                        />
                                        <Box sx={{ flex: 1 }}>
                                            <Typography sx={{ fontSize: '0.875rem', fontWeight: 600 }}>
                                                Eligible for subscription discount
                                            </Typography>
                                            <Typography sx={{ fontSize: '0.7rem', color: tokens.text.muted, mt: 0.25 }}>
                                                When a package sale and subscription discount both apply, the higher is used (not stacked).
                                            </Typography>
                                        </Box>
                                    </Stack>
                                </Box>
                            </Box>
                        </Stack>
                    )}
                </DialogContent>
                <DialogActions
                    sx={{
                        px: 3,
                        py: 2,
                        borderTop: `1px solid ${tokens.borders.subtle}`,
                        bgcolor: tokens.palette.neutral[50],
                    }}
                >
                    <Button onClick={closeEdit} disabled={saving} sx={{ textTransform: 'none', fontWeight: 600 }}>
                        Cancel
                    </Button>
                    <LoadingButton
                        variant="contained"
                        onClick={handleSave}
                        loading={saving}
                        sx={{
                            background: activeTheme.gradient,
                            textTransform: 'none',
                            fontWeight: 600,
                            px: 3,
                            boxShadow: `0 8px 20px -8px ${activeTheme.glow}`,
                            '&:hover': {
                                background: activeTheme.gradient,
                                filter: 'brightness(1.08)',
                            },
                        }}
                    >
                        {editDialog.mode === 'create' ? 'Create Package' : 'Save Changes'}
                    </LoadingButton>
                </DialogActions>
            </Dialog>

            {/* Delete dialog */}
            <Dialog
                open={deleteDialog.open}
                onClose={() => setDeleteDialog({ open: false, pkg: null })}
                PaperProps={{ sx: { borderRadius: 3, overflow: 'hidden' } }}
            >
                <Box
                    sx={{
                        px: 3,
                        pt: 2.75,
                        pb: 2.25,
                        background: `linear-gradient(135deg, ${tokens.palette.danger[500]} 0%, ${tokens.palette.danger[700]} 100%)`,
                        color: '#fff',
                    }}
                >
                    <Stack direction="row" alignItems="center" spacing={1.5}>
                        <Box
                            sx={{
                                width: 40,
                                height: 40,
                                borderRadius: 2,
                                bgcolor: 'rgba(255,255,255,0.22)',
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                            }}
                        >
                            <DeleteIcon />
                        </Box>
                        <Typography sx={{ fontWeight: 700, fontSize: '1.1rem' }}>
                            Delete {deleteDialog.pkg?.packageKey}?
                        </Typography>
                    </Stack>
                </Box>
                <DialogContent sx={{ px: 3, py: 3 }}>
                    <Typography variant="body2" color="text.secondary">
                        This permanently removes the <b>{deleteDialog.pkg?.packageKey}</b> custom boost tier.
                        Existing active boosts on this tier continue until expiry; new purchases become impossible.
                        This cannot be undone.
                    </Typography>
                </DialogContent>
                <DialogActions sx={{ px: 3, py: 2, bgcolor: tokens.palette.neutral[50] }}>
                    <Button
                        onClick={() => setDeleteDialog({ open: false, pkg: null })}
                        disabled={saving}
                        sx={{ textTransform: 'none', fontWeight: 600 }}
                    >
                        Cancel
                    </Button>
                    <LoadingButton
                        variant="contained"
                        color="error"
                        onClick={handleDelete}
                        loading={saving}
                        sx={{ textTransform: 'none', fontWeight: 600, px: 3 }}
                    >
                        Delete
                    </LoadingButton>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

const SectionTitle = ({ icon, accent, children }) => (
    <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.25 }}>
        <Box
            sx={{
                width: 26,
                height: 26,
                borderRadius: 1,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                bgcolor: alpha(accent, 0.12),
                color: accent,
            }}
        >
            {icon}
        </Box>
        <Typography
            sx={{
                fontSize: '0.8125rem',
                fontWeight: 700,
                color: tokens.text.primary,
                letterSpacing: '0.02em',
                textTransform: 'uppercase',
            }}
        >
            {children}
        </Typography>
    </Stack>
);

export default AdminBoostPackages;

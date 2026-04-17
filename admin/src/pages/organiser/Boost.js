import React, { useState, useEffect } from 'react';
import {
    Box,
    Typography,
    Grid,
    Button,
    IconButton,
    Tooltip,
    Chip,
    TextField,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    TablePagination,
    Avatar,
    Alert,
    Autocomplete,
    CircularProgress,
    Divider,
    Stack,
} from '@mui/material';
import {
    Refresh as RefreshIcon,
    Rocket as RocketIcon,
    Star as StarIcon,
    Bolt as BoltIcon,
    Diamond as DiamondIcon,
    Add as AddIcon,
    CheckCircle as ActiveIcon,
    TrendingUp as UpgradeIcon,
    AccessTime as ExtendIcon,
    LocalFireDepartment as FireIcon,
    CheckCircleOutline as CheckIcon,
} from '@mui/icons-material';
import { organiserApi } from '../../api';
import { LoadingSpinner } from '../../components/common';
import {
    PageHeader,
    SectionCard,
    FormDialog,
    LoadingButton,
    StatusChip,
    EmptyState,
} from '../../components/ui';
import { tokens } from '../../theme';
import { toast } from 'react-toastify';

const PACKAGE_META = {
    BASIC: {
        icon: <BoltIcon />,
        accent: tokens.palette.neutral[500],
        accentBg: tokens.palette.neutral[100],
    },
    STANDARD: {
        icon: <StarIcon />,
        accent: tokens.palette.info[600],
        accentBg: tokens.palette.info[50],
    },
    PREMIUM: {
        icon: <RocketIcon />,
        accent: tokens.palette.warning[600],
        accentBg: tokens.palette.warning[50],
    },
    VIP: {
        icon: <DiamondIcon />,
        accent: tokens.palette.secondary[600],
        accentBg: tokens.palette.secondary[50],
    },
};

const PackageCard = ({ pkg, selected, onSelect, discountPercent, upgradeInfo, currentPackage }) => {
    const meta = PACKAGE_META[pkg.packageType] || PACKAGE_META.BASIC;
    const accent = meta.accent;
    const isCurrentPackage = currentPackage === pkg.packageType;
    const isExtend = upgradeInfo?.action === 'EXTEND' && isCurrentPackage;
    const isUpgrade = upgradeInfo?.action === 'UPGRADE' && selected;
    const isDowngrade = upgradeInfo?.action === 'DOWNGRADE' && selected;
    const isFeatured = pkg.packageType === 'PREMIUM';

    return (
        <Box
            onClick={onSelect}
            sx={{
                height: '100%',
                position: 'relative',
                cursor: 'pointer',
                borderRadius: `${tokens.radius.lg}px`,
                border: '2px solid',
                borderColor: selected
                    ? accent
                    : isCurrentPackage
                        ? tokens.borders.default
                        : tokens.borders.subtle,
                borderStyle: isCurrentPackage && !selected ? 'dashed' : 'solid',
                bgcolor: tokens.surfaces.card,
                p: 2.5,
                transition: tokens.motion.base,
                boxShadow: selected ? tokens.shadow.md : tokens.shadow.xs,
                '&:hover': {
                    transform: 'translateY(-3px)',
                    boxShadow: tokens.shadow.lg,
                    borderColor: accent,
                },
            }}
        >
            {isFeatured && !isCurrentPackage && (
                <Chip
                    icon={<FireIcon sx={{ fontSize: 14 }} />}
                    label="FEATURED"
                    size="small"
                    sx={{
                        position: 'absolute',
                        top: -10,
                        left: 16,
                        bgcolor: tokens.palette.warning[500],
                        color: '#fff',
                        fontWeight: 700,
                        fontSize: '0.6875rem',
                        height: 22,
                        '& .MuiChip-icon': { color: '#fff' },
                    }}
                />
            )}
            {isCurrentPackage && (
                <StatusChip
                    label="Current"
                    status="primary"
                    sx={{ position: 'absolute', top: 12, right: 12 }}
                />
            )}
            <Stack direction="row" spacing={1.5} alignItems="center" sx={{ mb: 2 }}>
                <Box
                    sx={{
                        width: 44,
                        height: 44,
                        borderRadius: `${tokens.radius.md}px`,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        bgcolor: meta.accentBg,
                        color: accent,
                    }}
                >
                    {meta.icon}
                </Box>
                <Box sx={{ minWidth: 0 }}>
                    <Typography variant="h4" sx={{ fontWeight: 700, color: tokens.text.strong }}>
                        {pkg.displayName}
                    </Typography>
                    {pkg.badge && (
                        <Chip
                            label={pkg.badge}
                            size="small"
                            sx={{
                                bgcolor: accent,
                                color: '#fff',
                                height: 18,
                                fontSize: '0.6875rem',
                                fontWeight: 600,
                                mt: 0.5,
                            }}
                        />
                    )}
                </Box>
            </Stack>

            <Box sx={{ mb: 1.5 }}>
                {discountPercent > 0 && (
                    <Typography
                        variant="caption"
                        sx={{
                            textDecoration: 'line-through',
                            color: tokens.text.muted,
                            display: 'block',
                        }}
                    >
                        {pkg.originalPriceFormatted || pkg.priceFormatted}
                    </Typography>
                )}
                <Stack direction="row" alignItems="baseline" spacing={1}>
                    <Typography
                        sx={{
                            fontSize: '1.75rem',
                            fontWeight: 800,
                            color: accent,
                            lineHeight: 1.1,
                        }}
                    >
                        {pkg.priceFormatted}
                    </Typography>
                    {discountPercent > 0 && (
                        <Chip
                            label={`-${discountPercent}%`}
                            size="small"
                            sx={{
                                height: 18,
                                fontSize: '0.6875rem',
                                bgcolor: tokens.palette.success[50],
                                color: tokens.palette.success[700],
                                fontWeight: 700,
                            }}
                        />
                    )}
                </Stack>
            </Box>

            <Typography variant="caption" sx={{ color: tokens.text.muted, display: 'block', mb: 1.5 }}>
                {pkg.durationDays} days duration
            </Typography>
            <Divider sx={{ mb: 1.5 }} />
            <Typography variant="body2" sx={{ color: tokens.text.secondary, minHeight: 40 }}>
                {pkg.description}
            </Typography>

            {selected && (
                <Box sx={{ mt: 2, display: 'flex', justifyContent: 'center' }}>
                    {isExtend ? (
                        <StatusChip icon={<ExtendIcon sx={{ fontSize: 16 }} />} label="Extend" status="info" />
                    ) : isUpgrade ? (
                        <StatusChip icon={<UpgradeIcon sx={{ fontSize: 16 }} />} label="Upgrade" status="warning" />
                    ) : isDowngrade ? (
                        <StatusChip icon={<UpgradeIcon sx={{ fontSize: 16 }} />} label="Change" status="neutral" />
                    ) : (
                        <StatusChip icon={<ActiveIcon sx={{ fontSize: 16 }} />} label="Selected" status="success" />
                    )}
                </Box>
            )}
        </Box>
    );
};

const OrganiserBoost = () => {
    const [loading, setLoading] = useState(true);
    const [packages, setPackages] = useState([]);
    const [boosts, setBoosts] = useState([]);
    const [events, setEvents] = useState([]);
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(10);
    const [totalElements, setTotalElements] = useState(0);
    const [discountPercent, setDiscountPercent] = useState(0);

    const [openDialog, setOpenDialog] = useState(false);
    const [selectedPackage, setSelectedPackage] = useState(null);
    const [selectedEvent, setSelectedEvent] = useState('');
    const [submitting, setSubmitting] = useState(false);

    const [upgradeInfo, setUpgradeInfo] = useState(null);
    const [checkingUpgrade, setCheckingUpgrade] = useState(false);

    useEffect(() => {
        loadData();

        const params = new URLSearchParams(window.location.search);
        const handlePaymentCallback = async () => {
            if (params.get('success') === 'true') {
                const boostId = params.get('boost');
                const action = params.get('action');
                const existingBoostId = params.get('existingBoostId');
                if (boostId) {
                    try {
                        await organiserApi.confirmBoostPayment(boostId, action, existingBoostId);
                        const actionMessage = action === 'EXTEND'
                            ? 'Boost extended successfully!'
                            : action === 'UPGRADE' || action === 'DOWNGRADE'
                            ? 'Boost upgraded successfully!'
                            : 'Payment successful! Your boost is now active.';
                        toast.success(actionMessage);
                        await loadData();
                    } catch (error) {
                        console.error('Error confirming boost payment:', error);
                        toast.error('Payment successful but failed to activate boost. Please contact support.');
                    }
                }
                window.history.replaceState({}, document.title, window.location.pathname);
            } else if (params.get('canceled') === 'true') {
                toast.info('Payment was canceled. You can try again or delete the pending boost.');
                window.history.replaceState({}, document.title, window.location.pathname);
            }
        };

        handlePaymentCallback();
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [page, rowsPerPage]);

    useEffect(() => {
        const checkUpgrade = async () => {
            if (!selectedEvent || !selectedPackage) {
                setUpgradeInfo(null);
                return;
            }

            try {
                setCheckingUpgrade(true);
                const response = await organiserApi.checkBoostUpgrade(selectedEvent, selectedPackage.packageType);
                setUpgradeInfo(response.data?.data || null);
            } catch (error) {
                console.error('Error checking upgrade:', error);
                setUpgradeInfo(null);
            } finally {
                setCheckingUpgrade(false);
            }
        };

        checkUpgrade();
    }, [selectedEvent, selectedPackage]);

    const loadData = async () => {
        try {
            setLoading(true);
            const [packagesRes, boostsRes, eventsRes, discountRes] = await Promise.all([
                organiserApi.getBoostPackages(),
                organiserApi.getMyBoosts({ page, size: rowsPerPage }),
                organiserApi.getMyEvents({ size: 1000 }),
                organiserApi.getBoostDiscount().catch(() => ({ data: { data: 0 } })),
            ]);
            setPackages(packagesRes.data?.data || []);
            setBoosts(boostsRes.data?.data?.content || []);
            setTotalElements(boostsRes.data?.data?.totalElements || 0);
            setEvents(eventsRes.data?.data?.content || []);
            setDiscountPercent(discountRes.data?.data || 0);
        } catch (error) {
            toast.error('Failed to load data');
        } finally {
            setLoading(false);
        }
    };

    const handleCreateBoost = async () => {
        if (!selectedEvent || !selectedPackage) {
            toast.error('Please select an event and a boost package');
            return;
        }

        try {
            setSubmitting(true);
            const response = await organiserApi.createBoostCheckout({
                eventId: selectedEvent,
                boostPackage: selectedPackage.packageType,
            });
            const checkoutUrl = response.data.data.checkoutUrl;

            window.location.href = checkoutUrl;
        } catch (error) {
            toast.error(error.response?.data?.message || 'Failed to create checkout session');
            setSubmitting(false);
        }
    };

    const handleCloseDialog = () => {
        setOpenDialog(false);
        setSelectedEvent('');
        setSelectedPackage(null);
        setUpgradeInfo(null);
    };

    const getStatusChip = (status) => {
        const config = {
            PENDING: { label: 'Pending Payment', status: 'warning' },
            ACTIVE: { label: 'Active', status: 'success' },
            EXPIRED: { label: 'Expired', status: 'neutral' },
            CANCELLED: { label: 'Cancelled', status: 'danger' },
        };
        const c = config[status] || { label: status, status: 'neutral' };
        return <StatusChip label={c.label} status={c.status} />;
    };

    const getPackageChip = (pkg) => {
        const meta = PACKAGE_META[pkg];
        if (!meta) return <Chip label={pkg} size="small" variant="outlined" />;
        return (
            <Chip
                label={pkg}
                size="small"
                variant="outlined"
                sx={{
                    borderColor: meta.accent,
                    color: meta.accent,
                    fontWeight: 600,
                    bgcolor: meta.accentBg,
                }}
            />
        );
    };

    const formatCurrency = (value) => {
        if (!value) return '$0.00';
        return `$${parseFloat(value).toFixed(2)}`;
    };

    const getButtonText = () => {
        if (submitting) return 'Processing...';
        if (!selectedPackage) return 'Select a Package';
        if (checkingUpgrade) return 'Checking...';

        const price = upgradeInfo?.price ?? selectedPackage?.price;
        const priceText = formatCurrency(price);

        if (upgradeInfo) {
            switch (upgradeInfo.action) {
                case 'EXTEND':
                    return `Extend Boost - ${priceText}`;
                case 'UPGRADE':
                    return `Upgrade to ${selectedPackage.displayName} - ${priceText}`;
                case 'DOWNGRADE':
                    return `Change to ${selectedPackage.displayName} - ${priceText}`;
                default:
                    return `Pay ${priceText}`;
            }
        }

        return `Pay ${selectedPackage?.priceFormatted || ''}`;
    };

    if (loading) {
        return <LoadingSpinner message="Loading..." />;
    }

    return (
        <Box>
            <PageHeader
                title="Event Boost"
                subtitle="Boost your events to increase visibility and registrations"
                icon={<RocketIcon />}
                actions={
                    <>
                        <Tooltip title="Refresh">
                            <IconButton
                                onClick={loadData}
                                sx={{
                                    border: `1px solid ${tokens.borders.subtle}`,
                                    borderRadius: `${tokens.radius.md}px`,
                                }}
                            >
                                <RefreshIcon />
                            </IconButton>
                        </Tooltip>
                        <Button
                            variant="contained"
                            startIcon={<AddIcon />}
                            onClick={() => setOpenDialog(true)}
                        >
                            New Boost
                        </Button>
                    </>
                }
            />

            {discountPercent > 0 && (
                <Alert severity="success" sx={{ mb: 2, borderRadius: `${tokens.radius.md}px` }}>
                    <Typography variant="body2">
                        <strong>Subscription Discount Active!</strong> You get{' '}
                        <strong>{discountPercent}% off</strong> on all boost packages with your current subscription plan.
                    </Typography>
                </Alert>
            )}

            <Alert severity="info" sx={{ mb: 3, borderRadius: `${tokens.radius.md}px` }}>
                <Typography variant="body2">
                    <strong>Event Boost</strong> helps your events appear in prominent positions, increasing views and registrations.
                    You can <strong>extend</strong> an existing boost with the same package, or <strong>upgrade</strong> to a higher tier.
                </Typography>
            </Alert>

            {/* Pricing plans grid */}
            <Typography variant="h2" sx={{ mb: 2, fontWeight: 700 }}>
                Choose a Boost Package
            </Typography>
            <Grid container spacing={2.5} sx={{ mb: 4 }}>
                {packages.map((pkg) => {
                    const meta = PACKAGE_META[pkg.packageType] || PACKAGE_META.BASIC;
                    const isFeatured = pkg.packageType === 'PREMIUM';
                    return (
                        <Grid item xs={12} sm={6} md={3} key={pkg.packageType}>
                            <SectionCard
                                sx={{
                                    height: '100%',
                                    position: 'relative',
                                    border: '1px solid',
                                    borderColor: isFeatured ? meta.accent : tokens.borders.subtle,
                                    boxShadow: isFeatured ? tokens.shadow.md : tokens.shadow.xs,
                                    transition: tokens.motion.base,
                                    '&:hover': {
                                        transform: 'translateY(-3px)',
                                        boxShadow: tokens.shadow.lg,
                                    },
                                }}
                                contentSx={{ display: 'flex', flexDirection: 'column', height: '100%' }}
                            >
                                {isFeatured && (
                                    <Chip
                                        icon={<FireIcon sx={{ fontSize: 14 }} />}
                                        label="FEATURED"
                                        size="small"
                                        sx={{
                                            position: 'absolute',
                                            top: 12,
                                            right: 12,
                                            bgcolor: tokens.palette.warning[500],
                                            color: '#fff',
                                            fontWeight: 700,
                                            fontSize: '0.6875rem',
                                            height: 22,
                                            '& .MuiChip-icon': { color: '#fff' },
                                        }}
                                    />
                                )}
                                <Stack direction="row" spacing={1.5} alignItems="center" sx={{ mb: 2 }}>
                                    <Box
                                        sx={{
                                            width: 48,
                                            height: 48,
                                            borderRadius: `${tokens.radius.md}px`,
                                            display: 'flex',
                                            alignItems: 'center',
                                            justifyContent: 'center',
                                            bgcolor: meta.accentBg,
                                            color: meta.accent,
                                        }}
                                    >
                                        {meta.icon}
                                    </Box>
                                    <Typography variant="h3" sx={{ fontWeight: 700 }}>
                                        {pkg.displayName}
                                    </Typography>
                                </Stack>
                                <Box sx={{ mb: 2 }}>
                                    {discountPercent > 0 && (
                                        <Typography
                                            variant="caption"
                                            sx={{ textDecoration: 'line-through', color: tokens.text.muted, display: 'block' }}
                                        >
                                            {pkg.originalPriceFormatted || pkg.priceFormatted}
                                        </Typography>
                                    )}
                                    <Stack direction="row" alignItems="baseline" spacing={1}>
                                        <Typography sx={{ fontSize: '2rem', fontWeight: 800, color: meta.accent, lineHeight: 1 }}>
                                            {pkg.priceFormatted}
                                        </Typography>
                                        <Typography variant="caption" color="text.secondary">
                                            / {pkg.durationDays}d
                                        </Typography>
                                    </Stack>
                                    {discountPercent > 0 && (
                                        <Chip
                                            label={`${discountPercent}% OFF`}
                                            size="small"
                                            sx={{
                                                mt: 0.5,
                                                bgcolor: tokens.palette.success[50],
                                                color: tokens.palette.success[700],
                                                fontWeight: 700,
                                                height: 20,
                                                fontSize: '0.6875rem',
                                            }}
                                        />
                                    )}
                                </Box>
                                <Divider sx={{ mb: 2 }} />
                                <Typography variant="body2" sx={{ color: tokens.text.secondary, mb: 2, flexGrow: 1 }}>
                                    {pkg.description}
                                </Typography>
                                <Stack spacing={0.75} sx={{ mb: 2.5 }}>
                                    <Stack direction="row" spacing={1} alignItems="center">
                                        <CheckIcon sx={{ fontSize: 16, color: tokens.palette.success[600] }} />
                                        <Typography variant="caption" color="text.secondary">
                                            {pkg.durationDays} days active boost
                                        </Typography>
                                    </Stack>
                                    {pkg.badge && (
                                        <Stack direction="row" spacing={1} alignItems="center">
                                            <CheckIcon sx={{ fontSize: 16, color: tokens.palette.success[600] }} />
                                            <Typography variant="caption" color="text.secondary">
                                                {pkg.badge}
                                            </Typography>
                                        </Stack>
                                    )}
                                </Stack>
                                <LoadingButton
                                    fullWidth
                                    variant={isFeatured ? 'contained' : 'outlined'}
                                    onClick={() => {
                                        setSelectedPackage(pkg);
                                        setOpenDialog(true);
                                    }}
                                    sx={
                                        isFeatured
                                            ? {}
                                            : {
                                                  borderColor: meta.accent,
                                                  color: meta.accent,
                                                  '&:hover': {
                                                      borderColor: meta.accent,
                                                      bgcolor: meta.accentBg,
                                                  },
                                              }
                                    }
                                >
                                    Boost Now
                                </LoadingButton>
                            </SectionCard>
                        </Grid>
                    );
                })}
            </Grid>

            <SectionCard
                title="Boost History"
                subtitle={`${totalElements} boost${totalElements === 1 ? '' : 's'} total`}
                contentSx={{ p: 0, pt: 0 }}
            >
                {boosts.length === 0 ? (
                    <EmptyState
                        icon={<RocketIcon sx={{ fontSize: 32 }} />}
                        title="No boosts yet"
                        description="Create your first boost to start promoting your events"
                        action={
                            <Button
                                variant="contained"
                                startIcon={<AddIcon />}
                                onClick={() => setOpenDialog(true)}
                            >
                                Create Boost
                            </Button>
                        }
                    />
                ) : (
                    <>
                        <TableContainer>
                            <Table>
                                <TableHead>
                                    <TableRow sx={{ bgcolor: tokens.surfaces.sunken }}>
                                        <TableCell sx={{ fontWeight: 600 }}>Event</TableCell>
                                        <TableCell sx={{ fontWeight: 600 }}>Package</TableCell>
                                        <TableCell sx={{ fontWeight: 600 }}>Amount</TableCell>
                                        <TableCell sx={{ fontWeight: 600 }}>Status</TableCell>
                                        <TableCell sx={{ fontWeight: 600 }}>Duration</TableCell>
                                        <TableCell sx={{ fontWeight: 600 }}>Remaining</TableCell>
                                        <TableCell sx={{ fontWeight: 600 }}>Performance</TableCell>
                                        <TableCell sx={{ fontWeight: 600 }}>Actions</TableCell>
                                    </TableRow>
                                </TableHead>
                                <TableBody>
                                    {boosts.map((boost) => (
                                        <TableRow key={boost.id} hover>
                                            <TableCell>
                                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                                    <Avatar
                                                        src={boost.eventImageUrl}
                                                        variant="rounded"
                                                        sx={{ width: 40, height: 40 }}
                                                    />
                                                    <Typography variant="body2" fontWeight="medium" noWrap sx={{ maxWidth: 180 }}>
                                                        {boost.eventTitle}
                                                    </Typography>
                                                </Box>
                                            </TableCell>
                                            <TableCell>{getPackageChip(boost.boostPackage)}</TableCell>
                                            <TableCell>
                                                <Typography variant="body2" fontWeight={600}>
                                                    {formatCurrency(boost.amount)}
                                                </Typography>
                                            </TableCell>
                                            <TableCell>{getStatusChip(boost.status)}</TableCell>
                                            <TableCell>
                                                <Typography variant="caption" color="text.secondary">
                                                    {boost.startTime ? new Date(boost.startTime).toLocaleDateString('en-US') : '-'}
                                                    {' - '}
                                                    {boost.endTime ? new Date(boost.endTime).toLocaleDateString('en-US') : '-'}
                                                </Typography>
                                            </TableCell>
                                            <TableCell>
                                                {boost.status === 'ACTIVE' && boost.daysRemaining !== undefined ? (
                                                    <StatusChip
                                                        label={`${boost.daysRemaining} ${boost.daysRemaining === 1 ? 'day' : 'days'}`}
                                                        status="success"
                                                    />
                                                ) : '-'}
                                            </TableCell>
                                            <TableCell>
                                                <Typography variant="caption" display="block">
                                                    +{boost.viewsDuringBoost || 0} views
                                                </Typography>
                                                <Typography variant="caption" display="block" color="success.main">
                                                    +{boost.registrationsDuringBoost || 0} regs
                                                </Typography>
                                            </TableCell>
                                            <TableCell>
                                                {boost.status === 'ACTIVE' && (
                                                    <Tooltip title="Extend or Upgrade">
                                                        <Button
                                                            size="small"
                                                            variant="outlined"
                                                            onClick={() => {
                                                                setSelectedEvent(boost.eventId);
                                                                setOpenDialog(true);
                                                            }}
                                                        >
                                                            Manage
                                                        </Button>
                                                    </Tooltip>
                                                )}
                                            </TableCell>
                                        </TableRow>
                                    ))}
                                </TableBody>
                            </Table>
                        </TableContainer>
                        <TablePagination
                            component="div"
                            count={totalElements}
                            page={page}
                            onPageChange={(e, p) => setPage(p)}
                            rowsPerPage={rowsPerPage}
                            onRowsPerPageChange={(e) => { setRowsPerPage(parseInt(e.target.value)); setPage(0); }}
                            rowsPerPageOptions={[5, 10, 25]}
                            labelRowsPerPage="Rows per page:"
                        />
                    </>
                )}
            </SectionCard>

            <FormDialog
                open={openDialog}
                onClose={handleCloseDialog}
                maxWidth="md"
                icon={<RocketIcon />}
                title={upgradeInfo?.hasExistingBoost ? 'Extend or Upgrade Boost' : 'Create New Boost'}
                subtitle="Select an event and boost package to get started"
                actions={
                    <>
                        <Button onClick={handleCloseDialog} color="inherit">
                            Cancel
                        </Button>
                        <LoadingButton
                            variant="contained"
                            onClick={handleCreateBoost}
                            loading={submitting}
                            disabled={!selectedEvent || !selectedPackage || checkingUpgrade}
                            startIcon={checkingUpgrade ? <CircularProgress size={16} /> : null}
                        >
                            {getButtonText()}
                        </LoadingButton>
                    </>
                }
            >
                <Autocomplete
                    fullWidth
                    options={events}
                    getOptionLabel={(option) => option.title || ''}
                    value={events.find(e => e.id === selectedEvent) || null}
                    onChange={(e, newValue) => {
                        setSelectedEvent(newValue?.id || '');
                        setSelectedPackage(null);
                        setUpgradeInfo(null);
                    }}
                    renderInput={(params) => (
                        <TextField
                            {...params}
                            label="Search and Select Event"
                            placeholder="Type to search..."
                        />
                    )}
                    renderOption={(props, option) => (
                        <Box component="li" {...props} key={option.id} sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                            <Avatar src={option.imageUrl} variant="rounded" sx={{ width: 32, height: 32 }} />
                            <Box>
                                <Typography variant="body2" fontWeight="medium">{option.title}</Typography>
                                <Typography variant="caption" color="text.secondary">
                                    {option.status} • {option.startTime ? new Date(option.startTime).toLocaleDateString() : ''}
                                </Typography>
                            </Box>
                        </Box>
                    )}
                    sx={{ mb: 3 }}
                    noOptionsText="No events found"
                />

                {upgradeInfo?.hasExistingBoost && (
                    <Alert
                        severity={upgradeInfo.action === 'EXTEND' ? 'info' : 'warning'}
                        sx={{ mb: 3, borderRadius: `${tokens.radius.md}px` }}
                        icon={upgradeInfo.action === 'EXTEND' ? <ExtendIcon /> : <UpgradeIcon />}
                    >
                        <Typography variant="body2">
                            <strong>This event has an active {upgradeInfo.currentPackage} boost</strong>
                            <br />
                            Remaining: {upgradeInfo.remainingDays} days (ends {new Date(upgradeInfo.currentEndTime).toLocaleDateString()})
                        </Typography>
                        {upgradeInfo.message && (
                            <Typography variant="body2" sx={{ mt: 1 }}>
                                {upgradeInfo.message}
                            </Typography>
                        )}
                    </Alert>
                )}

                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                    <Typography variant="h4" sx={{ fontWeight: 700 }}>
                        Select Boost Package
                    </Typography>
                    {discountPercent > 0 && (
                        <Chip
                            label={`${discountPercent}% Subscription Discount`}
                            size="small"
                            sx={{
                                bgcolor: tokens.palette.success[50],
                                color: tokens.palette.success[700],
                                fontWeight: 600,
                            }}
                        />
                    )}
                </Box>
                <Grid container spacing={2}>
                    {packages.map((pkg) => (
                        <Grid item xs={12} sm={6} md={3} key={pkg.packageType}>
                            <PackageCard
                                pkg={pkg}
                                selected={selectedPackage?.packageType === pkg.packageType}
                                onSelect={() => setSelectedPackage(pkg)}
                                discountPercent={discountPercent}
                                upgradeInfo={upgradeInfo}
                                currentPackage={upgradeInfo?.currentPackage}
                            />
                        </Grid>
                    ))}
                </Grid>

                {upgradeInfo && selectedPackage && (
                    <Box
                        sx={{
                            mt: 3,
                            p: 2.5,
                            borderRadius: `${tokens.radius.md}px`,
                            bgcolor: tokens.surfaces.sunken,
                            border: `1px solid ${tokens.borders.subtle}`,
                        }}
                    >
                        <Typography variant="h5" sx={{ mb: 1, fontWeight: 700 }}>
                            Price Summary
                        </Typography>
                        <Divider sx={{ mb: 1.5 }} />
                        {upgradeInfo.action === 'EXTEND' && (
                            <>
                                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 0.5 }}>
                                    <Typography variant="body2">Extend {selectedPackage.displayName} ({selectedPackage.durationDays} days)</Typography>
                                    <Typography variant="body2" fontWeight={600}>{formatCurrency(upgradeInfo.price)}</Typography>
                                </Box>
                                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 0.5 }}>
                                    <Typography variant="body2" color="text.secondary">New end date</Typography>
                                    <Typography variant="body2" color="text.secondary">
                                        {new Date(upgradeInfo.newEndTime).toLocaleDateString()}
                                    </Typography>
                                </Box>
                            </>
                        )}
                        {(upgradeInfo.action === 'UPGRADE' || upgradeInfo.action === 'DOWNGRADE') && (
                            <>
                                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 0.5 }}>
                                    <Typography variant="body2">{selectedPackage.displayName} package</Typography>
                                    <Typography variant="body2">{formatCurrency(upgradeInfo.originalPrice)}</Typography>
                                </Box>
                                {upgradeInfo.refundAmount > 0 && (
                                    <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 0.5 }}>
                                        <Typography variant="body2" color="success.main">
                                            Prorated credit ({upgradeInfo.remainingDays} days remaining)
                                        </Typography>
                                        <Typography variant="body2" color="success.main">
                                            -{formatCurrency(upgradeInfo.refundAmount)}
                                        </Typography>
                                    </Box>
                                )}
                                <Divider sx={{ my: 1 }} />
                                <Box sx={{ display: 'flex', justifyContent: 'space-between' }}>
                                    <Typography variant="body2" fontWeight={700}>Total to pay</Typography>
                                    <Typography variant="body2" fontWeight={700} color="primary">
                                        {formatCurrency(upgradeInfo.price)}
                                    </Typography>
                                </Box>
                            </>
                        )}
                    </Box>
                )}
            </FormDialog>
        </Box>
    );
};

export default OrganiserBoost;

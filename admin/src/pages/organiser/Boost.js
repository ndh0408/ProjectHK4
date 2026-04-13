import React, { useState, useEffect } from 'react';
import {
    Box,
    Paper,
    Typography,
    Card,
    CardContent,
    Grid,
    Button,
    IconButton,
    Tooltip,
    Chip,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
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
} from '@mui/icons-material';
import { organiserApi } from '../../api';
import { LoadingSpinner } from '../../components/common';
import { toast } from 'react-toastify';

const PackageCard = ({ pkg, selected, onSelect, discountPercent, upgradeInfo, currentPackage }) => {
    const getIcon = (type) => {
        switch (type) {
            case 'BASIC': return <BoltIcon />;
            case 'STANDARD': return <StarIcon />;
            case 'PREMIUM': return <RocketIcon />;
            case 'VIP': return <DiamondIcon />;
            default: return <BoltIcon />;
        }
    };

    const getColor = (type) => {
        switch (type) {
            case 'BASIC': return '#64748b';
            case 'STANDARD': return '#3b82f6';
            case 'PREMIUM': return '#f59e0b';
            case 'VIP': return '#ef4444';
            default: return '#64748b';
        }
    };

    const color = getColor(pkg.packageType);
    const isCurrentPackage = currentPackage === pkg.packageType;
    const isExtend = upgradeInfo?.action === 'EXTEND' && isCurrentPackage;
    const isUpgrade = upgradeInfo?.action === 'UPGRADE' && selected;
    const isDowngrade = upgradeInfo?.action === 'DOWNGRADE' && selected;

    return (
        <Card
            sx={{
                cursor: 'pointer',
                border: selected ? `2px solid ${color}` : isCurrentPackage ? `2px dashed ${color}` : '2px solid transparent',
                transition: 'all 0.2s',
                '&:hover': { transform: 'translateY(-4px)', boxShadow: 4 },
                position: 'relative',
                opacity: isCurrentPackage && !selected ? 0.8 : 1,
            }}
            onClick={onSelect}
        >
            {isCurrentPackage && (
                <Chip
                    label="Current"
                    size="small"
                    color="primary"
                    sx={{ position: 'absolute', top: 8, right: 8 }}
                />
            )}
            <CardContent>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                    <Box sx={{ p: 1, borderRadius: 2, bgcolor: `${color}15`, color }}>
                        {getIcon(pkg.packageType)}
                    </Box>
                    <Box>
                        <Typography variant="h6" fontWeight="bold">{pkg.displayName}</Typography>
                        {pkg.badge && <Chip label={pkg.badge} size="small" sx={{ bgcolor: color, color: 'white' }} />}
                    </Box>
                </Box>
                <Box sx={{ mb: 1 }}>
                    {discountPercent > 0 && (
                        <Typography variant="body2" sx={{ textDecoration: 'line-through', color: 'text.secondary' }}>
                            {pkg.originalPriceFormatted || pkg.priceFormatted}
                        </Typography>
                    )}
                    <Typography variant="h5" fontWeight="bold" color={color}>
                        {pkg.priceFormatted}
                        {discountPercent > 0 && (
                            <Chip label={`-${discountPercent}%`} size="small" color="success" sx={{ ml: 1 }} />
                        )}
                    </Typography>
                </Box>
                <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                    {pkg.durationDays} days
                </Typography>
                <Typography variant="body2">{pkg.description}</Typography>
                {selected && (
                    <Box sx={{ mt: 2, display: 'flex', justifyContent: 'center' }}>
                        {isExtend ? (
                            <Chip icon={<ExtendIcon />} label="Extend" color="info" />
                        ) : isUpgrade ? (
                            <Chip icon={<UpgradeIcon />} label="Upgrade" color="warning" />
                        ) : isDowngrade ? (
                            <Chip icon={<UpgradeIcon />} label="Change" color="secondary" />
                        ) : (
                            <Chip icon={<ActiveIcon />} label="Selected" color="success" />
                        )}
                    </Box>
                )}
            </CardContent>
        </Card>
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
            PENDING: { label: 'Pending Payment', color: 'warning' },
            ACTIVE: { label: 'Active', color: 'success' },
            EXPIRED: { label: 'Expired', color: 'default' },
            CANCELLED: { label: 'Cancelled', color: 'error' },
        };
        const c = config[status] || { label: status, color: 'default' };
        return <Chip label={c.label} color={c.color} size="small" />;
    };

    const getPackageChip = (pkg) => {
        const config = {
            BASIC: { color: 'default' },
            STANDARD: { color: 'info' },
            PREMIUM: { color: 'warning' },
            VIP: { color: 'error' },
        };
        const c = config[pkg] || { color: 'default' };
        return <Chip label={pkg} color={c.color} size="small" variant="outlined" />;
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
        <Box className="dashboard">
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                <Box>
                    <Typography variant="h4" fontWeight="bold">Event Boost</Typography>
                    <Typography variant="body2" color="text.secondary">
                        Boost your events to increase visibility and registrations
                    </Typography>
                </Box>
                <Box sx={{ display: 'flex', gap: 1 }}>
                    <Tooltip title="Refresh">
                        <IconButton onClick={loadData} color="primary">
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
                </Box>
            </Box>

            {discountPercent > 0 && (
                <Alert severity="success" sx={{ mb: 3 }}>
                    <Typography variant="body2">
                        <strong>Subscription Discount Active!</strong> You get <strong>{discountPercent}% off</strong> on all boost packages with your current subscription plan.
                    </Typography>
                </Alert>
            )}

            <Alert severity="info" sx={{ mb: 3 }}>
                <Typography variant="body2">
                    <strong>Event Boost</strong> helps your events appear in prominent positions, increasing views and registrations.
                    You can <strong>extend</strong> an existing boost with the same package, or <strong>upgrade</strong> to a higher tier.
                </Typography>
            </Alert>

            <Paper sx={{ p: 2 }}>
                <Typography variant="h6" fontWeight="bold" sx={{ mb: 2 }}>
                    Boost History
                </Typography>
                <TableContainer>
                    <Table>
                        <TableHead>
                            <TableRow>
                                <TableCell>Event</TableCell>
                                <TableCell>Package</TableCell>
                                <TableCell>Amount</TableCell>
                                <TableCell>Status</TableCell>
                                <TableCell>Duration</TableCell>
                                <TableCell>Remaining</TableCell>
                                <TableCell>Performance</TableCell>
                                <TableCell>Actions</TableCell>
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
                                    <TableCell>{formatCurrency(boost.amount)}</TableCell>
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
                                            <Chip
                                                label={`${boost.daysRemaining} ${boost.daysRemaining === 1 ? 'day' : 'days'}`}
                                                size="small"
                                                color="success"
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
                                            <Box sx={{ display: 'flex', gap: 0.5 }}>
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
                                            </Box>
                                        )}
                                    </TableCell>
                                </TableRow>
                            ))}
                            {boosts.length === 0 && (
                                <TableRow>
                                    <TableCell colSpan={8} align="center" sx={{ py: 4 }}>
                                        <Typography color="text.secondary">
                                            No boosts yet. Create your first boost!
                                        </Typography>
                                    </TableCell>
                                </TableRow>
                            )}
                        </TableBody>
                    </Table>
                </TableContainer>
                {boosts.length > 0 && (
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
                )}
            </Paper>

            <Dialog open={openDialog} onClose={handleCloseDialog} maxWidth="md" fullWidth>
                <DialogTitle sx={{ fontWeight: 'bold' }}>
                    {upgradeInfo?.hasExistingBoost ? 'Extend or Upgrade Boost' : 'Create New Boost'}
                </DialogTitle>
                <DialogContent>
                    <Box sx={{ mt: 2 }}>
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
                                sx={{ mb: 3 }}
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

                        <Typography variant="subtitle1" fontWeight="bold" sx={{ mb: 2 }}>
                            Select Boost Package
                            {discountPercent > 0 && (
                                <Chip label={`${discountPercent}% Subscription Discount`} size="small" color="success" sx={{ ml: 1 }} />
                            )}
                        </Typography>
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
                            <Paper sx={{ mt: 3, p: 2, bgcolor: 'grey.50' }}>
                                <Typography variant="subtitle2" fontWeight="bold" sx={{ mb: 1 }}>
                                    Price Summary
                                </Typography>
                                <Divider sx={{ mb: 1 }} />
                                {upgradeInfo.action === 'EXTEND' && (
                                    <>
                                        <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 0.5 }}>
                                            <Typography variant="body2">Extend {selectedPackage.displayName} ({selectedPackage.durationDays} days)</Typography>
                                            <Typography variant="body2">{formatCurrency(upgradeInfo.price)}</Typography>
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
                                            <Typography variant="body2" fontWeight="bold">Total to pay</Typography>
                                            <Typography variant="body2" fontWeight="bold" color="primary">
                                                {formatCurrency(upgradeInfo.price)}
                                            </Typography>
                                        </Box>
                                    </>
                                )}
                            </Paper>
                        )}
                    </Box>
                </DialogContent>
                <DialogActions sx={{ p: 2 }}>
                    <Button onClick={handleCloseDialog} color="inherit">
                        Cancel
                    </Button>
                    <Button
                        variant="contained"
                        onClick={handleCreateBoost}
                        disabled={submitting || !selectedEvent || !selectedPackage || checkingUpgrade}
                        startIcon={checkingUpgrade ? <CircularProgress size={16} /> : null}
                    >
                        {getButtonText()}
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default OrganiserBoost;

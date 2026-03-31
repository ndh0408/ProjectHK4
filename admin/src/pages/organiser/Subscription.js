import React, { useState, useEffect } from 'react';
import {
    Box,
    Card,
    CardContent,
    Typography,
    Grid,
    Button,
    Chip,
    LinearProgress,
    Alert,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    CircularProgress,
    Divider,
    List,
    ListItem,
    ListItemIcon,
    ListItemText,
} from '@mui/material';
import {
    Star as StarIcon,
    Rocket as RocketIcon,
    WorkspacePremium as PremiumIcon,
    Diamond as DiamondIcon,
    Event as EventIcon,
    TrendingUp as BoostIcon,
    Warning as WarningIcon,
} from '@mui/icons-material';
import { organiserApi } from '../../api';
import { toast } from 'react-toastify';

const planIcons = {
    FREE: <StarIcon />,
    STANDARD: <RocketIcon />,
    PREMIUM: <PremiumIcon />,
    VIP: <DiamondIcon />,
};

const planColors = {
    FREE: '#9e9e9e',
    STANDARD: '#2196f3',
    PREMIUM: '#9c27b0',
    VIP: '#ff9800',
};

const Subscription = () => {
    const [loading, setLoading] = useState(true);
    const [subscription, setSubscription] = useState(null);
    const [plans, setPlans] = useState([]);
    const [error, setError] = useState(null);
    const [upgradeDialog, setUpgradeDialog] = useState({ open: false, plan: null });
    const [cancelDialog, setCancelDialog] = useState(false);
    const [processing, setProcessing] = useState(false);

    useEffect(() => {
        const params = new URLSearchParams(window.location.search);
        if (params.get('success') === 'true') {
            const plan = params.get('plan');
            confirmPayment(plan);
        } else if (params.get('canceled') === 'true') {
            toast.info('Payment was canceled. Your subscription was not changed.');
            window.history.replaceState({}, document.title, window.location.pathname);
            fetchData();
        } else {
            fetchData();
        }
    }, []);

    const confirmPayment = async (plan) => {
        try {
            setLoading(true);
            await organiserApi.confirmSubscriptionPayment(plan);
            toast.success(`Successfully upgraded to ${plan} plan!`);
            window.history.replaceState({}, document.title, window.location.pathname);
            await fetchData();
        } catch (err) {
            const errorMsg = err.response?.data?.message || 'Failed to confirm payment';
            setError(errorMsg);
            toast.error(errorMsg);
            console.error('Confirm payment error:', err);
            window.history.replaceState({}, document.title, window.location.pathname);
            setLoading(false);
        }
    };

    const fetchData = async () => {
        try {
            setLoading(true);
            const [subscriptionRes, plansRes] = await Promise.all([
                organiserApi.getMySubscription(),
                organiserApi.getSubscriptionPlans(),
            ]);
            setSubscription(subscriptionRes.data.data);
            setPlans(plansRes.data.data);
        } catch (err) {
            setError('Failed to load subscription data');
            console.error(err);
        } finally {
            setLoading(false);
        }
    };

    const handleUpgrade = async () => {
        if (!upgradeDialog.plan) return;

        try {
            setProcessing(true);

            if (upgradeDialog.plan === 'FREE') {
                await organiserApi.cancelSubscription();
                toast.success('Successfully downgraded to FREE plan!');
                setUpgradeDialog({ open: false, plan: null });
                await fetchData();
                return;
            }

            const response = await organiserApi.createSubscriptionCheckout(upgradeDialog.plan);
            const checkoutUrl = response.data.data.checkoutUrl;

            window.location.href = checkoutUrl;
        } catch (err) {
            const errorMsg = err.response?.data?.message || 'Failed to create checkout session';
            setError(errorMsg);
            toast.error(errorMsg);
            console.error('Upgrade error:', err);
            setProcessing(false);
        }
    };

    const handleCancel = async () => {
        try {
            setProcessing(true);
            await organiserApi.cancelSubscription();
            setCancelDialog(false);
            await fetchData();
        } catch (err) {
            setError(err.response?.data?.message || 'Failed to cancel subscription');
        } finally {
            setProcessing(false);
        }
    };

    const getUsagePercentage = (used, max) => {
        if (max === -1) return 0;
        return Math.min((used / max) * 100, 100);
    };

    if (loading) {
        return (
            <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
                <CircularProgress />
            </Box>
        );
    }

    return (
        <Box sx={{ p: 3 }}>
            <Typography variant="h4" gutterBottom fontWeight="bold">
                Subscription Management
            </Typography>
            <Typography variant="body1" color="text.secondary" sx={{ mb: 4 }}>
                Manage your subscription plan and view your usage
            </Typography>

            {error && (
                <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError(null)}>
                    {error}
                </Alert>
            )}

            {subscription && subscription.remainingEvents !== -1 && subscription.remainingEvents <= 2 && subscription.remainingEvents > 0 && (
                <Alert severity="warning" sx={{ mb: 2 }}>
                    <Typography variant="body2">
                        <strong>Warning:</strong> You only have <strong>{subscription.remainingEvents}</strong> event{subscription.remainingEvents > 1 ? 's' : ''} remaining this month.
                        Consider upgrading to create more events.
                    </Typography>
                </Alert>
            )}
            {subscription && subscription.remainingEvents === 0 && (
                <Alert severity="error" sx={{ mb: 2 }}>
                    <Typography variant="body2">
                        <strong>Limit Reached:</strong> You have used all your event quota for this month.
                        Upgrade your plan to create more events.
                    </Typography>
                </Alert>
            )}

            {subscription && (
                <Card sx={{ mb: 4, border: `2px solid ${planColors[subscription.plan]}` }}>
                    <CardContent>
                        <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
                            <Box display="flex" alignItems="center" gap={2}>
                                <Box
                                    sx={{
                                        p: 1.5,
                                        borderRadius: 2,
                                        bgcolor: `${planColors[subscription.plan]}20`,
                                        color: planColors[subscription.plan],
                                    }}
                                >
                                    {planIcons[subscription.plan]}
                                </Box>
                                <Box>
                                    <Typography variant="h5" fontWeight="bold">
                                        {subscription.planDisplayName} Plan
                                    </Typography>
                                    <Chip
                                        label={subscription.active ? 'Active' : 'Inactive'}
                                        color={subscription.active ? 'success' : 'error'}
                                        size="small"
                                    />
                                </Box>
                            </Box>
                            {subscription.plan !== 'FREE' && (
                                <Button
                                    variant="outlined"
                                    color="error"
                                    onClick={() => setCancelDialog(true)}
                                >
                                    Cancel Subscription
                                </Button>
                            )}
                        </Box>

                        <Divider sx={{ my: 2 }} />

                        <Typography variant="h6" gutterBottom>
                            Monthly Usage
                        </Typography>
                        <Grid container spacing={3}>
                            <Grid item xs={12} md={6}>
                                <Box>
                                    <Box display="flex" justifyContent="space-between" mb={1}>
                                        <Box display="flex" alignItems="center" gap={1}>
                                            <EventIcon fontSize="small" color="primary" />
                                            <Typography variant="body2">Events Created</Typography>
                                        </Box>
                                        <Typography variant="body2" fontWeight="bold">
                                            {subscription.eventsCreatedThisMonth} / {subscription.maxEventsPerMonth === -1 ? '∞' : subscription.maxEventsPerMonth}
                                        </Typography>
                                    </Box>
                                    <LinearProgress
                                        variant="determinate"
                                        value={getUsagePercentage(subscription.eventsCreatedThisMonth, subscription.maxEventsPerMonth)}
                                        sx={{ height: 8, borderRadius: 4 }}
                                    />
                                    {subscription.remainingEvents !== -1 && (
                                        <Typography variant="caption" color="text.secondary">
                                            {subscription.remainingEvents} remaining
                                        </Typography>
                                    )}
                                </Box>
                            </Grid>

                            <Grid item xs={12} md={6}>
                                <Box>
                                    <Box display="flex" alignItems="center" gap={1} mb={1}>
                                        <BoostIcon fontSize="small" color="warning" />
                                        <Typography variant="body2">Boost Discount</Typography>
                                    </Box>
                                    <Typography variant="h4" color="warning.main" fontWeight="bold">
                                        {subscription.boostDiscountPercent}%
                                    </Typography>
                                    <Typography variant="caption" color="text.secondary">
                                        Applied to all boost packages
                                    </Typography>
                                </Box>
                            </Grid>
                        </Grid>
                    </CardContent>
                </Card>
            )}

            <Typography variant="h5" gutterBottom fontWeight="bold" sx={{ mt: 4 }}>
                Available Plans
            </Typography>
            <Grid container spacing={3}>
                {plans.map((plan) => (
                    <Grid item xs={12} sm={6} md={3} key={plan.name}>
                        <Card
                            sx={{
                                height: '100%',
                                border: subscription?.plan === plan.name ? `3px solid ${planColors[plan.name]}` : '1px solid #e0e0e0',
                                position: 'relative',
                                transition: 'transform 0.2s, box-shadow 0.2s',
                                '&:hover': {
                                    transform: 'translateY(-4px)',
                                    boxShadow: 4,
                                },
                            }}
                        >
                            {subscription?.plan === plan.name && (
                                <Chip
                                    label="Current Plan"
                                    color="primary"
                                    size="small"
                                    sx={{
                                        position: 'absolute',
                                        top: 10,
                                        right: 10,
                                    }}
                                />
                            )}
                            <CardContent>
                                <Box
                                    sx={{
                                        p: 2,
                                        borderRadius: 2,
                                        bgcolor: `${planColors[plan.name]}15`,
                                        color: planColors[plan.name],
                                        display: 'flex',
                                        justifyContent: 'center',
                                        mb: 2,
                                    }}
                                >
                                    {planIcons[plan.name]}
                                </Box>
                                <Typography variant="h6" align="center" fontWeight="bold">
                                    {plan.displayName}
                                </Typography>
                                <Typography variant="h4" align="center" fontWeight="bold" sx={{ my: 2 }}>
                                    ${plan.monthlyPrice}
                                    <Typography component="span" variant="body2" color="text.secondary">
                                        /month
                                    </Typography>
                                </Typography>

                                <List dense>
                                    <ListItem>
                                        <ListItemIcon sx={{ minWidth: 36 }}>
                                            <EventIcon fontSize="small" />
                                        </ListItemIcon>
                                        <ListItemText
                                            primary={plan.maxEventsPerMonth === 'Unlimited' ? 'Unlimited Events/month' : `${plan.maxEventsPerMonth} Events/month`}
                                        />
                                    </ListItem>
                                    <ListItem>
                                        <ListItemIcon sx={{ minWidth: 36 }}>
                                            <BoostIcon fontSize="small" color="warning" />
                                        </ListItemIcon>
                                        <ListItemText primary={`${plan.boostDiscountPercent}% Boost Discount`} />
                                    </ListItem>
                                </List>

                                <Box mt={2}>
                                    {subscription?.plan === plan.name ? (
                                        <Button fullWidth variant="outlined" disabled>
                                            Current Plan
                                        </Button>
                                    ) : (
                                        <Button
                                            fullWidth
                                            variant="contained"
                                            sx={{
                                                bgcolor: planColors[plan.name],
                                                '&:hover': {
                                                    bgcolor: planColors[plan.name],
                                                    filter: 'brightness(0.9)',
                                                },
                                            }}
                                            onClick={() => setUpgradeDialog({ open: true, plan: plan.name })}
                                        >
                                            {plan.name === 'FREE' ? 'Downgrade' : 'Upgrade'}
                                        </Button>
                                    )}
                                </Box>
                            </CardContent>
                        </Card>
                    </Grid>
                ))}
            </Grid>

            <Dialog open={upgradeDialog.open} onClose={() => setUpgradeDialog({ open: false, plan: null })}>
                <DialogTitle>
                    {upgradeDialog.plan === 'FREE'
                        ? 'Downgrade to Free Plan?'
                        : `Upgrade to ${plans.find(p => p.name === upgradeDialog.plan)?.displayName || upgradeDialog.plan || ''} Plan?`}
                </DialogTitle>
                <DialogContent>
                    <Typography>
                        {upgradeDialog.plan === 'FREE'
                            ? 'You will lose access to premium features. Are you sure you want to downgrade?'
                            : 'You will be charged for the new plan. Continue with the upgrade?'}
                    </Typography>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setUpgradeDialog({ open: false, plan: null })}>
                        Cancel
                    </Button>
                    <Button
                        variant="contained"
                        onClick={handleUpgrade}
                        disabled={processing}
                        color={upgradeDialog.plan === 'FREE' ? 'error' : 'primary'}
                    >
                        {processing ? <CircularProgress size={24} /> : 'Confirm'}
                    </Button>
                </DialogActions>
            </Dialog>

            <Dialog open={cancelDialog} onClose={() => setCancelDialog(false)}>
                <DialogTitle sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <WarningIcon color="warning" />
                    Cancel Subscription?
                </DialogTitle>
                <DialogContent>
                    <Typography>
                        Your subscription will be cancelled and you will be downgraded to the Free plan.
                        You will lose access to premium features immediately.
                    </Typography>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setCancelDialog(false)}>
                        Keep Subscription
                    </Button>
                    <Button
                        variant="contained"
                        color="error"
                        onClick={handleCancel}
                        disabled={processing}
                    >
                        {processing ? <CircularProgress size={24} /> : 'Cancel Subscription'}
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default Subscription;

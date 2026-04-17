import React, { useState, useEffect } from 'react';
import {
    Box,
    Typography,
    Grid,
    Button,
    LinearProgress,
    Alert,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    CircularProgress,
    Divider,
    Stack,
} from '@mui/material';
import {
    Star as StarIcon,
    Rocket as RocketIcon,
    WorkspacePremium as PremiumIcon,
    Diamond as DiamondIcon,
    Event as EventIcon,
    TrendingUp as BoostIcon,
    Warning as WarningIcon,
    CheckCircleOutline as CheckIcon,
    LocalFireDepartment as FireIcon,
} from '@mui/icons-material';
import { organiserApi } from '../../api';
import {
    PageHeader,
    SectionCard,
    StatusChip,
    LoadingButton,
} from '../../components/ui';
import { tokens } from '../../theme';
import { toast } from 'react-toastify';

const PLAN_META = {
    FREE: {
        icon: <StarIcon />,
        accent: tokens.palette.neutral[500],
        accentBg: tokens.palette.neutral[100],
    },
    STANDARD: {
        icon: <RocketIcon />,
        accent: tokens.palette.info[600],
        accentBg: tokens.palette.info[50],
    },
    PREMIUM: {
        icon: <PremiumIcon />,
        accent: tokens.palette.primary[600],
        accentBg: tokens.palette.primary[50],
    },
    VIP: {
        icon: <DiamondIcon />,
        accent: tokens.palette.warning[600],
        accentBg: tokens.palette.warning[50],
    },
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
        // eslint-disable-next-line react-hooks/exhaustive-deps
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

    const currentPlanMeta = subscription ? PLAN_META[subscription.plan] || PLAN_META.FREE : PLAN_META.FREE;

    return (
        <Box>
            <PageHeader
                title="Subscription Management"
                subtitle="Manage your subscription plan and view your usage"
                icon={<PremiumIcon />}
            />

            {error && (
                <Alert
                    severity="error"
                    sx={{ mb: 3, borderRadius: `${tokens.radius.md}px` }}
                    onClose={() => setError(null)}
                >
                    {error}
                </Alert>
            )}

            {subscription && subscription.remainingEvents !== -1 && subscription.remainingEvents <= 2 && subscription.remainingEvents > 0 && (
                <Alert severity="warning" sx={{ mb: 2, borderRadius: `${tokens.radius.md}px` }}>
                    <Typography variant="body2">
                        <strong>Warning:</strong> You only have <strong>{subscription.remainingEvents}</strong> event{subscription.remainingEvents > 1 ? 's' : ''} remaining this month.
                        Consider upgrading to create more events.
                    </Typography>
                </Alert>
            )}
            {subscription && subscription.remainingEvents === 0 && (
                <Alert severity="error" sx={{ mb: 2, borderRadius: `${tokens.radius.md}px` }}>
                    <Typography variant="body2">
                        <strong>Limit Reached:</strong> You have used all your event quota for this month.
                        Upgrade your plan to create more events.
                    </Typography>
                </Alert>
            )}

            {subscription && (
                <SectionCard
                    sx={{
                        mb: 4,
                        borderLeft: `4px solid ${currentPlanMeta.accent}`,
                    }}
                >
                    <Stack
                        direction={{ xs: 'column', sm: 'row' }}
                        justifyContent="space-between"
                        alignItems={{ xs: 'flex-start', sm: 'center' }}
                        spacing={2}
                        sx={{ mb: 3 }}
                    >
                        <Stack direction="row" alignItems="center" spacing={2}>
                            <Box
                                sx={{
                                    p: 1.5,
                                    borderRadius: `${tokens.radius.md}px`,
                                    bgcolor: currentPlanMeta.accentBg,
                                    color: currentPlanMeta.accent,
                                    display: 'flex',
                                }}
                            >
                                {currentPlanMeta.icon}
                            </Box>
                            <Box>
                                <Stack direction="row" alignItems="center" spacing={1}>
                                    <Typography variant="h2" sx={{ fontWeight: 700 }}>
                                        {subscription.planDisplayName} Plan
                                    </Typography>
                                    <StatusChip
                                        label={subscription.active ? 'Active' : 'Inactive'}
                                        status={subscription.active ? 'success' : 'danger'}
                                    />
                                </Stack>
                                <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
                                    Your current subscription tier
                                </Typography>
                            </Box>
                        </Stack>
                        {subscription.plan !== 'FREE' && (
                            <Button
                                variant="outlined"
                                color="error"
                                onClick={() => setCancelDialog(true)}
                            >
                                Cancel Subscription
                            </Button>
                        )}
                    </Stack>

                    <Divider sx={{ my: 2 }} />

                    <Typography variant="h4" sx={{ fontWeight: 700, mb: 2 }}>
                        Monthly Usage
                    </Typography>
                    <Grid container spacing={3}>
                        <Grid item xs={12} md={6}>
                            <Box
                                sx={{
                                    p: 2,
                                    borderRadius: `${tokens.radius.md}px`,
                                    bgcolor: tokens.surfaces.sunken,
                                    border: `1px solid ${tokens.borders.subtle}`,
                                }}
                            >
                                <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 1 }}>
                                    <Stack direction="row" alignItems="center" spacing={1}>
                                        <EventIcon fontSize="small" sx={{ color: tokens.palette.primary[600] }} />
                                        <Typography variant="body2" fontWeight={600}>Events Created</Typography>
                                    </Stack>
                                    <Typography variant="body2" fontWeight={700}>
                                        {subscription.eventsCreatedThisMonth} / {subscription.maxEventsPerMonth === -1 ? '\u221e' : subscription.maxEventsPerMonth}
                                    </Typography>
                                </Stack>
                                <LinearProgress
                                    variant="determinate"
                                    value={getUsagePercentage(subscription.eventsCreatedThisMonth, subscription.maxEventsPerMonth)}
                                    sx={{
                                        height: 8,
                                        borderRadius: `${tokens.radius.pill}px`,
                                        bgcolor: tokens.palette.neutral[200],
                                    }}
                                />
                                {subscription.remainingEvents !== -1 && (
                                    <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
                                        {subscription.remainingEvents} remaining this month
                                    </Typography>
                                )}
                            </Box>
                        </Grid>

                        <Grid item xs={12} md={6}>
                            <Box
                                sx={{
                                    p: 2,
                                    borderRadius: `${tokens.radius.md}px`,
                                    bgcolor: tokens.surfaces.sunken,
                                    border: `1px solid ${tokens.borders.subtle}`,
                                }}
                            >
                                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
                                    <BoostIcon fontSize="small" sx={{ color: tokens.palette.warning[600] }} />
                                    <Typography variant="body2" fontWeight={600}>Boost Discount</Typography>
                                </Stack>
                                <Typography sx={{ fontSize: '2rem', fontWeight: 800, color: tokens.palette.warning[600], lineHeight: 1 }}>
                                    {subscription.boostDiscountPercent}%
                                </Typography>
                                <Typography variant="caption" color="text.secondary" sx={{ mt: 0.5, display: 'block' }}>
                                    Applied to all boost packages
                                </Typography>
                            </Box>
                        </Grid>
                    </Grid>
                </SectionCard>
            )}

            <Typography variant="h2" sx={{ fontWeight: 700, mb: 0.5 }}>
                Available Plans
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
                Choose the plan that fits your needs
            </Typography>

            <Grid container spacing={2.5}>
                {plans.map((plan) => {
                    const meta = PLAN_META[plan.name] || PLAN_META.FREE;
                    const isCurrent = subscription?.plan === plan.name;
                    const isFeatured = plan.name === 'PREMIUM';
                    return (
                        <Grid item xs={12} sm={6} md={3} key={plan.name}>
                            <SectionCard
                                sx={{
                                    height: '100%',
                                    position: 'relative',
                                    border: '2px solid',
                                    borderColor: isCurrent
                                        ? meta.accent
                                        : isFeatured
                                            ? meta.accent
                                            : tokens.borders.subtle,
                                    boxShadow: isCurrent || isFeatured ? tokens.shadow.md : tokens.shadow.xs,
                                    transition: tokens.motion.base,
                                    '&:hover': {
                                        transform: 'translateY(-3px)',
                                        boxShadow: tokens.shadow.lg,
                                    },
                                }}
                                contentSx={{ display: 'flex', flexDirection: 'column', height: '100%' }}
                            >
                                {isFeatured && !isCurrent && (
                                    <Box
                                        sx={{
                                            position: 'absolute',
                                            top: -12,
                                            left: '50%',
                                            transform: 'translateX(-50%)',
                                            bgcolor: meta.accent,
                                            color: '#fff',
                                            px: 1.5,
                                            py: 0.25,
                                            borderRadius: `${tokens.radius.pill}px`,
                                            display: 'flex',
                                            alignItems: 'center',
                                            gap: 0.5,
                                            fontSize: '0.6875rem',
                                            fontWeight: 700,
                                            letterSpacing: '0.05em',
                                        }}
                                    >
                                        <FireIcon sx={{ fontSize: 14 }} />
                                        MOST POPULAR
                                    </Box>
                                )}
                                {isCurrent && (
                                    <StatusChip
                                        label="Current Plan"
                                        status="primary"
                                        sx={{ position: 'absolute', top: 12, right: 12 }}
                                    />
                                )}

                                <Box
                                    sx={{
                                        width: 56,
                                        height: 56,
                                        borderRadius: `${tokens.radius.lg}px`,
                                        bgcolor: meta.accentBg,
                                        color: meta.accent,
                                        display: 'flex',
                                        alignItems: 'center',
                                        justifyContent: 'center',
                                        mb: 2,
                                        mx: 'auto',
                                        '& svg': { fontSize: 28 },
                                    }}
                                >
                                    {meta.icon}
                                </Box>
                                <Typography variant="h3" align="center" sx={{ fontWeight: 700 }}>
                                    {plan.displayName}
                                </Typography>
                                <Box sx={{ my: 2, textAlign: 'center' }}>
                                    <Stack direction="row" alignItems="baseline" spacing={0.5} justifyContent="center">
                                        <Typography sx={{ fontSize: '2.5rem', fontWeight: 800, color: meta.accent, lineHeight: 1 }}>
                                            ${plan.monthlyPrice}
                                        </Typography>
                                        <Typography variant="body2" color="text.secondary">
                                            /month
                                        </Typography>
                                    </Stack>
                                </Box>

                                <Divider sx={{ mb: 2 }} />

                                <Stack spacing={1.25} sx={{ mb: 3, flexGrow: 1 }}>
                                    <Stack direction="row" spacing={1.25} alignItems="flex-start">
                                        <CheckIcon sx={{ fontSize: 18, color: tokens.palette.success[600], mt: 0.125 }} />
                                        <Typography variant="body2">
                                            {plan.maxEventsPerMonth === 'Unlimited' ? 'Unlimited Events/month' : `${plan.maxEventsPerMonth} Events/month`}
                                        </Typography>
                                    </Stack>
                                    <Stack direction="row" spacing={1.25} alignItems="flex-start">
                                        <CheckIcon sx={{ fontSize: 18, color: tokens.palette.success[600], mt: 0.125 }} />
                                        <Typography variant="body2">
                                            {plan.boostDiscountPercent}% Boost Discount
                                        </Typography>
                                    </Stack>
                                    <Stack direction="row" spacing={1.25} alignItems="flex-start">
                                        <CheckIcon sx={{ fontSize: 18, color: tokens.palette.success[600], mt: 0.125 }} />
                                        <Typography variant="body2" color="text.secondary">
                                            Standard analytics & support
                                        </Typography>
                                    </Stack>
                                </Stack>

                                {isCurrent ? (
                                    <Button fullWidth variant="outlined" disabled>
                                        Current Plan
                                    </Button>
                                ) : (
                                    <LoadingButton
                                        fullWidth
                                        variant={isFeatured ? 'contained' : 'outlined'}
                                        onClick={() => setUpgradeDialog({ open: true, plan: plan.name })}
                                        sx={
                                            isFeatured
                                                ? {
                                                      bgcolor: meta.accent,
                                                      '&:hover': {
                                                          bgcolor: meta.accent,
                                                          filter: 'brightness(0.92)',
                                                      },
                                                  }
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
                                        {plan.name === 'FREE' ? 'Downgrade' : 'Upgrade'}
                                    </LoadingButton>
                                )}
                            </SectionCard>
                        </Grid>
                    );
                })}
            </Grid>

            <Dialog open={upgradeDialog.open} onClose={() => setUpgradeDialog({ open: false, plan: null })}>
                <DialogTitle sx={{ fontWeight: 700 }}>
                    {upgradeDialog.plan === 'FREE'
                        ? 'Downgrade to Free Plan?'
                        : `Upgrade to ${plans.find(p => p.name === upgradeDialog.plan)?.displayName || upgradeDialog.plan || ''} Plan?`}
                </DialogTitle>
                <DialogContent>
                    <Typography variant="body2" color="text.secondary">
                        {upgradeDialog.plan === 'FREE'
                            ? 'You will lose access to premium features. Are you sure you want to downgrade?'
                            : 'You will be charged for the new plan. Continue with the upgrade?'}
                    </Typography>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setUpgradeDialog({ open: false, plan: null })}>
                        Cancel
                    </Button>
                    <LoadingButton
                        variant="contained"
                        onClick={handleUpgrade}
                        loading={processing}
                        color={upgradeDialog.plan === 'FREE' ? 'error' : 'primary'}
                    >
                        Confirm
                    </LoadingButton>
                </DialogActions>
            </Dialog>

            <Dialog open={cancelDialog} onClose={() => setCancelDialog(false)}>
                <DialogTitle sx={{ display: 'flex', alignItems: 'center', gap: 1, fontWeight: 700 }}>
                    <WarningIcon sx={{ color: tokens.palette.warning[600] }} />
                    Cancel Subscription?
                </DialogTitle>
                <DialogContent>
                    <Typography variant="body2" color="text.secondary">
                        Your subscription will be cancelled and you will be downgraded to the Free plan.
                        You will lose access to premium features immediately.
                    </Typography>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setCancelDialog(false)}>
                        Keep Subscription
                    </Button>
                    <LoadingButton
                        variant="contained"
                        color="error"
                        onClick={handleCancel}
                        loading={processing}
                    >
                        Cancel Subscription
                    </LoadingButton>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default Subscription;

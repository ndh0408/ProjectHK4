import React, { useState, useEffect } from 'react';
import {
    Box,
    Typography,
    Button,
    Paper,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    Grid,
    Stack,
} from '@mui/material';
import {
    AttachMoney as MoneyIcon,
    TrendingUp as TrendingUpIcon,
    TrendingDown as TrendingDownIcon,
    Subscriptions as SubscriptionIcon,
    Rocket as BoostIcon,
    Refresh as RefreshIcon,
} from '@mui/icons-material';
import { LineChart } from '@mui/x-charts/LineChart';
import { PieChart } from '@mui/x-charts/PieChart';
import { adminApi } from '../../api';
import { LoadingSpinner } from '../../components/common';
import {
    PageHeader,
    StatCard,
    SectionCard,
    EmptyState,
    StatusChip,
} from '../../components/ui';
import { tokens } from '../../theme';
import { toast } from 'react-toastify';

const formatCurrency = (value) => {
    if (value == null) return '$0.00';
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD',
    }).format(value);
};

const PIE_COLORS = [
    tokens.palette.primary[500],
    tokens.palette.secondary[500],
    tokens.palette.success[500],
    tokens.palette.warning[500],
    tokens.palette.info[500],
];

const CHART_AXIS_SX = {
    '& .MuiChartsAxis-line': { stroke: tokens.palette.neutral[200] },
    '& .MuiChartsAxis-tick': { stroke: tokens.palette.neutral[200] },
    '& .MuiAreaElement-root': { fillOpacity: 0.12 },
};

const PLAN_VARIANT = {
    STARTER: 'primary',
    PROFESSIONAL: 'info',
    BUSINESS: 'warning',
    ENTERPRISE: 'success',
};

const PACKAGE_VARIANT = {
    BASIC: 'neutral',
    STANDARD: 'primary',
    PREMIUM: 'info',
    VIP: 'warning',
};

const Revenue = () => {
    const [stats, setStats] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => { loadData(); }, []);

    const loadData = async () => {
        setLoading(true);
        try {
            const response = await adminApi.getRevenueStats();
            setStats(response.data.data);
        } catch (error) {
            console.error('Failed to load revenue stats:', error);
            toast.error('Failed to load revenue data');
        } finally {
            setLoading(false);
        }
    };

    if (loading) return <LoadingSpinner message="Loading revenue data..." fullPage />;

    const monthlyTrend = stats?.monthlyTrend || [];
    const trendLabels = monthlyTrend.map(item => item.month);
    const subscriptionData = monthlyTrend.map(item => parseFloat(item.subscriptionRevenue) || 0);
    const boostData = monthlyTrend.map(item => parseFloat(item.boostRevenue) || 0);

    const subscriptionByPlan = stats?.subscriptionByPlan || {};
    const planData = Object.entries(subscriptionByPlan).map(([key, value], index) => ({
        id: index,
        value: parseFloat(value.revenue) || 0,
        label: value.plan,
        color: PIE_COLORS[index % PIE_COLORS.length],
    })).filter(item => item.value > 0);

    const boostByPackage = stats?.boostByPackage || {};
    const packageData = Object.entries(boostByPackage).map(([key, value], index) => ({
        id: index,
        value: parseFloat(value.revenue) || 0,
        label: value.packageName,
        color: PIE_COLORS[index % PIE_COLORS.length],
    })).filter(item => item.value > 0);

    const growth = stats?.revenueGrowthPercent ?? 0;
    const growthPositive = growth >= 0;

    return (
        <Box>
            <PageHeader
                title="Revenue Analytics"
                subtitle="Track financial performance across subscriptions and boosts."
                actions={
                    <Button
                        startIcon={<RefreshIcon fontSize="small" />}
                        onClick={loadData}
                        variant="outlined"
                    >
                        Refresh
                    </Button>
                }
            />

            <Grid container spacing={2} sx={{ mb: 3 }}>
                <Grid item xs={12} sm={6} lg={3}>
                    <StatCard
                        label="Total revenue"
                        value={formatCurrency(stats?.totalRevenue)}
                        icon={<MoneyIcon />}
                        iconColor="primary"
                        helper="All time"
                    />
                </Grid>
                <Grid item xs={12} sm={6} lg={3}>
                    <StatCard
                        label="This month"
                        value={formatCurrency(stats?.monthlyRevenue)}
                        icon={<TrendingUpIcon />}
                        iconColor="success"
                        change={stats?.revenueGrowthPercent}
                        changeLabel={`Last month: ${formatCurrency(stats?.lastMonthRevenue)}`}
                    />
                </Grid>
                <Grid item xs={12} sm={6} lg={3}>
                    <StatCard
                        label="Subscription revenue"
                        value={formatCurrency(stats?.subscriptionRevenue)}
                        icon={<SubscriptionIcon />}
                        iconColor="info"
                        change={stats?.subscriptionGrowthPercent}
                        changeLabel={`${stats?.activeSubscriptions || 0} active`}
                    />
                </Grid>
                <Grid item xs={12} sm={6} lg={3}>
                    <StatCard
                        label="Boost revenue"
                        value={formatCurrency(stats?.boostRevenue)}
                        icon={<BoostIcon />}
                        iconColor="warning"
                        change={stats?.boostGrowthPercent}
                        changeLabel={`${stats?.activeBoosts || 0} active`}
                    />
                </Grid>
            </Grid>

            <SectionCard
                title="Monthly revenue trend"
                subtitle="Subscription and boost revenue across the last 12 months"
                sx={{ mb: 2 }}
            >
                {monthlyTrend.length > 0 ? (
                    <LineChart
                        xAxis={[{ scaleType: 'band', data: trendLabels }]}
                        series={[
                            {
                                data: subscriptionData,
                                label: 'Subscription',
                                color: tokens.palette.info[500],
                                area: true,
                            },
                            {
                                data: boostData,
                                label: 'Boost',
                                color: tokens.palette.warning[500],
                                area: true,
                            },
                        ]}
                        height={340}
                        sx={CHART_AXIS_SX}
                    />
                ) : (
                    <EmptyState icon={<MoneyIcon sx={{ fontSize: 28 }} />} title="No revenue data yet" compact />
                )}
            </SectionCard>

            <Grid container spacing={2} sx={{ mb: 2 }}>
                <Grid item xs={12} md={6}>
                    <SectionCard title="Revenue by subscription plan">
                        {planData.length > 0 ? (
                            <PieChart
                                series={[{
                                    data: planData,
                                    highlightScope: { faded: 'global', highlighted: 'item' },
                                    innerRadius: 50,
                                    paddingAngle: 2,
                                    cornerRadius: 6,
                                }]}
                                height={280}
                            />
                        ) : (
                            <EmptyState title="No subscription data" compact />
                        )}
                    </SectionCard>
                </Grid>
                <Grid item xs={12} md={6}>
                    <SectionCard title="Revenue by boost package">
                        {packageData.length > 0 ? (
                            <PieChart
                                series={[{
                                    data: packageData,
                                    highlightScope: { faded: 'global', highlighted: 'item' },
                                    innerRadius: 50,
                                    paddingAngle: 2,
                                    cornerRadius: 6,
                                }]}
                                height={280}
                            />
                        ) : (
                            <EmptyState title="No boost data" compact />
                        )}
                    </SectionCard>
                </Grid>
            </Grid>

            <Grid container spacing={2} sx={{ mb: 2 }}>
                <Grid item xs={12} md={6}>
                    <SectionCard title="Subscription plans breakdown" contentSx={{ px: 0 }}>
                        <TableContainer>
                            <Table size="small">
                                <TableHead>
                                    <TableRow>
                                        <TableCell>Plan</TableCell>
                                        <TableCell align="right">Count</TableCell>
                                        <TableCell align="right">Revenue</TableCell>
                                        <TableCell align="right">MRR</TableCell>
                                    </TableRow>
                                </TableHead>
                                <TableBody>
                                    {Object.entries(subscriptionByPlan).map(([key, value]) => (
                                        <TableRow key={key}>
                                            <TableCell>
                                                <StatusChip label={value.plan} status={PLAN_VARIANT[key] || 'neutral'} />
                                            </TableCell>
                                            <TableCell align="right">{value.count}</TableCell>
                                            <TableCell align="right">{formatCurrency(value.revenue)}</TableCell>
                                            <TableCell align="right">{formatCurrency(value.monthlyRecurringRevenue)}</TableCell>
                                        </TableRow>
                                    ))}
                                    {Object.keys(subscriptionByPlan).length === 0 && (
                                        <TableRow>
                                            <TableCell colSpan={4} align="center" sx={{ py: 4, color: 'text.secondary' }}>
                                                No data available
                                            </TableCell>
                                        </TableRow>
                                    )}
                                </TableBody>
                            </Table>
                        </TableContainer>
                    </SectionCard>
                </Grid>
                <Grid item xs={12} md={6}>
                    <SectionCard title="Boost packages breakdown" contentSx={{ px: 0 }}>
                        <TableContainer>
                            <Table size="small">
                                <TableHead>
                                    <TableRow>
                                        <TableCell>Package</TableCell>
                                        <TableCell align="right">Count</TableCell>
                                        <TableCell align="right">Revenue</TableCell>
                                    </TableRow>
                                </TableHead>
                                <TableBody>
                                    {Object.entries(boostByPackage).map(([key, value]) => (
                                        <TableRow key={key}>
                                            <TableCell>
                                                <StatusChip label={value.packageName} status={PACKAGE_VARIANT[key] || 'neutral'} />
                                            </TableCell>
                                            <TableCell align="right">{value.count}</TableCell>
                                            <TableCell align="right">{formatCurrency(value.revenue)}</TableCell>
                                        </TableRow>
                                    ))}
                                    {Object.keys(boostByPackage).length === 0 && (
                                        <TableRow>
                                            <TableCell colSpan={3} align="center" sx={{ py: 4, color: 'text.secondary' }}>
                                                No data available
                                            </TableCell>
                                        </TableRow>
                                    )}
                                </TableBody>
                            </Table>
                        </TableContainer>
                    </SectionCard>
                </Grid>
            </Grid>

            <SectionCard title="Monthly comparison" subtitle="How this month compares to last">
                <Grid container spacing={2}>
                    <Grid item xs={12} md={4}>
                        <Paper variant="outlined" sx={{ p: 2.5, textAlign: 'center', bgcolor: 'grey.50' }}>
                            <Typography variant="caption" color="text.secondary" sx={{ letterSpacing: '0.04em', fontWeight: 600, textTransform: 'uppercase' }}>
                                This month
                            </Typography>
                            <Typography variant="h1" sx={{ color: 'primary.700', my: 1 }}>
                                {formatCurrency(stats?.monthlyRevenue)}
                            </Typography>
                            <Stack direction="row" justifyContent="center" spacing={2} sx={{ color: 'text.secondary' }}>
                                <Typography variant="caption">Subs: {formatCurrency(stats?.monthlySubscriptionRevenue)}</Typography>
                                <Typography variant="caption">Boosts: {formatCurrency(stats?.monthlyBoostRevenue)}</Typography>
                            </Stack>
                        </Paper>
                    </Grid>
                    <Grid item xs={12} md={4}>
                        <Paper variant="outlined" sx={{ p: 2.5, textAlign: 'center', bgcolor: 'grey.50' }}>
                            <Typography variant="caption" color="text.secondary" sx={{ letterSpacing: '0.04em', fontWeight: 600, textTransform: 'uppercase' }}>
                                Last month
                            </Typography>
                            <Typography variant="h1" sx={{ color: 'text.secondary', my: 1 }}>
                                {formatCurrency(stats?.lastMonthRevenue)}
                            </Typography>
                            <Stack direction="row" justifyContent="center" spacing={2} sx={{ color: 'text.secondary' }}>
                                <Typography variant="caption">Subs: {formatCurrency(stats?.lastMonthSubscriptionRevenue)}</Typography>
                                <Typography variant="caption">Boosts: {formatCurrency(stats?.lastMonthBoostRevenue)}</Typography>
                            </Stack>
                        </Paper>
                    </Grid>
                    <Grid item xs={12} md={4}>
                        <Paper
                            variant="outlined"
                            sx={{
                                p: 2.5,
                                textAlign: 'center',
                                bgcolor: growthPositive ? 'success.50' : 'error.50',
                                borderColor: growthPositive ? 'success.100' : 'error.100',
                            }}
                        >
                            <Typography variant="caption" color="text.secondary" sx={{ letterSpacing: '0.04em', fontWeight: 600, textTransform: 'uppercase' }}>
                                Growth
                            </Typography>
                            <Typography
                                variant="h1"
                                sx={{
                                    color: growthPositive ? 'success.700' : 'error.700',
                                    my: 1,
                                    display: 'flex',
                                    alignItems: 'center',
                                    justifyContent: 'center',
                                    gap: 0.75,
                                }}
                            >
                                {growthPositive ? <TrendingUpIcon fontSize="inherit" /> : <TrendingDownIcon fontSize="inherit" />}
                                {growth.toFixed(1)}%
                            </Typography>
                            <Typography variant="caption" color="text.secondary">
                                {growthPositive ? 'Revenue is growing' : 'Revenue declined'}
                            </Typography>
                        </Paper>
                    </Grid>
                </Grid>
            </SectionCard>
        </Box>
    );
};

export default Revenue;

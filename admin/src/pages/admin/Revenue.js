import React, { useState, useEffect } from 'react';
import {
    Box,
    Typography,
    Chip,
    Button,
    Paper,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    Grid,
    Card,
    CardContent,
} from '@mui/material';
import {
    AttachMoney as MoneyIcon,
    TrendingUp as TrendingUpIcon,
    TrendingDown as TrendingDownIcon,
    Subscriptions as SubscriptionIcon,
    Rocket as BoostIcon,
    Refresh as RefreshIcon,
    ArrowUpward as ArrowUpIcon,
    ArrowDownward as ArrowDownIcon,
} from '@mui/icons-material';
import { LineChart } from '@mui/x-charts/LineChart';
import { BarChart } from '@mui/x-charts/BarChart';
import { PieChart } from '@mui/x-charts/PieChart';
import { adminApi } from '../../api';
import { LoadingSpinner } from '../../components/common';
import { toast } from 'react-toastify';

const formatCurrency = (value) => {
    if (value == null) return '$0.00';
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD',
    }).format(value);
};

const StatCard = ({ title, value, subtitle, icon, variant, change, isLoading }) => {
    const isPositive = change >= 0;

    return (
        <Card
            sx={{
                height: '100%',
                background: variant === 'primary'
                    ? 'var(--gradient-purple-pink)'
                    : variant === 'success'
                    ? 'var(--gradient-success)'
                    : variant === 'warning'
                    ? 'var(--gradient-warning)'
                    : variant === 'info'
                    ? 'var(--gradient-blue-cyan)'
                    : 'var(--gradient-purple-pink)',
                color: 'white',
            }}
        >
            <CardContent>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                    <Box>
                        <Typography variant="body2" sx={{ opacity: 0.9, mb: 1 }}>
                            {title}
                        </Typography>
                        <Typography variant="h4" sx={{ fontWeight: 'bold', mb: 1 }}>
                            {isLoading ? '...' : value}
                        </Typography>
                        {subtitle && (
                            <Typography variant="body2" sx={{ opacity: 0.8 }}>
                                {subtitle}
                            </Typography>
                        )}
                        {change !== undefined && (
                            <Chip
                                size="small"
                                icon={isPositive ? <ArrowUpIcon sx={{ fontSize: 14, color: 'inherit' }} /> : <ArrowDownIcon sx={{ fontSize: 14, color: 'inherit' }} />}
                                label={`${isPositive ? '+' : ''}${change?.toFixed(1)}%`}
                                sx={{
                                    mt: 1,
                                    height: 24,
                                    bgcolor: 'rgba(255,255,255,0.2)',
                                    color: 'white',
                                    '& .MuiChip-icon': { ml: 0.5, color: 'white' },
                                    '& .MuiChip-label': { px: 0.5 }
                                }}
                            />
                        )}
                    </Box>
                    <Box sx={{
                        bgcolor: 'rgba(255,255,255,0.2)',
                        borderRadius: 2,
                        p: 1.5,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center'
                    }}>
                        {icon}
                    </Box>
                </Box>
            </CardContent>
        </Card>
    );
};

const ChartCard = ({ title, children, height = 300 }) => (
    <Paper sx={{ p: 3, height: '100%' }}>
        <Typography variant="h6" sx={{ mb: 2, fontWeight: 'bold' }}>
            {title}
        </Typography>
        <Box sx={{ height }}>
            {children}
        </Box>
    </Paper>
);

const Revenue = () => {
    const [stats, setStats] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        loadData();
    }, []);

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

    if (loading) {
        return <LoadingSpinner message="Loading revenue data..." />;
    }

    const chartColors = {
        primary: '#6366f1',
        secondary: '#ec4899',
        success: '#10b981',
        warning: '#f59e0b',
        info: '#3b82f6',
    };

    const pieColors = ['#6366f1', '#ec4899', '#10b981', '#f59e0b'];

    const monthlyTrend = stats?.monthlyTrend || [];
    const trendLabels = monthlyTrend.map(item => item.month);
    const subscriptionData = monthlyTrend.map(item => parseFloat(item.subscriptionRevenue) || 0);
    const boostData = monthlyTrend.map(item => parseFloat(item.boostRevenue) || 0);

    const subscriptionByPlan = stats?.subscriptionByPlan || {};
    const planData = Object.entries(subscriptionByPlan).map(([key, value], index) => ({
        id: index,
        value: parseFloat(value.revenue) || 0,
        label: value.plan,
        color: pieColors[index % pieColors.length],
    })).filter(item => item.value > 0);

    const boostByPackage = stats?.boostByPackage || {};
    const packageData = Object.entries(boostByPackage).map(([key, value], index) => ({
        id: index,
        value: parseFloat(value.revenue) || 0,
        label: value.packageName,
        color: pieColors[index % pieColors.length],
    })).filter(item => item.value > 0);

    return (
        <div className="dashboard">
            <div className="dashboard-header">
                <Box>
                    <h1>Revenue Analytics</h1>
                    <p>Track your platform's financial performance</p>
                </Box>
                <Button
                    startIcon={<RefreshIcon />}
                    onClick={loadData}
                    variant="outlined"
                    size="small"
                >
                    Refresh
                </Button>
            </div>

            <Grid container spacing={3} sx={{ mb: 4 }}>
                <Grid item xs={12} sm={6} md={3}>
                    <StatCard
                        title="Total Revenue"
                        value={formatCurrency(stats?.totalRevenue)}
                        subtitle="All time"
                        icon={<MoneyIcon sx={{ fontSize: 32 }} />}
                        variant="primary"
                    />
                </Grid>
                <Grid item xs={12} sm={6} md={3}>
                    <StatCard
                        title="This Month"
                        value={formatCurrency(stats?.monthlyRevenue)}
                        subtitle={`Last month: ${formatCurrency(stats?.lastMonthRevenue)}`}
                        icon={<TrendingUpIcon sx={{ fontSize: 32 }} />}
                        variant="success"
                        change={stats?.revenueGrowthPercent}
                    />
                </Grid>
                <Grid item xs={12} sm={6} md={3}>
                    <StatCard
                        title="Subscription Revenue"
                        value={formatCurrency(stats?.subscriptionRevenue)}
                        subtitle={`${stats?.activeSubscriptions || 0} active subscriptions`}
                        icon={<SubscriptionIcon sx={{ fontSize: 32 }} />}
                        variant="info"
                        change={stats?.subscriptionGrowthPercent}
                    />
                </Grid>
                <Grid item xs={12} sm={6} md={3}>
                    <StatCard
                        title="Boost Revenue"
                        value={formatCurrency(stats?.boostRevenue)}
                        subtitle={`${stats?.activeBoosts || 0} active boosts`}
                        icon={<BoostIcon sx={{ fontSize: 32 }} />}
                        variant="warning"
                        change={stats?.boostGrowthPercent}
                    />
                </Grid>
            </Grid>

            <Grid container spacing={3} sx={{ mb: 4 }}>
                <Grid item xs={12}>
                    <ChartCard title="Monthly Revenue Trend (Last 12 Months)" height={350}>
                        {monthlyTrend.length > 0 ? (
                            <LineChart
                                xAxis={[{
                                    scaleType: 'band',
                                    data: trendLabels,
                                }]}
                                series={[
                                    {
                                        data: subscriptionData,
                                        label: 'Subscription',
                                        color: chartColors.info,
                                        area: true,
                                    },
                                    {
                                        data: boostData,
                                        label: 'Boost',
                                        color: chartColors.warning,
                                        area: true,
                                    },
                                ]}
                                height={320}
                                sx={{
                                    '& .MuiChartsAxis-line': { stroke: 'var(--neutral-200)' },
                                    '& .MuiChartsAxis-tick': { stroke: 'var(--neutral-200)' },
                                }}
                            />
                        ) : (
                            <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100%' }}>
                                <Typography color="text.secondary">No data available</Typography>
                            </Box>
                        )}
                    </ChartCard>
                </Grid>
            </Grid>

            <Grid container spacing={3} sx={{ mb: 4 }}>
                <Grid item xs={12} md={6}>
                    <ChartCard title="Revenue by Subscription Plan">
                        {planData.length > 0 ? (
                            <PieChart
                                series={[{
                                    data: planData,
                                    highlightScope: { faded: 'global', highlighted: 'item' },
                                    innerRadius: 50,
                                    paddingAngle: 2,
                                    cornerRadius: 4,
                                }]}
                                height={280}
                            />
                        ) : (
                            <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100%' }}>
                                <Typography color="text.secondary">No subscription data</Typography>
                            </Box>
                        )}
                    </ChartCard>
                </Grid>
                <Grid item xs={12} md={6}>
                    <ChartCard title="Revenue by Boost Package">
                        {packageData.length > 0 ? (
                            <PieChart
                                series={[{
                                    data: packageData,
                                    highlightScope: { faded: 'global', highlighted: 'item' },
                                    innerRadius: 50,
                                    paddingAngle: 2,
                                    cornerRadius: 4,
                                }]}
                                height={280}
                            />
                        ) : (
                            <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100%' }}>
                                <Typography color="text.secondary">No boost data</Typography>
                            </Box>
                        )}
                    </ChartCard>
                </Grid>
            </Grid>

            <Grid container spacing={3}>
                <Grid item xs={12} md={6}>
                    <Paper sx={{ p: 3 }}>
                        <Typography variant="h6" sx={{ mb: 2, fontWeight: 'bold' }}>
                            Subscription Plans Breakdown
                        </Typography>
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
                                                <Chip
                                                    label={value.plan}
                                                    size="small"
                                                    color={
                                                        key === 'STARTER' ? 'primary' :
                                                        key === 'PROFESSIONAL' ? 'secondary' :
                                                        key === 'BUSINESS' ? 'warning' : 'default'
                                                    }
                                                />
                                            </TableCell>
                                            <TableCell align="right">{value.count}</TableCell>
                                            <TableCell align="right">{formatCurrency(value.revenue)}</TableCell>
                                            <TableCell align="right">{formatCurrency(value.monthlyRecurringRevenue)}</TableCell>
                                        </TableRow>
                                    ))}
                                    {Object.keys(subscriptionByPlan).length === 0 && (
                                        <TableRow>
                                            <TableCell colSpan={4} align="center">No data</TableCell>
                                        </TableRow>
                                    )}
                                </TableBody>
                            </Table>
                        </TableContainer>
                    </Paper>
                </Grid>
                <Grid item xs={12} md={6}>
                    <Paper sx={{ p: 3 }}>
                        <Typography variant="h6" sx={{ mb: 2, fontWeight: 'bold' }}>
                            Boost Packages Breakdown
                        </Typography>
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
                                                <Chip
                                                    label={value.packageName}
                                                    size="small"
                                                    color={
                                                        key === 'BASIC' ? 'default' :
                                                        key === 'STANDARD' ? 'primary' :
                                                        key === 'PREMIUM' ? 'secondary' :
                                                        key === 'VIP' ? 'warning' : 'default'
                                                    }
                                                />
                                            </TableCell>
                                            <TableCell align="right">{value.count}</TableCell>
                                            <TableCell align="right">{formatCurrency(value.revenue)}</TableCell>
                                        </TableRow>
                                    ))}
                                    {Object.keys(boostByPackage).length === 0 && (
                                        <TableRow>
                                            <TableCell colSpan={3} align="center">No data</TableCell>
                                        </TableRow>
                                    )}
                                </TableBody>
                            </Table>
                        </TableContainer>
                    </Paper>
                </Grid>
            </Grid>

            <Grid container spacing={3} sx={{ mt: 2 }}>
                <Grid item xs={12}>
                    <Paper sx={{ p: 3 }}>
                        <Typography variant="h6" sx={{ mb: 2, fontWeight: 'bold' }}>
                            Monthly Comparison
                        </Typography>
                        <Grid container spacing={3}>
                            <Grid item xs={12} md={4}>
                                <Box sx={{ textAlign: 'center', p: 2, bgcolor: 'grey.50', borderRadius: 2 }}>
                                    <Typography variant="body2" color="text.secondary">This Month Revenue</Typography>
                                    <Typography variant="h4" sx={{ fontWeight: 'bold', color: 'primary.main' }}>
                                        {formatCurrency(stats?.monthlyRevenue)}
                                    </Typography>
                                    <Box sx={{ display: 'flex', justifyContent: 'center', gap: 2, mt: 1 }}>
                                        <Typography variant="body2">
                                            Subscriptions: {formatCurrency(stats?.monthlySubscriptionRevenue)}
                                        </Typography>
                                        <Typography variant="body2">
                                            Boosts: {formatCurrency(stats?.monthlyBoostRevenue)}
                                        </Typography>
                                    </Box>
                                </Box>
                            </Grid>
                            <Grid item xs={12} md={4}>
                                <Box sx={{ textAlign: 'center', p: 2, bgcolor: 'grey.50', borderRadius: 2 }}>
                                    <Typography variant="body2" color="text.secondary">Last Month Revenue</Typography>
                                    <Typography variant="h4" sx={{ fontWeight: 'bold', color: 'text.secondary' }}>
                                        {formatCurrency(stats?.lastMonthRevenue)}
                                    </Typography>
                                    <Box sx={{ display: 'flex', justifyContent: 'center', gap: 2, mt: 1 }}>
                                        <Typography variant="body2">
                                            Subscriptions: {formatCurrency(stats?.lastMonthSubscriptionRevenue)}
                                        </Typography>
                                        <Typography variant="body2">
                                            Boosts: {formatCurrency(stats?.lastMonthBoostRevenue)}
                                        </Typography>
                                    </Box>
                                </Box>
                            </Grid>
                            <Grid item xs={12} md={4}>
                                <Box sx={{ textAlign: 'center', p: 2, bgcolor: stats?.revenueGrowthPercent >= 0 ? 'success.50' : 'error.50', borderRadius: 2 }}>
                                    <Typography variant="body2" color="text.secondary">Growth</Typography>
                                    <Typography
                                        variant="h4"
                                        sx={{
                                            fontWeight: 'bold',
                                            color: stats?.revenueGrowthPercent >= 0 ? 'success.main' : 'error.main',
                                            display: 'flex',
                                            alignItems: 'center',
                                            justifyContent: 'center',
                                            gap: 1
                                        }}
                                    >
                                        {stats?.revenueGrowthPercent >= 0 ? <TrendingUpIcon /> : <TrendingDownIcon />}
                                        {stats?.revenueGrowthPercent?.toFixed(1)}%
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                                        {stats?.revenueGrowthPercent >= 0 ? 'Revenue is growing!' : 'Revenue declined'}
                                    </Typography>
                                </Box>
                            </Grid>
                        </Grid>
                    </Paper>
                </Grid>
            </Grid>
        </div>
    );
};

export default Revenue;

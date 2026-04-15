import React, { useState, useEffect } from 'react';
import {
    Box,
    Typography,
    Chip,
    FormControl,
    InputLabel,
    Select,
    MenuItem,
    Button,
    Alert,
    AlertTitle,
    CircularProgress,
    Collapse,
    IconButton,
    Paper,
} from '@mui/material';
import {
    People as PeopleIcon,
    Event as EventIcon,
    Business as BusinessIcon,
    ArrowUpward as ArrowUpIcon,
    ArrowDownward as ArrowDownIcon,
    AutoAwesome as AIIcon,
    Refresh as RefreshIcon,
    CheckCircle as SuccessIcon,
    Warning as WarningIcon,
    Info as InfoIcon,
    Lightbulb as TipIcon,
    ExpandMore as ExpandMoreIcon,
    ExpandLess as ExpandLessIcon,
    ConfirmationNumber as RegistrationIcon,
} from '@mui/icons-material';
import { BarChart } from '@mui/x-charts/BarChart';
import { PieChart } from '@mui/x-charts/PieChart';
import { LineChart } from '@mui/x-charts/LineChart';
import { adminApi } from '../../api';
import { LoadingSpinner } from '../../components/common';
import { toast } from 'react-toastify';

const StatCard = ({ title, value, icon, variant, change }) => {
    const isPositive = change >= 0;

    return (
        <div className={`stat-card ${variant}`}>
            <div className="stat-card-content">
                <div className="stat-card-info">
                    <h3>{title}</h3>
                    <div className="stat-card-value">{value?.toLocaleString() || 0}</div>
                    {change !== undefined && (
                        <Chip
                            size="small"
                            icon={isPositive ? <ArrowUpIcon sx={{ fontSize: 14 }} /> : <ArrowDownIcon sx={{ fontSize: 14 }} />}
                            label={`${isPositive ? '+' : ''}${change}%`}
                            className={`stat-card-change ${isPositive ? 'positive' : 'negative'}`}
                            sx={{
                                height: 24,
                                '& .MuiChip-icon': { ml: 0.5 },
                                '& .MuiChip-label': { px: 0.5 }
                            }}
                        />
                    )}
                </div>
                <div className="stat-card-icon">
                    {icon}
                </div>
            </div>
        </div>
    );
};

const ChartCard = ({ title, children, legend }) => (
    <div className="chart-card">
        <div className="chart-card-header">
            <h3>{title}</h3>
            {legend && <div className="chart-legend">{legend}</div>}
        </div>
        {children}
    </div>
);

const InsightIcon = ({ type }) => {
    switch (type) {
        case 'success':
            return <SuccessIcon sx={{ color: 'success.main' }} />;
        case 'warning':
            return <WarningIcon sx={{ color: 'warning.main' }} />;
        case 'tip':
            return <TipIcon sx={{ color: 'secondary.main' }} />;
        case 'info':
        default:
            return <InfoIcon sx={{ color: 'info.main' }} />;
    }
};

const InsightSeverity = (type) => {
    switch (type) {
        case 'success':
            return 'success';
        case 'warning':
            return 'warning';
        case 'tip':
            return 'info';
        case 'info':
        default:
            return 'info';
    }
};

const AdminDashboard = () => {
    const [stats, setStats] = useState(null);
    const [userGrowth, setUserGrowth] = useState([]);
    const [eventsByCity, setEventsByCity] = useState([]);
    const [eventsByCategory, setEventsByCategory] = useState([]);
    const [loading, setLoading] = useState(true);
    const [timeRange, setTimeRange] = useState(6);
    const [aiInsights, setAiInsights] = useState(null);
    const [aiLoading, setAiLoading] = useState(false);
    const [showInsights, setShowInsights] = useState(true);

    useEffect(() => {
        loadData();
    }, [timeRange]);

    const loadData = async () => {
        setLoading(true);
        try {
            const [statsRes, growthRes, cityRes, categoryRes] = await Promise.all([
                adminApi.getSystemStats(),
                adminApi.getUserGrowth(timeRange),
                adminApi.getEventsByCity(),
                adminApi.getEventsByCategory(),
            ]);

            setStats(statsRes.data.data);
            setUserGrowth(growthRes.data.data || []);
            setEventsByCity(cityRes.data.data || []);
            setEventsByCategory(categoryRes.data.data || []);
        } catch (error) {
            console.error('Failed to load dashboard data:', error);
        } finally {
            setLoading(false);
        }
    };

    const loadAIInsights = async () => {
        setAiLoading(true);
        try {
            const response = await adminApi.getAIInsights();

            if (response.data?.data) {
                setAiInsights(response.data.data);
                if (response.data.message === 'Basic insights') {
                    toast.info('Hiển thị phân tích cơ bản (AI đang gặp sự cố)');
                } else {
                    toast.success('AI insights generated!');
                }
            }
        } catch (error) {
            toast.error('Failed to generate insights: ' + error.message);
        } finally {
            setAiLoading(false);
        }
    };

    if (loading) {
        return <LoadingSpinner message="Loading dashboard..." />;
    }

    const chartColors = {
        primary: '#6366f1',
        secondary: '#ec4899',
        success: '#10b981',
        warning: '#f59e0b',
        info: '#3b82f6',
    };

    const pieColors = ['#6366f1', '#ec4899', '#10b981', '#f59e0b', '#3b82f6', '#8b5cf6', '#14b8a6', '#f97316'];

    return (
        <div className="dashboard">
            <div className="dashboard-header">
                <Box>
                    <h1>Dashboard</h1>
                    <p>Welcome back! Here's what's happening with your platform.</p>
                </Box>
                <Box sx={{ display: 'flex', gap: 2, alignItems: 'center' }}>
                    <FormControl size="small" sx={{ minWidth: 150 }}>
                        <InputLabel>Time Range</InputLabel>
                        <Select
                            value={timeRange}
                            onChange={(e) => setTimeRange(e.target.value)}
                            label="Time Range"
                        >
                            <MenuItem value={3}>Last 3 months</MenuItem>
                            <MenuItem value={6}>Last 6 months</MenuItem>
                            <MenuItem value={12}>Last 12 months</MenuItem>
                        </Select>
                    </FormControl>
                    <Button
                        startIcon={<RefreshIcon />}
                        onClick={loadData}
                        variant="outlined"
                        size="small"
                    >
                        Refresh
                    </Button>
                </Box>
            </div>

            <div className="stats-grid">
                <StatCard
                    title="Total Users"
                    value={stats?.totalUsers}
                    icon={<PeopleIcon />}
                    variant="primary"
                    change={stats?.userGrowthPercent}
                />
                <StatCard
                    title="Organisers"
                    value={stats?.totalOrganisers}
                    icon={<BusinessIcon />}
                    variant="success"
                    change={stats?.organiserGrowthPercent}
                />
                <StatCard
                    title="Total Events"
                    value={stats?.totalEvents}
                    icon={<EventIcon />}
                    variant="warning"
                    change={stats?.eventGrowthPercent}
                />
                <StatCard
                    title="Registrations"
                    value={stats?.totalRegistrations}
                    icon={<RegistrationIcon />}
                    variant="info"
                    change={stats?.registrationGrowthPercent}
                />
            </div>

            <Paper sx={{ p: 2, mb: 3, background: 'linear-gradient(135deg, #f5f3ff 0%, #ede9fe 100%)' }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <AIIcon sx={{ color: 'secondary.main' }} />
                        <Typography variant="h6" fontWeight="bold">
                            AI Insights & Recommendations
                        </Typography>
                    </Box>
                    <Box sx={{ display: 'flex', gap: 1 }}>
                        {aiInsights && (
                            <IconButton size="small" onClick={() => setShowInsights(!showInsights)}>
                                {showInsights ? <ExpandLessIcon /> : <ExpandMoreIcon />}
                            </IconButton>
                        )}
                        <Button
                            variant="contained"
                            color="secondary"
                            size="small"
                            startIcon={aiLoading ? <CircularProgress size={16} color="inherit" /> : (aiInsights ? <RefreshIcon /> : <AIIcon />)}
                            onClick={loadAIInsights}
                            disabled={aiLoading}
                        >
                            {aiLoading ? 'Analyzing...' : (aiInsights ? 'Refresh' : 'Get AI Insights')}
                        </Button>
                    </Box>
                </Box>

                {!aiInsights && !aiLoading && (
                    <Alert severity="info" sx={{ bgcolor: 'transparent' }}>
                        <AlertTitle>Get platform analytics</AlertTitle>
                        Click "Get AI Insights" to analyze platform data and receive actionable recommendations.
                    </Alert>
                )}

                <Collapse in={showInsights && aiInsights !== null}>
                    {aiInsights && (
                        <Box>
                            {aiInsights.summary && (
                                <Typography variant="body1" sx={{ mb: 2, fontStyle: 'italic', color: 'text.secondary' }}>
                                    "{aiInsights.summary}"
                                </Typography>
                            )}

                            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5 }}>
                                {aiInsights.insights?.map((insight, index) => (
                                    <Alert
                                        key={index}
                                        severity={InsightSeverity(insight.type)}
                                        icon={<InsightIcon type={insight.type} />}
                                        sx={{
                                            '& .MuiAlert-message': { width: '100%' },
                                            bgcolor: 'background.paper',
                                        }}
                                        action={
                                            insight.actionText && (
                                                <Button color="inherit" size="small">
                                                    {insight.actionText}
                                                </Button>
                                            )
                                        }
                                    >
                                        <AlertTitle sx={{ fontWeight: 'bold' }}>{insight.title}</AlertTitle>
                                        {insight.description}
                                    </Alert>
                                ))}
                            </Box>
                        </Box>
                    )}
                </Collapse>
            </Paper>

            <div className="charts-grid">
                <ChartCard
                    title="User Growth"
                    legend={
                        <div className="chart-legend-item">
                            <span className="dot primary"></span>
                            <span>New Users</span>
                        </div>
                    }
                >
                    {userGrowth.length > 0 && userGrowth.some(item => item.count != null) ? (
                        <LineChart
                            xAxis={[{
                                scaleType: 'band',
                                data: userGrowth.map(item => `${item.month}/${item.year}`),
                            }]}
                            series={[{
                                data: userGrowth.map(item => item.count || 0),
                                color: chartColors.primary,
                                area: true,
                            }]}
                            height={300}
                            slotProps={{
                                noDataOverlay: { message: 'No data available' },
                            }}
                            sx={{
                                '& .MuiChartsAxis-line': { stroke: '#e5e7eb' },
                                '& .MuiChartsAxis-tick': { stroke: '#e5e7eb' },
                            }}
                        />
                    ) : (
                        <div className="empty-state">
                            <EventIcon />
                            <p>No data available</p>
                        </div>
                    )}
                </ChartCard>

                <ChartCard
                    title="Events Growth"
                    legend={
                        <div className="chart-legend-item">
                            <span className="dot success"></span>
                            <span>New Events</span>
                        </div>
                    }
                >
                    {stats?.newEventsPerMonth?.length > 0 && stats.newEventsPerMonth.some(item => item.count != null) ? (
                        <BarChart
                            xAxis={[{
                                scaleType: 'band',
                                data: stats.newEventsPerMonth.map(item => `${item.month}/${item.year}`),
                            }]}
                            series={[{
                                data: stats.newEventsPerMonth.map(item => item.count || 0),
                                color: chartColors.success,
                            }]}
                            height={300}
                            slotProps={{
                                noDataOverlay: { message: 'No data available' },
                            }}
                            sx={{
                                '& .MuiChartsAxis-line': { stroke: '#e5e7eb' },
                                '& .MuiChartsAxis-tick': { stroke: '#e5e7eb' },
                            }}
                        />
                    ) : (
                        <div className="empty-state">
                            <EventIcon />
                            <p>No data available</p>
                        </div>
                    )}
                </ChartCard>
            </div>

            <div className="charts-grid">
                <ChartCard
                    title="Events by City"
                    legend={
                        <div className="chart-legend-item">
                            <span className="dot warning"></span>
                            <span>Events</span>
                        </div>
                    }
                >
                    {eventsByCity.length > 0 && eventsByCity.some(item => item.cityName && item.eventCount != null) ? (
                        <BarChart
                            xAxis={[{
                                scaleType: 'band',
                                data: eventsByCity.filter(item => item.cityName).map(item => item.cityName),
                            }]}
                            series={[{
                                data: eventsByCity.filter(item => item.cityName).map(item => item.eventCount || 0),
                                color: chartColors.warning,
                            }]}
                            height={300}
                            slotProps={{
                                noDataOverlay: { message: 'No data available' },
                            }}
                            sx={{
                                '& .MuiChartsAxis-line': { stroke: '#e5e7eb' },
                                '& .MuiChartsAxis-tick': { stroke: '#e5e7eb' },
                            }}
                        />
                    ) : (
                        <div className="empty-state">
                            <EventIcon />
                            <p>No data available</p>
                        </div>
                    )}
                </ChartCard>

                <ChartCard title="Events by Category">
                    {eventsByCategory.length > 0 && eventsByCategory.some(item => item.categoryName && item.eventCount > 0) ? (
                        <PieChart
                            series={[{
                                data: eventsByCategory
                                    .filter(item => item.categoryName && item.eventCount > 0)
                                    .map((item, index) => ({
                                        id: index,
                                        value: item.eventCount,
                                        label: item.categoryName,
                                        color: pieColors[index % pieColors.length],
                                    })),
                                highlightScope: { faded: 'global', highlighted: 'item' },
                                innerRadius: 40,
                                paddingAngle: 2,
                                cornerRadius: 4,
                            }]}
                            height={300}
                            slotProps={{
                                noDataOverlay: { message: 'No data available' },
                            }}
                        />
                    ) : (
                        <div className="empty-state">
                            <EventIcon />
                            <p>No data available</p>
                        </div>
                    )}
                </ChartCard>
            </div>
        </div>
    );
};

export default AdminDashboard;

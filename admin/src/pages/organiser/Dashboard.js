import React, { useState, useEffect } from 'react';
import {
    Avatar,
    Chip,
    Box,
    Paper,
    Typography,
    Button,
    Alert,
    AlertTitle,
    CircularProgress,
    IconButton,
    Tooltip,
    Collapse,
} from '@mui/material';
import {
    Event as EventIcon,
    People as PeopleIcon,
    PersonAdd as FollowersIcon,
    AttachMoney as MoneyIcon,
    ArrowUpward as ArrowUpIcon,
    ArrowDownward as ArrowDownIcon,
    AutoAwesome as AIIcon,
    Lightbulb as TipIcon,
    CheckCircle as SuccessIcon,
    Warning as WarningIcon,
    Info as InfoIcon,
    Refresh as RefreshIcon,
    ExpandMore as ExpandMoreIcon,
    ExpandLess as ExpandLessIcon,
} from '@mui/icons-material';
import { LineChart } from '@mui/x-charts/LineChart';
import { organiserApi } from '../../api';
import { LoadingSpinner } from '../../components/common';
import { toast } from 'react-toastify';

const StatCard = ({ title, value, icon, variant, change }) => {
    const isPositive = change >= 0;

    return (
        <div className={`stat-card ${variant}`}>
            <div className="stat-card-content">
                <div className="stat-card-info">
                    <h3>{title}</h3>
                    <div className="stat-card-value">{value}</div>
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

const OrganiserDashboard = () => {
    const [stats, setStats] = useState(null);
    const [loading, setLoading] = useState(true);
    const [aiInsights, setAiInsights] = useState(null);
    const [aiLoading, setAiLoading] = useState(false);
    const [showInsights, setShowInsights] = useState(true);

    useEffect(() => {
        loadDashboard();
    }, []);

    const loadDashboard = async () => {
        try {
            const response = await organiserApi.getDashboardStats();
            setStats(response.data.data);
        } catch (error) {
            console.error('Failed to load dashboard:', error);
        } finally {
            setLoading(false);
        }
    };

    const loadAIInsights = async () => {
        setAiLoading(true);
        try {
            const response = await organiserApi.getAIInsights();

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

    const formatCurrency = (value) => {
        return new Intl.NumberFormat('vi-VN', {
            style: 'currency',
            currency: 'VND',
        }).format(value || 0);
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

    return (
        <div className="dashboard">
            <div className="dashboard-header">
                <h1>Dashboard</h1>
                <p>Welcome back! Here's your event performance overview.</p>
            </div>

            <div className="stats-grid">
                <StatCard
                    title="Total Events"
                    value={stats?.totalEvents?.toLocaleString() || 0}
                    icon={<EventIcon />}
                    variant="primary"
                    change={5}
                />
                <StatCard
                    title="Total Registrations"
                    value={stats?.totalRegistrations?.toLocaleString() || 0}
                    icon={<PeopleIcon />}
                    variant="success"
                    change={12}
                />
                <StatCard
                    title="Followers"
                    value={stats?.totalFollowers?.toLocaleString() || 0}
                    icon={<FollowersIcon />}
                    variant="warning"
                    change={8}
                />
                <StatCard
                    title="Total Revenue"
                    value={formatCurrency(stats?.totalRevenue)}
                    icon={<MoneyIcon />}
                    variant="info"
                    change={15}
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
                        <Tooltip title={aiInsights ? "Refresh insights" : "Generate AI insights"}>
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
                        </Tooltip>
                    </Box>
                </Box>

                {!aiInsights && !aiLoading && (
                    <Alert severity="info" sx={{ bgcolor: 'transparent' }}>
                        <AlertTitle>Get personalized recommendations</AlertTitle>
                        Click "Get AI Insights" to analyze your data and receive actionable recommendations to grow your events.
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
                    title="Registration Growth"
                    legend={
                        <div className="chart-legend-item">
                            <span className="dot primary"></span>
                            <span>Registrations</span>
                        </div>
                    }
                >
                    {stats?.registrationGrowth?.length > 0 ? (
                        <LineChart
                            xAxis={[{
                                scaleType: 'band',
                                data: stats.registrationGrowth.map(item => item.date || item.month || ''),
                            }]}
                            series={[{
                                data: stats.registrationGrowth.map(item => item.count || 0),
                                color: chartColors.primary,
                                curve: 'catmullRom',
                                area: true,
                            }]}
                            height={300}
                            tooltip={{ trigger: 'axis' }}
                            sx={{
                                '& .MuiChartsAxis-line': { stroke: 'var(--neutral-200)' },
                                '& .MuiChartsAxis-tick': { stroke: 'var(--neutral-200)' },
                                '& .MuiAreaElement-root': {
                                    fillOpacity: 0.1,
                                },
                            }}
                        />
                    ) : (
                        <div className="empty-state">
                            <EventIcon />
                            <p>No data available</p>
                        </div>
                    )}
                </ChartCard>

                <ChartCard title="Recent Events">
                    {stats?.recentEvents?.length > 0 ? (
                        <ul className="activity-list">
                            {stats.recentEvents.slice(0, 5).map((event) => (
                                <li key={event.id} className="activity-item">
                                    <Avatar
                                        src={event.imageUrl}
                                        variant="rounded"
                                        sx={{
                                            width: 48,
                                            height: 48,
                                            background: 'linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%)',
                                        }}
                                    >
                                        <EventIcon />
                                    </Avatar>
                                    <div className="activity-content">
                                        <div className="activity-title">{event.title}</div>
                                        <div className="activity-meta">
                                            <span className={`activity-badge ${event.status?.toLowerCase()}`}>
                                                {event.status}
                                            </span>
                                        </div>
                                    </div>
                                    <div className="activity-stats">
                                        <span>{event.currentRegistrations}/{event.capacity}</span>
                                    </div>
                                </li>
                            ))}
                        </ul>
                    ) : (
                        <div className="empty-state">
                            <EventIcon />
                            <p>No events yet</p>
                        </div>
                    )}
                </ChartCard>
            </div>
        </div>
    );
};

export default OrganiserDashboard;

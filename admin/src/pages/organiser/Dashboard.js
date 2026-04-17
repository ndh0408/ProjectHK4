import React, { useState, useEffect } from 'react';
import {
    Avatar,
    Box,
    Grid,
    Paper,
    Typography,
    Button,
    Alert,
    AlertTitle,
    CircularProgress,
    IconButton,
    Tooltip,
    Collapse,
    Stack,
    LinearProgress,
} from '@mui/material';
import {
    Event as EventIcon,
    People as PeopleIcon,
    PersonAdd as FollowersIcon,
    AttachMoney as MoneyIcon,
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
import {
    PageHeader,
    StatCard,
    SectionCard,
    EmptyState,
    StatusChip,
} from '../../components/ui';
import { tokens } from '../../theme';
import { toast } from 'react-toastify';

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

const insightSeverity = (type) =>
    type === 'success' ? 'success'
        : type === 'warning' ? 'warning'
            : type === 'tip' ? 'info'
                : 'info';

const eventStatusVariant = (status) => {
    const s = (status || '').toUpperCase();
    if (s === 'PUBLISHED' || s === 'LIVE') return 'success';
    if (s === 'DRAFT') return 'neutral';
    if (s === 'CANCELLED' || s === 'REJECTED') return 'danger';
    if (s === 'PENDING') return 'warning';
    if (s === 'COMPLETED') return 'info';
    return 'neutral';
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

    const formatCurrency = (value) =>
        new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(value || 0);

    if (loading) return <LoadingSpinner message="Loading dashboard..." fullPage />;

    return (
        <Box>
            <PageHeader
                title="Dashboard"
                subtitle="Welcome back. Here’s your event performance at a glance."
                actions={
                    <Button
                        variant="outlined"
                        startIcon={<RefreshIcon fontSize="small" />}
                        onClick={loadDashboard}
                    >
                        Refresh
                    </Button>
                }
            />

            <Grid container spacing={2} sx={{ mb: 3 }}>
                <Grid item xs={12} sm={6} lg={3}>
                    <StatCard
                        label="Total Events"
                        value={stats?.totalEvents?.toLocaleString() || 0}
                        icon={<EventIcon />}
                        iconColor="primary"
                        change={5}
                        changeLabel="vs. last month"
                    />
                </Grid>
                <Grid item xs={12} sm={6} lg={3}>
                    <StatCard
                        label="Registrations"
                        value={stats?.totalRegistrations?.toLocaleString() || 0}
                        icon={<PeopleIcon />}
                        iconColor="success"
                        change={12}
                        changeLabel="vs. last month"
                    />
                </Grid>
                <Grid item xs={12} sm={6} lg={3}>
                    <StatCard
                        label="Followers"
                        value={stats?.totalFollowers?.toLocaleString() || 0}
                        icon={<FollowersIcon />}
                        iconColor="warning"
                        change={8}
                        changeLabel="vs. last month"
                    />
                </Grid>
                <Grid item xs={12} sm={6} lg={3}>
                    <StatCard
                        label="Total Revenue"
                        value={formatCurrency(stats?.totalRevenue)}
                        icon={<MoneyIcon />}
                        iconColor="info"
                        change={15}
                        changeLabel="vs. last month"
                    />
                </Grid>
            </Grid>

            <Paper
                variant="outlined"
                sx={{
                    mb: 3,
                    p: { xs: 2, md: 2.5 },
                    background: `linear-gradient(135deg, ${tokens.palette.primary[50]} 0%, ${tokens.palette.secondary[50]} 100%)`,
                    borderColor: tokens.palette.primary[100],
                }}
            >
                <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} alignItems={{ xs: 'flex-start', sm: 'center' }}>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.25, flex: 1 }}>
                        <Box
                            sx={{
                                width: 38,
                                height: 38,
                                borderRadius: 2,
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                bgcolor: 'secondary.100',
                                color: 'secondary.700',
                            }}
                        >
                            <AIIcon />
                        </Box>
                        <Box>
                            <Typography variant="h3" sx={{ fontSize: '1rem' }}>
                                AI Insights & Recommendations
                            </Typography>
                            <Typography variant="caption" color="text.secondary">
                                Let Luma analyse your data and surface opportunities.
                            </Typography>
                        </Box>
                    </Box>
                    <Stack direction="row" spacing={1} alignItems="center">
                        {aiInsights && (
                            <IconButton
                                size="small"
                                onClick={() => setShowInsights((v) => !v)}
                                aria-label={showInsights ? 'Collapse insights' : 'Expand insights'}
                            >
                                {showInsights ? <ExpandLessIcon /> : <ExpandMoreIcon />}
                            </IconButton>
                        )}
                        <Tooltip title={aiInsights ? 'Refresh insights' : 'Generate AI insights'}>
                            <span>
                                <Button
                                    variant="contained"
                                    color="secondary"
                                    size="small"
                                    startIcon={aiLoading
                                        ? <CircularProgress size={14} color="inherit" thickness={5} />
                                        : (aiInsights ? <RefreshIcon fontSize="small" /> : <AIIcon fontSize="small" />)
                                    }
                                    onClick={loadAIInsights}
                                    disabled={aiLoading}
                                >
                                    {aiLoading ? 'Analysing...' : (aiInsights ? 'Refresh' : 'Get AI insights')}
                                </Button>
                            </span>
                        </Tooltip>
                    </Stack>
                </Stack>

                {!aiInsights && !aiLoading && (
                    <Alert severity="info" sx={{ mt: 2, bgcolor: 'transparent', border: '1px dashed', borderColor: 'divider' }}>
                        <AlertTitle sx={{ fontSize: '0.875rem' }}>Get personalised recommendations</AlertTitle>
                        Click <b>Get AI insights</b> to analyse your data and receive actionable tips.
                    </Alert>
                )}

                <Collapse in={showInsights && Boolean(aiInsights)}>
                    {aiInsights && (
                        <Box sx={{ mt: 2 }}>
                            {aiInsights.summary && (
                                <Typography
                                    variant="body2"
                                    sx={{
                                        mb: 2,
                                        fontStyle: 'italic',
                                        color: 'text.secondary',
                                        px: 1.5,
                                        py: 1,
                                        borderLeft: '3px solid',
                                        borderColor: 'secondary.300',
                                        bgcolor: 'rgba(255,255,255,0.5)',
                                        borderRadius: 1,
                                    }}
                                >
                                    “{aiInsights.summary}”
                                </Typography>
                            )}

                            <Stack spacing={1.25}>
                                {aiInsights.insights?.map((insight, index) => (
                                    <Alert
                                        key={index}
                                        severity={insightSeverity(insight.type)}
                                        icon={<InsightIcon type={insight.type} />}
                                        sx={{
                                            '& .MuiAlert-message': { width: '100%' },
                                            bgcolor: 'background.paper',
                                        }}
                                        action={insight.actionText && (
                                            <Button color="inherit" size="small">
                                                {insight.actionText}
                                            </Button>
                                        )}
                                    >
                                        <AlertTitle sx={{ fontWeight: 600, fontSize: '0.875rem' }}>
                                            {insight.title}
                                        </AlertTitle>
                                        {insight.description}
                                    </Alert>
                                ))}
                            </Stack>
                        </Box>
                    )}
                </Collapse>
            </Paper>

            <Grid container spacing={2}>
                <Grid item xs={12} lg={7}>
                    <SectionCard
                        title="Registration Growth"
                        subtitle="Registrations over the selected period"
                    >
                        {stats?.registrationGrowth?.length > 0 ? (
                            <LineChart
                                xAxis={[{
                                    scaleType: 'band',
                                    data: stats.registrationGrowth.map(item => item.date || item.month || ''),
                                }]}
                                series={[{
                                    data: stats.registrationGrowth.map(item => item.count || 0),
                                    color: tokens.palette.primary[500],
                                    curve: 'catmullRom',
                                    area: true,
                                }]}
                                height={300}
                                sx={{
                                    '& .MuiChartsAxis-line': { stroke: tokens.palette.neutral[200] },
                                    '& .MuiChartsAxis-tick': { stroke: tokens.palette.neutral[200] },
                                    '& .MuiAreaElement-root': { fillOpacity: 0.12 },
                                }}
                            />
                        ) : (
                            <EmptyState
                                icon={<EventIcon sx={{ fontSize: 28 }} />}
                                title="No registrations yet"
                                description="Publish an event to start tracking registration growth."
                                compact
                            />
                        )}
                    </SectionCard>
                </Grid>

                <Grid item xs={12} lg={5}>
                    <SectionCard
                        title="Recent Events"
                        subtitle="Your most recent events and their capacity"
                        contentSx={{ px: 0 }}
                    >
                        {stats?.recentEvents?.length > 0 ? (
                            <Stack divider={<Box sx={{ height: 1, bgcolor: 'divider' }} />}>
                                {stats.recentEvents.slice(0, 5).map((event) => {
                                    const registered = event.currentRegistrations || 0;
                                    const capacity = event.capacity || 0;
                                    const progress = capacity > 0
                                        ? Math.min(100, (registered / capacity) * 100)
                                        : 0;
                                    return (
                                        <Box
                                            key={event.id}
                                            sx={{
                                                display: 'flex',
                                                alignItems: 'center',
                                                gap: 1.75,
                                                px: 2.5,
                                                py: 1.75,
                                            }}
                                        >
                                            <Avatar
                                                src={event.imageUrl}
                                                variant="rounded"
                                                sx={{
                                                    width: 44,
                                                    height: 44,
                                                    background: tokens.gradient.primary,
                                                }}
                                            >
                                                <EventIcon fontSize="small" />
                                            </Avatar>
                                            <Box sx={{ flex: 1, minWidth: 0 }}>
                                                <Typography
                                                    variant="subtitle2"
                                                    noWrap
                                                    sx={{ fontWeight: 600, mb: 0.5 }}
                                                >
                                                    {event.title}
                                                </Typography>
                                                <Stack direction="row" spacing={1} alignItems="center">
                                                    <StatusChip
                                                        label={event.status || 'Draft'}
                                                        status={eventStatusVariant(event.status)}
                                                        size="small"
                                                    />
                                                    <Typography variant="caption" color="text.secondary">
                                                        {registered}/{capacity || '∞'} seats
                                                    </Typography>
                                                </Stack>
                                                {capacity > 0 && (
                                                    <LinearProgress
                                                        variant="determinate"
                                                        value={progress}
                                                        sx={{ mt: 1, height: 4 }}
                                                    />
                                                )}
                                            </Box>
                                        </Box>
                                    );
                                })}
                            </Stack>
                        ) : (
                            <EmptyState
                                icon={<EventIcon sx={{ fontSize: 28 }} />}
                                title="No recent events"
                                description="Once you publish events they will appear here."
                                compact
                            />
                        )}
                    </SectionCard>
                </Grid>
            </Grid>
        </Box>
    );
};

export default OrganiserDashboard;

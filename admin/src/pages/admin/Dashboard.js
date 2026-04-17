import React, { useState, useEffect } from 'react';
import {
    Box,
    Typography,
    Grid,
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
    Stack,
    Tooltip,
} from '@mui/material';
import {
    People as PeopleIcon,
    Event as EventIcon,
    Business as BusinessIcon,
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
import {
    PageHeader,
    StatCard,
    SectionCard,
    EmptyState,
} from '../../components/ui';
import { tokens } from '../../theme';
import { toast } from 'react-toastify';

const InsightIcon = ({ type }) => {
    switch (type) {
        case 'success': return <SuccessIcon sx={{ color: 'success.main' }} />;
        case 'warning': return <WarningIcon sx={{ color: 'warning.main' }} />;
        case 'tip': return <TipIcon sx={{ color: 'secondary.main' }} />;
        default: return <InfoIcon sx={{ color: 'info.main' }} />;
    }
};

const insightSeverity = (type) =>
    type === 'success' ? 'success'
        : type === 'warning' ? 'warning'
            : type === 'tip' ? 'info'
                : 'info';

const CHART_AXIS_SX = {
    '& .MuiChartsAxis-line': { stroke: tokens.palette.neutral[200] },
    '& .MuiChartsAxis-tick': { stroke: tokens.palette.neutral[200] },
};

const PIE_COLORS = [
    tokens.palette.primary[500],
    tokens.palette.secondary[500],
    tokens.palette.success[500],
    tokens.palette.warning[500],
    tokens.palette.info[500],
    tokens.palette.primary[400],
    '#14b8a6',
    '#f97316',
];

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

    // eslint-disable-next-line react-hooks/exhaustive-deps
    useEffect(() => { loadData(); }, [timeRange]);

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

    if (loading) return <LoadingSpinner message="Loading dashboard..." fullPage />;

    const hasUserGrowth = userGrowth.length > 0 && userGrowth.some(i => i.count != null);
    const hasEventsByMonth = stats?.newEventsPerMonth?.length > 0 && stats.newEventsPerMonth.some(i => i.count != null);
    const hasEventsByCity = eventsByCity.length > 0 && eventsByCity.some(i => i.cityName && i.eventCount != null);
    const hasEventsByCategory = eventsByCategory.length > 0 && eventsByCategory.some(i => i.categoryName && i.eventCount > 0);

    return (
        <Box>
            <PageHeader
                title="Platform Overview"
                subtitle="Monitor growth, performance and health of the Luma network."
                actions={[
                    <FormControl key="range" size="small" sx={{ minWidth: 160 }}>
                        <InputLabel>Time range</InputLabel>
                        <Select
                            value={timeRange}
                            onChange={(e) => setTimeRange(e.target.value)}
                            label="Time range"
                        >
                            <MenuItem value={3}>Last 3 months</MenuItem>
                            <MenuItem value={6}>Last 6 months</MenuItem>
                            <MenuItem value={12}>Last 12 months</MenuItem>
                        </Select>
                    </FormControl>,
                    <Button
                        key="refresh"
                        startIcon={<RefreshIcon fontSize="small" />}
                        onClick={loadData}
                        variant="outlined"
                    >
                        Refresh
                    </Button>,
                ]}
            />

            <Grid container spacing={2} sx={{ mb: 3 }}>
                <Grid item xs={12} sm={6} lg={3}>
                    <StatCard
                        label="Total users"
                        value={stats?.totalUsers?.toLocaleString() || 0}
                        icon={<PeopleIcon />}
                        iconColor="primary"
                        change={stats?.userGrowthPercent}
                        changeLabel="vs. previous period"
                    />
                </Grid>
                <Grid item xs={12} sm={6} lg={3}>
                    <StatCard
                        label="Organisers"
                        value={stats?.totalOrganisers?.toLocaleString() || 0}
                        icon={<BusinessIcon />}
                        iconColor="success"
                        change={stats?.organiserGrowthPercent}
                        changeLabel="vs. previous period"
                    />
                </Grid>
                <Grid item xs={12} sm={6} lg={3}>
                    <StatCard
                        label="Total events"
                        value={stats?.totalEvents?.toLocaleString() || 0}
                        icon={<EventIcon />}
                        iconColor="warning"
                        change={stats?.eventGrowthPercent}
                        changeLabel="vs. previous period"
                    />
                </Grid>
                <Grid item xs={12} sm={6} lg={3}>
                    <StatCard
                        label="Registrations"
                        value={stats?.totalRegistrations?.toLocaleString() || 0}
                        icon={<RegistrationIcon />}
                        iconColor="info"
                        change={stats?.registrationGrowthPercent}
                        changeLabel="vs. previous period"
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
                                width: 38, height: 38, borderRadius: 2,
                                display: 'flex', alignItems: 'center', justifyContent: 'center',
                                bgcolor: 'secondary.100', color: 'secondary.700',
                            }}
                        >
                            <AIIcon />
                        </Box>
                        <Box>
                            <Typography variant="h3" sx={{ fontSize: '1rem' }}>
                                AI Platform Insights
                            </Typography>
                            <Typography variant="caption" color="text.secondary">
                                Spot trends and opportunities across the platform.
                            </Typography>
                        </Box>
                    </Box>
                    <Stack direction="row" spacing={1} alignItems="center">
                        {aiInsights && (
                            <Tooltip title={showInsights ? 'Collapse' : 'Expand'}>
                                <IconButton size="small" onClick={() => setShowInsights((v) => !v)}>
                                    {showInsights ? <ExpandLessIcon /> : <ExpandMoreIcon />}
                                </IconButton>
                            </Tooltip>
                        )}
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
                    </Stack>
                </Stack>

                {!aiInsights && !aiLoading && (
                    <Alert severity="info" sx={{ mt: 2, bgcolor: 'transparent', border: '1px dashed', borderColor: 'divider' }}>
                        <AlertTitle sx={{ fontSize: '0.875rem' }}>Get platform analytics</AlertTitle>
                        Click <b>Get AI insights</b> to analyse platform data and receive recommendations.
                    </Alert>
                )}

                <Collapse in={showInsights && Boolean(aiInsights)}>
                    {aiInsights && (
                        <Box sx={{ mt: 2 }}>
                            {aiInsights.summary && (
                                <Typography
                                    variant="body2"
                                    sx={{
                                        mb: 2, fontStyle: 'italic', color: 'text.secondary',
                                        px: 1.5, py: 1,
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

            <Grid container spacing={2} sx={{ mb: 2 }}>
                <Grid item xs={12} lg={6}>
                    <SectionCard title="User growth" subtitle="New users per period">
                        {hasUserGrowth ? (
                            <LineChart
                                xAxis={[{
                                    scaleType: 'band',
                                    data: userGrowth.map(item => `${item.month}/${item.year}`),
                                }]}
                                series={[{
                                    data: userGrowth.map(item => item.count || 0),
                                    color: tokens.palette.primary[500],
                                    area: true,
                                }]}
                                height={300}
                                sx={{
                                    ...CHART_AXIS_SX,
                                    '& .MuiAreaElement-root': { fillOpacity: 0.12 },
                                }}
                            />
                        ) : (
                            <EmptyState icon={<PeopleIcon sx={{ fontSize: 28 }} />} title="No data available" compact />
                        )}
                    </SectionCard>
                </Grid>
                <Grid item xs={12} lg={6}>
                    <SectionCard title="Events growth" subtitle="New events per period">
                        {hasEventsByMonth ? (
                            <BarChart
                                xAxis={[{
                                    scaleType: 'band',
                                    data: stats.newEventsPerMonth.map(item => `${item.month}/${item.year}`),
                                }]}
                                series={[{
                                    data: stats.newEventsPerMonth.map(item => item.count || 0),
                                    color: tokens.palette.success[500],
                                }]}
                                height={300}
                                sx={CHART_AXIS_SX}
                            />
                        ) : (
                            <EmptyState icon={<EventIcon sx={{ fontSize: 28 }} />} title="No data available" compact />
                        )}
                    </SectionCard>
                </Grid>
            </Grid>

            <Grid container spacing={2}>
                <Grid item xs={12} lg={6}>
                    <SectionCard title="Events by city" subtitle="Where events are being hosted">
                        {hasEventsByCity ? (
                            <BarChart
                                xAxis={[{
                                    scaleType: 'band',
                                    data: eventsByCity.filter(item => item.cityName).map(item => item.cityName),
                                }]}
                                series={[{
                                    data: eventsByCity.filter(item => item.cityName).map(item => item.eventCount || 0),
                                    color: tokens.palette.warning[500],
                                }]}
                                height={300}
                                sx={CHART_AXIS_SX}
                            />
                        ) : (
                            <EmptyState icon={<EventIcon sx={{ fontSize: 28 }} />} title="No data available" compact />
                        )}
                    </SectionCard>
                </Grid>
                <Grid item xs={12} lg={6}>
                    <SectionCard title="Events by category" subtitle="Distribution across categories">
                        {hasEventsByCategory ? (
                            <PieChart
                                series={[{
                                    data: eventsByCategory
                                        .filter(item => item.categoryName && item.eventCount > 0)
                                        .map((item, index) => ({
                                            id: index,
                                            value: item.eventCount,
                                            label: item.categoryName,
                                            color: PIE_COLORS[index % PIE_COLORS.length],
                                        })),
                                    highlightScope: { faded: 'global', highlighted: 'item' },
                                    innerRadius: 48,
                                    paddingAngle: 2,
                                    cornerRadius: 6,
                                }]}
                                height={300}
                            />
                        ) : (
                            <EmptyState icon={<EventIcon sx={{ fontSize: 28 }} />} title="No data available" compact />
                        )}
                    </SectionCard>
                </Grid>
            </Grid>
        </Box>
    );
};

export default AdminDashboard;

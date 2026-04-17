import React, { useState, useEffect } from 'react';
import {
    Box,
    Typography,
    Paper,
    Grid,
    Card,
    CardContent,
    Button,
    Autocomplete,
    TextField,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    LinearProgress,
    Stack,
} from '@mui/material';
import {
    Refresh as RefreshIcon,
    TrendingDown as DropOffIcon,
    Visibility as ViewIcon,
    AppRegistration as RegIcon,
    CheckCircle as ApprovedIcon,
    EventSeat as AttendedIcon,
    RateReview as ReviewIcon,
    FilterAlt as FunnelIcon,
} from '@mui/icons-material';
import { BarChart } from '@mui/x-charts/BarChart';
import { organiserApi } from '../../api';
import { toast } from 'react-toastify';
import {
    PageHeader,
    SectionCard,
    StatusChip,
    EmptyState,
} from '../../components/ui';
import { tokens } from '../../theme';

const stepIcons = {
    Views: <ViewIcon />,
    Registrations: <RegIcon />,
    Approved: <ApprovedIcon />,
    Attended: <AttendedIcon />,
    Reviewed: <ReviewIcon />,
};

const STEP_COLORS = [
    tokens.palette.info[500],
    tokens.palette.primary[500],
    tokens.palette.success[500],
    tokens.palette.warning[500],
    tokens.palette.danger[500],
];

const conversionVariant = (value) =>
    value >= 50 ? 'success' : value >= 20 ? 'warning' : 'danger';

const OrganiserFunnelAnalytics = () => {
    const [funnel, setFunnel] = useState(null);
    const [events, setEvents] = useState([]);
    const [selectedEvent, setSelectedEvent] = useState(null);
    const [loading, setLoading] = useState(false);

    useEffect(() => {
        loadEvents();
        loadFunnel();
    }, []);

    const loadEvents = async () => {
        try {
            const response = await organiserApi.getMyEvents({ page: 0, size: 100 });
            setEvents(response.data.data.content || []);
        } catch (error) {
            console.error('Failed to load events:', error);
        }
    };

    const loadFunnel = async (eventId = null) => {
        setLoading(true);
        try {
            const response = eventId
                ? await organiserApi.getEventFunnel(eventId)
                : await organiserApi.getFunnelAnalytics();
            setFunnel(response.data.data);
        } catch (error) {
            toast.error('Failed to load funnel data');
        } finally {
            setLoading(false);
        }
    };

    const handleEventChange = (_, newValue) => {
        setSelectedEvent(newValue);
        loadFunnel(newValue?.id || null);
    };

    const funnelChartData = funnel?.steps?.map((step, i) => ({
        name: step.name,
        count: step.count,
        color: STEP_COLORS[i],
    })) || [];

    return (
        <Box>
            <PageHeader
                title="Conversion Funnel"
                subtitle="Track how users move through the registration lifecycle."
                icon={<FunnelIcon />}
                actions={
                    <Button
                        startIcon={<RefreshIcon fontSize="small" />}
                        onClick={() => loadFunnel(selectedEvent?.id)}
                        variant="outlined"
                    >
                        Refresh
                    </Button>
                }
            />

            <SectionCard sx={{ mb: 2 }}>
                <Autocomplete
                    options={events}
                    getOptionLabel={(option) => option.title || ''}
                    value={selectedEvent}
                    onChange={handleEventChange}
                    renderInput={(params) => (
                        <TextField {...params} label="Filter by event (leave empty for all)" />
                    )}
                    isOptionEqualToValue={(option, value) => option.id === value.id}
                    sx={{ maxWidth: 520 }}
                />
            </SectionCard>

            {loading ? (
                <LinearProgress />
            ) : funnel ? (
                <>
                    <Grid container spacing={2} sx={{ mb: 2 }}>
                        {funnel.steps?.map((step, index) => (
                            <Grid item xs={12} sm={6} md={4} lg={12 / 5} key={step.name}>
                                <Card sx={{ borderTop: '3px solid', borderColor: STEP_COLORS[index] }}>
                                    <CardContent sx={{ textAlign: 'center', py: 2.5 }}>
                                        <Box
                                            sx={{
                                                width: 40,
                                                height: 40,
                                                borderRadius: 2,
                                                display: 'flex',
                                                alignItems: 'center',
                                                justifyContent: 'center',
                                                bgcolor: STEP_COLORS[index] + '20',
                                                color: STEP_COLORS[index],
                                                mx: 'auto',
                                                mb: 1.5,
                                            }}
                                        >
                                            {stepIcons[step.name]}
                                        </Box>
                                        <Typography variant="h1" sx={{ fontSize: '1.5rem', mb: 0.25 }}>
                                            {step.count.toLocaleString()}
                                        </Typography>
                                        <Typography variant="caption" color="text.secondary" sx={{ fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                                            {step.name}
                                        </Typography>
                                        {index > 0 && (
                                            <Box sx={{ mt: 1.25 }}>
                                                <StatusChip
                                                    icon={<DropOffIcon sx={{ fontSize: 12 }} />}
                                                    label={`${step.percentage.toFixed(1)}%`}
                                                    status={conversionVariant(step.percentage)}
                                                />
                                            </Box>
                                        )}
                                    </CardContent>
                                </Card>
                            </Grid>
                        ))}
                    </Grid>

                    <Grid container spacing={2} sx={{ mb: 2 }}>
                        <Grid item xs={12} md={8}>
                            <SectionCard title="Funnel visualisation" subtitle="Absolute counts at each step">
                                <BarChart
                                    height={320}
                                    series={[{
                                        data: funnelChartData.map((d) => d.count),
                                        color: tokens.palette.primary[500],
                                    }]}
                                    xAxis={[{
                                        data: funnelChartData.map((d) => d.name),
                                        scaleType: 'band',
                                    }]}
                                    sx={{
                                        '& .MuiChartsAxis-line': { stroke: tokens.palette.neutral[200] },
                                        '& .MuiChartsAxis-tick': { stroke: tokens.palette.neutral[200] },
                                    }}
                                />
                            </SectionCard>
                        </Grid>
                        <Grid item xs={12} md={4}>
                            <SectionCard title="Conversion rates" subtitle="Step-by-step conversion">
                                <Stack spacing={1.75}>
                                    {[
                                        { label: 'View → Register', value: funnel.viewToRegistrationRate ?? 0 },
                                        { label: 'Register → Approved', value: funnel.registrationToApprovedRate ?? 0 },
                                        { label: 'Approved → Attended', value: funnel.approvedToAttendedRate ?? 0 },
                                        { label: 'Attended → Reviewed', value: funnel.attendedToReviewedRate ?? 0 },
                                    ].map((rate) => (
                                        <Box key={rate.label}>
                                            <Stack direction="row" justifyContent="space-between" sx={{ mb: 0.5 }}>
                                                <Typography variant="caption" color="text.secondary">{rate.label}</Typography>
                                                <Typography variant="caption" sx={{ fontWeight: 600 }}>
                                                    {rate.value.toFixed(1)}%
                                                </Typography>
                                            </Stack>
                                            <LinearProgress
                                                variant="determinate"
                                                value={Math.min(rate.value, 100)}
                                                sx={{ height: 6 }}
                                            />
                                        </Box>
                                    ))}
                                </Stack>
                                <Paper variant="outlined" sx={{ mt: 2.5, p: 2, bgcolor: 'primary.50', borderColor: 'primary.100' }}>
                                    <Typography variant="caption" color="text.secondary" sx={{ fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                                        Overall conversion
                                    </Typography>
                                    <Typography variant="h1" color="primary.700" sx={{ fontSize: '1.75rem', mt: 0.5 }}>
                                        {(funnel.overallConversionRate ?? 0).toFixed(1)}%
                                    </Typography>
                                    <Typography variant="caption" color="text.secondary">
                                        View → Attended
                                    </Typography>
                                </Paper>
                            </SectionCard>
                        </Grid>
                    </Grid>

                    {funnel.eventFunnels && funnel.eventFunnels.length > 0 && (
                        <SectionCard title="Event breakdown" subtitle="Funnel data per event" contentSx={{ px: 0 }}>
                            <TableContainer>
                                <Table size="small">
                                    <TableHead>
                                        <TableRow>
                                            <TableCell>Event</TableCell>
                                            <TableCell align="right">Views</TableCell>
                                            <TableCell align="right">Registrations</TableCell>
                                            <TableCell align="right">Approved</TableCell>
                                            <TableCell align="right">Attended</TableCell>
                                            <TableCell align="right">Reviewed</TableCell>
                                            <TableCell align="right">Conversion</TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {funnel.eventFunnels.map((ef) => (
                                            <TableRow key={ef.eventId} hover>
                                                <TableCell>
                                                    <Typography variant="body2" noWrap sx={{ maxWidth: 260, fontWeight: 500 }}>
                                                        {ef.eventTitle}
                                                    </Typography>
                                                </TableCell>
                                                <TableCell align="right">{ef.views}</TableCell>
                                                <TableCell align="right">{ef.registrations}</TableCell>
                                                <TableCell align="right">{ef.approved}</TableCell>
                                                <TableCell align="right">{ef.attended}</TableCell>
                                                <TableCell align="right">{ef.reviewed}</TableCell>
                                                <TableCell align="right">
                                                    <StatusChip
                                                        label={`${ef.conversionRate.toFixed(1)}%`}
                                                        status={conversionVariant(ef.conversionRate)}
                                                    />
                                                </TableCell>
                                            </TableRow>
                                        ))}
                                    </TableBody>
                                </Table>
                            </TableContainer>
                        </SectionCard>
                    )}
                </>
            ) : (
                <SectionCard>
                    <EmptyState
                        icon={<FunnelIcon sx={{ fontSize: 28 }} />}
                        title="No funnel data yet"
                        description="Once attendees start interacting with your events, their journey will appear here."
                    />
                </SectionCard>
            )}
        </Box>
    );
};

export default OrganiserFunnelAnalytics;

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
    Chip,
    LinearProgress,
} from '@mui/material';
import {
    Refresh as RefreshIcon,
    TrendingDown as DropOffIcon,
    Visibility as ViewIcon,
    AppRegistration as RegIcon,
    CheckCircle as ApprovedIcon,
    EventSeat as AttendedIcon,
    RateReview as ReviewIcon,
} from '@mui/icons-material';
import { BarChart } from '@mui/x-charts/BarChart';
import { organiserApi } from '../../api';
import { toast } from 'react-toastify';

const stepIcons = {
    'Views': <ViewIcon />,
    'Registrations': <RegIcon />,
    'Approved': <ApprovedIcon />,
    'Attended': <AttendedIcon />,
    'Reviewed': <ReviewIcon />,
};

const stepColors = ['#3B82F6', '#8B5CF6', '#10B981', '#F59E0B', '#EF4444'];

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
        color: stepColors[i],
    })) || [];

    return (
        <Box>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                <Typography variant="h5" fontWeight="bold">
                    Conversion Funnel
                </Typography>
                <Button startIcon={<RefreshIcon />} onClick={() => loadFunnel(selectedEvent?.id)}>
                    Refresh
                </Button>
            </Box>

            <Paper sx={{ p: 2, mb: 3 }}>
                <Autocomplete
                    options={events}
                    getOptionLabel={(option) => option.title || ''}
                    value={selectedEvent}
                    onChange={handleEventChange}
                    renderInput={(params) => (
                        <TextField {...params} label="Filter by Event (leave empty for all)" />
                    )}
                    isOptionEqualToValue={(option, value) => option.id === value.id}
                    sx={{ minWidth: 400 }}
                />
            </Paper>

            {loading ? (
                <LinearProgress />
            ) : funnel ? (
                <>
                    <Grid container spacing={2} sx={{ mb: 3 }}>
                        {funnel.steps?.map((step, index) => (
                            <Grid item xs={12} sm={6} md={2.4} key={step.name}>
                                <Card variant="outlined" sx={{
                                    borderTop: 3,
                                    borderColor: stepColors[index],
                                }}>
                                    <CardContent sx={{ textAlign: 'center', py: 2 }}>
                                        <Box sx={{ color: stepColors[index], mb: 1 }}>
                                            {stepIcons[step.name]}
                                        </Box>
                                        <Typography variant="h4" fontWeight="bold">
                                            {step.count.toLocaleString()}
                                        </Typography>
                                        <Typography variant="body2" color="text.secondary">
                                            {step.name}
                                        </Typography>
                                        {index > 0 && (
                                            <Chip
                                                icon={<DropOffIcon sx={{ fontSize: 14 }} />}
                                                label={`${step.percentage.toFixed(1)}%`}
                                                size="small"
                                                color={step.percentage >= 50 ? 'success' : step.percentage >= 20 ? 'warning' : 'error'}
                                                sx={{ mt: 1 }}
                                            />
                                        )}
                                    </CardContent>
                                </Card>
                            </Grid>
                        ))}
                    </Grid>

                    <Grid container spacing={3} sx={{ mb: 3 }}>
                        <Grid item xs={12} md={8}>
                            <Paper sx={{ p: 3 }}>
                                <Typography variant="h6" gutterBottom>Funnel Visualization</Typography>
                                <BarChart
                                    height={300}
                                    layout="horizontal"
                                    series={[{
                                        data: funnelChartData.map(d => d.count),
                                        color: '#3B82F6',
                                    }]}
                                    xAxis={[{
                                        data: funnelChartData.map(d => d.name),
                                        scaleType: 'band',
                                    }]}
                                />
                            </Paper>
                        </Grid>
                        <Grid item xs={12} md={4}>
                            <Paper sx={{ p: 3 }}>
                                <Typography variant="h6" gutterBottom>Conversion Rates</Typography>
                                <Box sx={{ mt: 2 }}>
                                    {[
                                        { label: 'View → Register', value: funnel.viewToRegistrationRate },
                                        { label: 'Register → Approved', value: funnel.registrationToApprovedRate },
                                        { label: 'Approved → Attended', value: funnel.approvedToAttendedRate },
                                        { label: 'Attended → Reviewed', value: funnel.attendedToReviewedRate },
                                    ].map((rate) => (
                                        <Box key={rate.label} sx={{ mb: 2 }}>
                                            <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 0.5 }}>
                                                <Typography variant="body2">{rate.label}</Typography>
                                                <Typography variant="body2" fontWeight="bold">
                                                    {rate.value.toFixed(1)}%
                                                </Typography>
                                            </Box>
                                            <LinearProgress
                                                variant="determinate"
                                                value={Math.min(rate.value, 100)}
                                                sx={{
                                                    height: 8,
                                                    borderRadius: 4,
                                                    backgroundColor: 'grey.200',
                                                }}
                                            />
                                        </Box>
                                    ))}
                                    <Box sx={{ mt: 3, p: 2, bgcolor: 'primary.50', borderRadius: 2 }}>
                                        <Typography variant="body2" color="text.secondary">
                                            Overall Conversion (View → Attended)
                                        </Typography>
                                        <Typography variant="h4" color="primary" fontWeight="bold">
                                            {funnel.overallConversionRate.toFixed(1)}%
                                        </Typography>
                                    </Box>
                                </Box>
                            </Paper>
                        </Grid>
                    </Grid>

                    {funnel.eventFunnels && funnel.eventFunnels.length > 0 && (
                        <Paper sx={{ p: 3 }}>
                            <Typography variant="h6" gutterBottom>Event Breakdown</Typography>
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
                                                    <Typography variant="body2" noWrap sx={{ maxWidth: 250 }}>
                                                        {ef.eventTitle}
                                                    </Typography>
                                                </TableCell>
                                                <TableCell align="right">{ef.views}</TableCell>
                                                <TableCell align="right">{ef.registrations}</TableCell>
                                                <TableCell align="right">{ef.approved}</TableCell>
                                                <TableCell align="right">{ef.attended}</TableCell>
                                                <TableCell align="right">{ef.reviewed}</TableCell>
                                                <TableCell align="right">
                                                    <Chip
                                                        label={`${ef.conversionRate.toFixed(1)}%`}
                                                        size="small"
                                                        color={ef.conversionRate >= 50 ? 'success' : ef.conversionRate >= 20 ? 'warning' : 'default'}
                                                    />
                                                </TableCell>
                                            </TableRow>
                                        ))}
                                    </TableBody>
                                </Table>
                            </TableContainer>
                        </Paper>
                    )}
                </>
            ) : (
                <Paper sx={{ p: 4, textAlign: 'center' }}>
                    <Typography color="text.secondary">No funnel data available yet</Typography>
                </Paper>
            )}
        </Box>
    );
};

export default OrganiserFunnelAnalytics;

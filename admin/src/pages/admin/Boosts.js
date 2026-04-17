import React, { useState, useEffect } from 'react';
import {
    Box,
    Paper,
    Typography,
    Tabs,
    Tab,
    Avatar,
    Stack,
    IconButton,
    Tooltip,
    Grid,
} from '@mui/material';
import {
    Refresh as RefreshIcon,
    Rocket as RocketIcon,
    Star as StarIcon,
    Home as HomeIcon,
    TrendingUp as TrendingUpIcon,
} from '@mui/icons-material';
import adminApi from '../../api/adminApi';
import { toast } from 'react-toastify';
import {
    PageHeader,
    StatCard,
    StatusChip,
    DataTableCard,
} from '../../components/ui';
import { tokens } from '../../theme';

const AdminBoosts = () => {
    const [loading, setLoading] = useState(true);
    const [boosts, setBoosts] = useState([]);
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(10);
    const [totalElements, setTotalElements] = useState(0);
    const [tabValue, setTabValue] = useState(0);
    const [stats, setStats] = useState({ totalActive: 0, totalFeatured: 0, totalHomeBanner: 0 });

    const statusMap = [null, 'PENDING', 'ACTIVE', 'EXPIRED', 'CANCELLED'];

    useEffect(() => {
        loadData();
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [page, rowsPerPage, tabValue]);

    const loadData = async () => {
        try {
            setLoading(true);
            const status = statusMap[tabValue];
            const params = { page, size: rowsPerPage };
            if (status) params.status = status;

            const [boostsRes, statsRes] = await Promise.all([
                adminApi.getBoosts(params),
                adminApi.getBoostStats(),
            ]);
            setBoosts(boostsRes.data?.data?.content || []);
            setTotalElements(boostsRes.data?.data?.totalElements || 0);
            setStats(statsRes.data?.data || { totalActive: 0, totalFeatured: 0, totalHomeBanner: 0 });
        } catch (error) {
            toast.error('Failed to load data');
        } finally {
            setLoading(false);
        }
    };

    const formatCurrency = (value) =>
        new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(value || 0);

    const statusConfig = {
        PENDING: { label: 'Pending Payment', status: 'warning' },
        ACTIVE: { label: 'Active', status: 'success' },
        EXPIRED: { label: 'Expired', status: 'neutral' },
        CANCELLED: { label: 'Cancelled', status: 'danger' },
    };

    const packageConfig = {
        BASIC: { label: 'Basic', status: 'neutral' },
        STANDARD: { label: 'Standard', status: 'info' },
        PREMIUM: { label: 'Premium', status: 'warning' },
        VIP: { label: 'VIP', status: 'danger' },
    };

    const columns = [
        {
            field: 'event',
            headerName: 'Event',
            flex: 1.6,
            minWidth: 240,
            sortable: false,
            renderCell: (params) => (
                <Stack direction="row" alignItems="center" spacing={1.5} sx={{ py: 1 }}>
                    <Avatar
                        src={params.row.eventImageUrl}
                        variant="rounded"
                        sx={{ width: 40, height: 40 }}
                    />
                    <Typography variant="body2" fontWeight={600} noWrap sx={{ maxWidth: 220 }}>
                        {params.row.eventTitle}
                    </Typography>
                </Stack>
            ),
        },
        {
            field: 'boostPackage',
            headerName: 'Package',
            width: 120,
            renderCell: (params) => {
                const cfg = packageConfig[params.value] || { label: params.value, status: 'neutral' };
                return <StatusChip label={cfg.label} status={cfg.status} />;
            },
        },
        {
            field: 'amount',
            headerName: 'Amount',
            width: 120,
            renderCell: (params) => (
                <Typography variant="body2" fontWeight={600}>
                    {formatCurrency(params.value)}
                </Typography>
            ),
        },
        {
            field: 'status',
            headerName: 'Status',
            width: 150,
            renderCell: (params) => {
                const cfg = statusConfig[params.value] || { label: params.value, status: 'neutral' };
                return <StatusChip label={cfg.label} status={cfg.status} />;
            },
        },
        {
            field: 'duration',
            headerName: 'Duration',
            flex: 1,
            minWidth: 200,
            sortable: false,
            renderCell: (params) => (
                <Typography variant="caption" color="text.secondary">
                    {params.row.startTime ? new Date(params.row.startTime).toLocaleDateString('en-US') : '-'}
                    {' → '}
                    {params.row.endTime ? new Date(params.row.endTime).toLocaleDateString('en-US') : '-'}
                </Typography>
            ),
        },
        {
            field: 'remaining',
            headerName: 'Remaining',
            width: 120,
            sortable: false,
            renderCell: (params) =>
                params.row.isActive ? (
                    <StatusChip label={`${params.row.daysRemaining} days`} status="success" />
                ) : (
                    <Typography variant="caption" color="text.disabled">-</Typography>
                ),
        },
        {
            field: 'performance',
            headerName: 'Performance',
            flex: 1,
            minWidth: 180,
            sortable: false,
            renderCell: (params) => (
                <Box sx={{ py: 0.5 }}>
                    <Typography variant="caption" display="block" color="text.secondary">
                        Views: <strong>+{params.row.viewsDuringBoost}</strong>
                    </Typography>
                    <Typography variant="caption" display="block" color="text.secondary">
                        Regs: <strong>+{params.row.registrationsDuringBoost}</strong>
                    </Typography>
                    <Typography
                        variant="caption"
                        display="block"
                        sx={{ color: tokens.palette.success[600], fontWeight: 600 }}
                    >
                        CVR: {params.row.conversionRate?.toFixed(1)}%
                    </Typography>
                </Box>
            ),
        },
    ];

    return (
        <Box>
            <PageHeader
                title="Boost Management"
                subtitle="Monitor boosted events and their performance"
                icon={<RocketIcon />}
                actions={
                    <Tooltip title="Refresh">
                        <IconButton onClick={loadData} color="primary" aria-label="refresh boosts">
                            <RefreshIcon />
                        </IconButton>
                    </Tooltip>
                }
            />

            <Grid container spacing={2} sx={{ mb: 3 }}>
                <Grid item xs={12} sm={4}>
                    <StatCard
                        label="Active Boosts"
                        value={stats.totalActive}
                        icon={<RocketIcon />}
                        iconColor="success"
                        helper="Running right now"
                    />
                </Grid>
                <Grid item xs={12} sm={4}>
                    <StatCard
                        label="Featured Events"
                        value={stats.totalFeatured}
                        icon={<StarIcon />}
                        iconColor="warning"
                        helper="Highlighted in feed"
                    />
                </Grid>
                <Grid item xs={12} sm={4}>
                    <StatCard
                        label="Home Banner"
                        value={stats.totalHomeBanner}
                        icon={<HomeIcon />}
                        iconColor="primary"
                        helper="On landing page"
                    />
                </Grid>
            </Grid>

            <Paper sx={{ mb: 2, borderRadius: 2 }}>
                <Tabs
                    value={tabValue}
                    onChange={(e, v) => {
                        setTabValue(v);
                        setPage(0);
                    }}
                    sx={{ px: 2 }}
                >
                    <Tab label="All" />
                    <Tab label="Pending Payment" />
                    <Tab label="Active" />
                    <Tab label="Expired" />
                    <Tab label="Cancelled" />
                </Tabs>
            </Paper>

            <DataTableCard
                rows={boosts}
                columns={columns}
                loading={loading}
                emptyIcon={<TrendingUpIcon sx={{ fontSize: 32 }} />}
                emptyTitle="No boosts found"
                emptyDescription="Nothing to show with the current filter. Try switching tabs."
                dataGridProps={{
                    autoHeight: true,
                    paginationMode: 'server',
                    rowCount: totalElements,
                    paginationModel: { page, pageSize: rowsPerPage },
                    onPaginationModelChange: (model) => {
                        setPage(model.page);
                        setRowsPerPage(model.pageSize);
                    },
                    pageSizeOptions: [5, 10, 25],
                    rowHeight: 72,
                    disableColumnMenu: true,
                }}
            />
        </Box>
    );
};

export default AdminBoosts;

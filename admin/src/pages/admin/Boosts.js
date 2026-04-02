import React, { useState, useEffect } from 'react';
import {
    Box,
    Paper,
    Typography,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    TablePagination,
    Chip,
    IconButton,
    Tooltip,
    Card,
    CardContent,
    Grid,
    Tabs,
    Tab,
    Avatar,
} from '@mui/material';
import {
    Refresh as RefreshIcon,
    TrendingUp as TrendingUpIcon,
    Rocket as RocketIcon,
    Star as StarIcon,
    Home as HomeIcon,
} from '@mui/icons-material';
import adminApi from '../../api/adminApi';
import { LoadingSpinner } from '../../components/common';
import { toast } from 'react-toastify';

const StatCard = ({ title, value, subtitle, icon, color }) => (
    <Card sx={{ height: '100%' }}>
        <CardContent>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <Box>
                    <Typography variant="body2" color="text.secondary">{title}</Typography>
                    <Typography variant="h4" fontWeight="bold">{value}</Typography>
                    {subtitle && (
                        <Typography variant="caption" color="text.secondary">{subtitle}</Typography>
                    )}
                </Box>
                <Box sx={{ p: 1.5, borderRadius: 2, bgcolor: `${color}15`, color }}>
                    {icon}
                </Box>
            </Box>
        </CardContent>
    </Card>
);

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
            toast.error('Không thể tải dữ liệu');
        } finally {
            setLoading(false);
        }
    };

    const getStatusChip = (status) => {
        const config = {
            PENDING: { label: 'Chờ thanh toán', color: 'warning' },
            ACTIVE: { label: 'Đang hoạt động', color: 'success' },
            EXPIRED: { label: 'Đã hết hạn', color: 'default' },
            CANCELLED: { label: 'Đã hủy', color: 'error' },
        };
        const c = config[status] || { label: status, color: 'default' };
        return <Chip label={c.label} color={c.color} size="small" />;
    };

    const getPackageChip = (pkg) => {
        const config = {
            BASIC: { label: 'Basic', color: 'default' },
            STANDARD: { label: 'Standard', color: 'info' },
            PREMIUM: { label: 'Premium', color: 'warning' },
            VIP: { label: 'VIP', color: 'error' },
        };
        const c = config[pkg] || { label: pkg, color: 'default' };
        return <Chip label={c.label} color={c.color} size="small" variant="outlined" />;
    };

    const formatCurrency = (value) => {
        return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(value || 0);
    };

    if (loading && boosts.length === 0) {
        return <LoadingSpinner message="Đang tải..." />;
    }

    return (
        <Box className="dashboard">
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                <Box>
                    <Typography variant="h4" fontWeight="bold">Quản lý Boost</Typography>
                    <Typography variant="body2" color="text.secondary">
                        Theo dõi các sự kiện được đẩy tin
                    </Typography>
                </Box>
                <Tooltip title="Làm mới">
                    <IconButton onClick={loadData} color="primary">
                        <RefreshIcon />
                    </IconButton>
                </Tooltip>
            </Box>

            <Grid container spacing={3} sx={{ mb: 3 }}>
                <Grid item xs={12} sm={4}>
                    <StatCard
                        title="Đang hoạt động"
                        value={stats.totalActive}
                        icon={<RocketIcon />}
                        color="success.main"
                    />
                </Grid>
                <Grid item xs={12} sm={4}>
                    <StatCard
                        title="Featured Events"
                        value={stats.totalFeatured}
                        icon={<StarIcon />}
                        color="warning.main"
                    />
                </Grid>
                <Grid item xs={12} sm={4}>
                    <StatCard
                        title="Home Banner"
                        value={stats.totalHomeBanner}
                        icon={<HomeIcon />}
                        color="primary.main"
                    />
                </Grid>
            </Grid>

            <Paper sx={{ mb: 2 }}>
                <Tabs value={tabValue} onChange={(e, v) => { setTabValue(v); setPage(0); }}>
                    <Tab label="Tất cả" />
                    <Tab label="Chờ thanh toán" />
                    <Tab label="Đang hoạt động" />
                    <Tab label="Đã hết hạn" />
                    <Tab label="Đã hủy" />
                </Tabs>
            </Paper>

            <Paper sx={{ p: 2 }}>
                <TableContainer>
                    <Table>
                        <TableHead>
                            <TableRow>
                                <TableCell>Sự kiện</TableCell>
                                <TableCell>Gói</TableCell>
                                <TableCell>Số tiền</TableCell>
                                <TableCell>Trạng thái</TableCell>
                                <TableCell>Thời gian</TableCell>
                                <TableCell>Còn lại</TableCell>
                                <TableCell>Hiệu quả</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {boosts.map((boost) => (
                                <TableRow key={boost.id} hover>
                                    <TableCell>
                                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                            <Avatar
                                                src={boost.eventImageUrl}
                                                variant="rounded"
                                                sx={{ width: 40, height: 40 }}
                                            />
                                            <Typography variant="body2" fontWeight="medium" noWrap sx={{ maxWidth: 200 }}>
                                                {boost.eventTitle}
                                            </Typography>
                                        </Box>
                                    </TableCell>
                                    <TableCell>{getPackageChip(boost.boostPackage)}</TableCell>
                                    <TableCell>{formatCurrency(boost.amount)}</TableCell>
                                    <TableCell>{getStatusChip(boost.status)}</TableCell>
                                    <TableCell>
                                        <Typography variant="caption" color="text.secondary">
                                            {boost.startTime ? new Date(boost.startTime).toLocaleDateString('vi-VN') : '-'}
                                            {' → '}
                                            {boost.endTime ? new Date(boost.endTime).toLocaleDateString('vi-VN') : '-'}
                                        </Typography>
                                    </TableCell>
                                    <TableCell>
                                        {boost.isActive ? (
                                            <Chip label={`${boost.daysRemaining} ngày`} size="small" color="success" />
                                        ) : '-'}
                                    </TableCell>
                                    <TableCell>
                                        <Box>
                                            <Typography variant="caption" display="block">
                                                Views: +{boost.viewsDuringBoost}
                                            </Typography>
                                            <Typography variant="caption" display="block">
                                                Regs: +{boost.registrationsDuringBoost}
                                            </Typography>
                                            <Typography variant="caption" color="success.main">
                                                CVR: {boost.conversionRate?.toFixed(1)}%
                                            </Typography>
                                        </Box>
                                    </TableCell>
                                </TableRow>
                            ))}
                            {boosts.length === 0 && (
                                <TableRow>
                                    <TableCell colSpan={7} align="center" sx={{ py: 4 }}>
                                        <Typography color="text.secondary">Không có dữ liệu</Typography>
                                    </TableCell>
                                </TableRow>
                            )}
                        </TableBody>
                    </Table>
                </TableContainer>
                <TablePagination
                    component="div"
                    count={totalElements}
                    page={page}
                    onPageChange={(e, p) => setPage(p)}
                    rowsPerPage={rowsPerPage}
                    onRowsPerPageChange={(e) => { setRowsPerPage(parseInt(e.target.value)); setPage(0); }}
                    rowsPerPageOptions={[5, 10, 25]}
                    labelRowsPerPage="Số dòng:"
                />
            </Paper>
        </Box>
    );
};

export default AdminBoosts;

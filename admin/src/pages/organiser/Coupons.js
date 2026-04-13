import React, { useState, useEffect } from 'react';
import {
    Box, Typography, Paper, Button, Chip, Dialog, DialogTitle, DialogContent,
    DialogActions, TextField, Grid, Select, MenuItem, FormControl, InputLabel,
    IconButton, Tooltip,
} from '@mui/material';
import { DataGrid } from '@mui/x-data-grid';
import {
    Add as AddIcon, Refresh as RefreshIcon, Block as DisableIcon,
    LocalOffer as CouponIcon,
} from '@mui/icons-material';
import { organiserApi } from '../../api';
import { toast } from 'react-toastify';

const OrganiserCoupons = () => {
    const [coupons, setCoupons] = useState([]);
    const [loading, setLoading] = useState(false);
    const [createDialog, setCreateDialog] = useState(false);
    const [paginationModel, setPaginationModel] = useState({ page: 0, pageSize: 10 });
    const [totalRows, setTotalRows] = useState(0);
    const [form, setForm] = useState({
        code: '', description: '', discountType: 'PERCENTAGE', discountValue: '',
        maxDiscountAmount: '', minOrderAmount: '', maxUsageCount: 0, maxUsagePerUser: '',
        validFrom: '', validUntil: '',
    });

    const loadCoupons = async () => {
        setLoading(true);
        try {
            const res = await organiserApi.getCoupons({ page: paginationModel.page, size: paginationModel.pageSize });
            setCoupons(res.data.data.content || []);
            setTotalRows(res.data.data.totalElements || 0);
        } catch { toast.error('Failed to load coupons'); }
        finally { setLoading(false); }
    };

    useEffect(() => { loadCoupons(); }, [paginationModel]);

    const handleCreate = async () => {
        if (!form.code.trim()) { toast.error('Coupon code is required'); return; }
        const dv = parseFloat(form.discountValue);
        if (!dv || dv <= 0) { toast.error('Discount value must be greater than 0'); return; }
        if (form.discountType === 'PERCENTAGE' && dv > 100) { toast.error('Percentage cannot exceed 100%'); return; }
        if (form.validFrom && form.validUntil && new Date(form.validFrom) >= new Date(form.validUntil)) {
            toast.error('Valid From must be before Valid Until'); return;
        }
        try {
            const data = { ...form, discountValue: dv };
            if (form.maxDiscountAmount) data.maxDiscountAmount = parseFloat(form.maxDiscountAmount);
            if (form.minOrderAmount) data.minOrderAmount = parseFloat(form.minOrderAmount);
            if (form.maxUsagePerUser) data.maxUsagePerUser = parseInt(form.maxUsagePerUser);
            if (form.validFrom) data.validFrom = new Date(form.validFrom).toISOString();
            if (form.validUntil) data.validUntil = new Date(form.validUntil).toISOString();
            await organiserApi.createCoupon(data);
            toast.success('Coupon created!');
            setCreateDialog(false);
            setForm({ code: '', description: '', discountType: 'PERCENTAGE', discountValue: '', maxDiscountAmount: '', minOrderAmount: '', maxUsageCount: 0, maxUsagePerUser: '', validFrom: '', validUntil: '' });
            loadCoupons();
        } catch (e) { toast.error(e.response?.data?.message || 'Failed to create coupon'); }
    };

    const handleDisable = async (id) => {
        try { await organiserApi.disableCoupon(id); toast.success('Coupon disabled'); loadCoupons(); }
        catch { toast.error('Failed'); }
    };

    const columns = [
        { field: 'code', headerName: 'Code', width: 130, renderCell: (p) => <Chip icon={<CouponIcon />} label={p.value} size="small" color="primary" /> },
        { field: 'discountType', headerName: 'Type', width: 120, renderCell: (p) => p.value === 'PERCENTAGE' ? `${p.row.discountValue}%` : `$${p.row.discountValue}` },
        { field: 'status', headerName: 'Status', width: 100, renderCell: (p) => <Chip label={p.value} size="small" color={p.value === 'ACTIVE' ? 'success' : 'default'} /> },
        { field: 'usedCount', headerName: 'Used', width: 80, renderCell: (p) => `${p.value}${p.row.maxUsageCount > 0 ? '/' + p.row.maxUsageCount : ''}` },
        { field: 'validUntil', headerName: 'Expires', width: 150, valueFormatter: (p) => p.value ? new Date(p.value).toLocaleDateString() : 'No expiry' },
        { field: 'actions', headerName: '', width: 80, sortable: false, renderCell: (p) => p.row.status === 'ACTIVE' ? (
            <Tooltip title="Disable"><IconButton size="small" color="error" onClick={() => handleDisable(p.row.id)}><DisableIcon /></IconButton></Tooltip>
        ) : null },
    ];

    return (
        <Box>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 3 }}>
                <Typography variant="h5" fontWeight="bold"><CouponIcon sx={{ mr: 1, verticalAlign: 'middle' }} />Coupons</Typography>
                <Box sx={{ display: 'flex', gap: 1 }}>
                    <Button startIcon={<RefreshIcon />} onClick={loadCoupons}>Refresh</Button>
                    <Button variant="contained" startIcon={<AddIcon />} onClick={() => setCreateDialog(true)}>Create Coupon</Button>
                </Box>
            </Box>
            <Paper>
                <DataGrid rows={coupons} columns={columns} loading={loading} paginationModel={paginationModel}
                    onPaginationModelChange={setPaginationModel} pageSizeOptions={[10, 25]} rowCount={totalRows}
                    paginationMode="server" disableRowSelectionOnClick autoHeight />
            </Paper>

            <Dialog open={createDialog} onClose={() => setCreateDialog(false)} maxWidth="sm" fullWidth>
                <DialogTitle>Create Coupon</DialogTitle>
                <DialogContent>
                    <Grid container spacing={2} sx={{ mt: 0.5 }}>
                        <Grid item xs={6}>
                            <TextField fullWidth label="Code" value={form.code} onChange={(e) => setForm({ ...form, code: e.target.value.toUpperCase() })} />
                        </Grid>
                        <Grid item xs={6}>
                            <FormControl fullWidth>
                                <InputLabel>Type</InputLabel>
                                <Select value={form.discountType} label="Type" onChange={(e) => setForm({ ...form, discountType: e.target.value })}>
                                    <MenuItem value="PERCENTAGE">Percentage (%)</MenuItem>
                                    <MenuItem value="FIXED_AMOUNT">Fixed Amount</MenuItem>
                                </Select>
                            </FormControl>
                        </Grid>
                        <Grid item xs={6}>
                            <TextField fullWidth type="number" label={form.discountType === 'PERCENTAGE' ? 'Discount %' : 'Discount Amount'} value={form.discountValue} onChange={(e) => setForm({ ...form, discountValue: e.target.value })} />
                        </Grid>
                        <Grid item xs={6}>
                            <TextField fullWidth type="number" label="Max Discount Amount" value={form.maxDiscountAmount} onChange={(e) => setForm({ ...form, maxDiscountAmount: e.target.value })} />
                        </Grid>
                        <Grid item xs={6}>
                            <TextField fullWidth type="number" label="Min Order Amount" value={form.minOrderAmount} onChange={(e) => setForm({ ...form, minOrderAmount: e.target.value })} />
                        </Grid>
                        <Grid item xs={6}>
                            <TextField fullWidth type="number" label="Max Usage (0 = unlimited)" value={form.maxUsageCount} onChange={(e) => setForm({ ...form, maxUsageCount: parseInt(e.target.value) || 0 })} />
                        </Grid>
                        <Grid item xs={12}><TextField fullWidth label="Description" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} multiline rows={2} /></Grid>
                        <Grid item xs={6}><TextField fullWidth type="datetime-local" label="Valid From" value={form.validFrom} onChange={(e) => setForm({ ...form, validFrom: e.target.value })} InputLabelProps={{ shrink: true }} /></Grid>
                        <Grid item xs={6}><TextField fullWidth type="datetime-local" label="Valid Until" value={form.validUntil} onChange={(e) => setForm({ ...form, validUntil: e.target.value })} InputLabelProps={{ shrink: true }} /></Grid>
                    </Grid>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setCreateDialog(false)}>Cancel</Button>
                    <Button variant="contained" onClick={handleCreate}>Create</Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default OrganiserCoupons;

import React, { useState, useEffect } from 'react';
import {
    Box, Typography, Paper, Button, Chip, Dialog, DialogTitle, DialogContent,
    DialogActions, TextField, Grid, Select, MenuItem, FormControl, InputLabel,
    IconButton, Tooltip, CircularProgress, Alert, Collapse,
} from '@mui/material';
import { DataGrid } from '@mui/x-data-grid';
import {
    Add as AddIcon, Refresh as RefreshIcon, Block as DisableIcon,
    LocalOffer as CouponIcon, AutoAwesome as AIIcon,
} from '@mui/icons-material';
import { organiserApi } from '../../api';
import { toast } from 'react-toastify';
import { ConfirmDialog } from '../../components/common';

const OrganiserCoupons = () => {
    const [coupons, setCoupons] = useState([]);
    const [loading, setLoading] = useState(false);
    const [createDialog, setCreateDialog] = useState(false);
    const [createSubmitting, setCreateSubmitting] = useState(false);
    const [paginationModel, setPaginationModel] = useState({ page: 0, pageSize: 10 });
    const [totalRows, setTotalRows] = useState(0);
    const [confirmDialog, setConfirmDialog] = useState({ open: false, title: '', message: '', action: null });
    const [form, setForm] = useState({
        code: '', description: '', discountType: 'PERCENTAGE', discountValue: '',
        maxDiscountAmount: '', minOrderAmount: '', maxUsageCount: 0, maxUsagePerUser: '',
        validFrom: '', validUntil: '',
    });

    const [aiDialog, setAiDialog] = useState(false);
    const [aiLoading, setAiLoading] = useState(false);
    const [aiResult, setAiResult] = useState(null);
    const [aiForm, setAiForm] = useState({
        description: '', eventName: '', discountType: 'PERCENTAGE', discountValue: '',
        maxDiscountAmount: '', minOrderAmount: '', maxUsageCount: '', maxUsagePerUser: '',
        validFrom: '', validUntil: '', language: 'vi',
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
        if (createSubmitting) return;
        if (!form.code.trim()) { toast.error('Coupon code is required'); return; }
        const dv = parseFloat(form.discountValue);
        if (!dv || dv <= 0) { toast.error('Discount value must be greater than 0'); return; }
        if (form.discountType === 'PERCENTAGE' && dv > 100) { toast.error('Percentage cannot exceed 100%'); return; }
        if (form.validFrom && form.validUntil && new Date(form.validFrom) >= new Date(form.validUntil)) {
            toast.error('Valid From must be before Valid Until'); return;
        }
        setCreateSubmitting(true);
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
        finally { setCreateSubmitting(false); }
    };

    const requestDisable = (id, code) => {
        setConfirmDialog({
            open: true,
            title: 'Disable coupon?',
            message: `Coupon "${code}" will no longer be usable. This cannot be undone.`,
            action: () => doDisable(id),
        });
    };

    const doDisable = async (id) => {
        try { await organiserApi.disableCoupon(id); toast.success('Coupon disabled'); loadCoupons(); }
        catch { toast.error('Failed'); }
    };

    const handleAIGenerate = async () => {
        setAiLoading(true);
        try {
            const data = { ...aiForm };
            if (aiForm.discountValue) data.discountValue = parseFloat(aiForm.discountValue);
            if (aiForm.maxDiscountAmount) data.maxDiscountAmount = parseFloat(aiForm.maxDiscountAmount);
            if (aiForm.minOrderAmount) data.minOrderAmount = parseFloat(aiForm.minOrderAmount);
            if (aiForm.maxUsageCount) data.maxUsageCount = parseInt(aiForm.maxUsageCount);
            if (aiForm.maxUsagePerUser) data.maxUsagePerUser = parseInt(aiForm.maxUsagePerUser);
            if (aiForm.validFrom) data.validFrom = new Date(aiForm.validFrom).toISOString();
            if (aiForm.validUntil) data.validUntil = new Date(aiForm.validUntil).toISOString();

            const res = await organiserApi.generateCouponAI(data);
            setAiResult(res.data.data);
            toast.success('AI generated coupon suggestions!');
        } catch (e) {
            const errorMsg = e.response?.data?.message
                || e.response?.data?.error
                || e.message
                || 'Failed to generate coupon with AI';
            toast.error(errorMsg);
        } finally {
            setAiLoading(false);
        }
    };

    const applyAIGenerated = () => {
        if (!aiResult) return;

        // Format datetime for input type="datetime-local" (YYYY-MM-DDTHH:mm)
        const formatDateTime = (dateStr) => {
            if (!dateStr) return '';
            try {
                const date = new Date(dateStr);
                if (isNaN(date.getTime())) return '';
                // Format to YYYY-MM-DDTHH:mm
                const year = date.getFullYear();
                const month = String(date.getMonth() + 1).padStart(2, '0');
                const day = String(date.getDate()).padStart(2, '0');
                const hours = String(date.getHours()).padStart(2, '0');
                const minutes = String(date.getMinutes()).padStart(2, '0');
                return `${year}-${month}-${day}T${hours}:${minutes}`;
            } catch {
                return '';
            }
        };

        // Calculate valid dates if AI returns suggestedValidDays but not specific dates
        let validFrom = aiResult.suggestedValidFrom || '';
        let validUntil = aiResult.suggestedValidUntil || '';

        if (!validFrom && !validUntil && aiResult.suggestedValidDays) {
            const now = new Date();
            validFrom = formatDateTime(now.toISOString());
            const future = new Date(now);
            future.setDate(future.getDate() + parseInt(aiResult.suggestedValidDays));
            validUntil = formatDateTime(future.toISOString());
        } else {
            validFrom = formatDateTime(validFrom);
            validUntil = formatDateTime(validUntil);
        }

        setForm({
            ...form,
            code: aiResult.code || form.code,
            description: aiResult.description || form.description,
            discountType: aiResult.suggestedDiscountType || form.discountType,
            discountValue: aiResult.suggestedDiscountValue?.toString() || form.discountValue,
            maxDiscountAmount: aiResult.suggestedMaxDiscountAmount?.toString() || form.maxDiscountAmount,
            minOrderAmount: aiResult.suggestedMinOrderAmount?.toString() || form.minOrderAmount,
            maxUsageCount: aiResult.suggestedMaxUsageCount || form.maxUsageCount,
            maxUsagePerUser: aiResult.suggestedMaxUsagePerUser?.toString() || form.maxUsagePerUser,
            validFrom: validFrom || form.validFrom,
            validUntil: validUntil || form.validUntil,
        });
        setAiDialog(false);
        setAiResult(null);
        setCreateDialog(true);
        toast.success('AI suggestions applied!');
    };

    const columns = [
        { field: 'code', headerName: 'Code', width: 130, renderCell: (p) => <Chip icon={<CouponIcon />} label={p.value} size="small" color="primary" /> },
        { field: 'discountType', headerName: 'Type', width: 120, renderCell: (p) => p.value === 'PERCENTAGE' ? `${p.row.discountValue}%` : `$${p.row.discountValue}` },
        { field: 'status', headerName: 'Status', width: 100, renderCell: (p) => <Chip label={p.value} size="small" color={p.value === 'ACTIVE' ? 'success' : 'default'} /> },
        { field: 'usedCount', headerName: 'Used', width: 80, renderCell: (p) => `${p.value}${p.row.maxUsageCount > 0 ? '/' + p.row.maxUsageCount : ''}` },
        { field: 'validUntil', headerName: 'Expires', width: 150, valueFormatter: (p) => p.value ? new Date(p.value).toLocaleDateString() : 'No expiry' },
        { field: 'actions', headerName: '', width: 80, sortable: false, renderCell: (p) => p.row.status === 'ACTIVE' ? (
            <Tooltip title="Disable"><IconButton size="small" color="error" onClick={() => requestDisable(p.row.id, p.row.code)}><DisableIcon /></IconButton></Tooltip>
        ) : null },
    ];

    return (
        <Box>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 3 }}>
                <Typography variant="h5" fontWeight="bold"><CouponIcon sx={{ mr: 1, verticalAlign: 'middle' }} />Coupons</Typography>
                <Box sx={{ display: 'flex', gap: 1 }}>
                    <Button startIcon={<RefreshIcon />} onClick={loadCoupons}>Refresh</Button>
                    <Button variant="outlined" startIcon={<AIIcon />} onClick={() => { setAiDialog(true); setAiResult(null); }}>AI Generate</Button>
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
                    <Button onClick={() => setCreateDialog(false)} disabled={createSubmitting}>Cancel</Button>
                    <Button
                        variant="contained"
                        onClick={handleCreate}
                        disabled={createSubmitting}
                        startIcon={createSubmitting ? <CircularProgress size={18} /> : null}
                    >
                        {createSubmitting ? 'Creating...' : 'Create'}
                    </Button>
                </DialogActions>
            </Dialog>

            <Dialog open={aiDialog} onClose={() => setAiDialog(false)} maxWidth="md" fullWidth>
                <DialogTitle sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <AIIcon color="primary" /> AI Generate Coupon
                </DialogTitle>
                <DialogContent>
                    <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                        Let AI help you create an effective coupon. Fill in your preferences and AI will suggest a creative code, description, and optimal settings.
                    </Typography>
                    <Grid container spacing={2}>
                        <Grid item xs={12}>
                            <TextField fullWidth multiline rows={2} label="What is this coupon for? (e.g., Early bird discount for tech conference)" value={aiForm.description} onChange={(e) => setAiForm({ ...aiForm, description: e.target.value })} />
                        </Grid>
                        <Grid item xs={6}>
                            <TextField fullWidth label="Event Name (optional)" value={aiForm.eventName} onChange={(e) => setAiForm({ ...aiForm, eventName: e.target.value })} />
                        </Grid>
                        <Grid item xs={6}>
                            <FormControl fullWidth>
                                <InputLabel>Language</InputLabel>
                                <Select value={aiForm.language} label="Language" onChange={(e) => setAiForm({ ...aiForm, language: e.target.value })}>
                                    <MenuItem value="vi">Vietnamese</MenuItem>
                                    <MenuItem value="en">English</MenuItem>
                                </Select>
                            </FormControl>
                        </Grid>
                        <Grid item xs={6}>
                            <FormControl fullWidth>
                                <InputLabel>Preferred Type</InputLabel>
                                <Select value={aiForm.discountType} label="Preferred Type" onChange={(e) => setAiForm({ ...aiForm, discountType: e.target.value })}>
                                    <MenuItem value="PERCENTAGE">Percentage (%)</MenuItem>
                                    <MenuItem value="FIXED_AMOUNT">Fixed Amount ($)</MenuItem>
                                </Select>
                            </FormControl>
                        </Grid>
                        <Grid item xs={6}>
                            <TextField fullWidth type="number" label="Preferred Discount Value" value={aiForm.discountValue} onChange={(e) => setAiForm({ ...aiForm, discountValue: e.target.value })} />
                        </Grid>
                        <Grid item xs={6}>
                            <TextField fullWidth type="number" label="Min Order Amount (optional)" value={aiForm.minOrderAmount} onChange={(e) => setAiForm({ ...aiForm, minOrderAmount: e.target.value })} />
                        </Grid>
                        <Grid item xs={6}>
                            <TextField fullWidth type="number" label="Max Per User (optional)" value={aiForm.maxUsagePerUser} onChange={(e) => setAiForm({ ...aiForm, maxUsagePerUser: e.target.value })} />
                        </Grid>
                        <Grid item xs={6}><TextField fullWidth type="datetime-local" label="Valid From" value={aiForm.validFrom} onChange={(e) => setAiForm({ ...aiForm, validFrom: e.target.value })} InputLabelProps={{ shrink: true }} /></Grid>
                        <Grid item xs={6}><TextField fullWidth type="datetime-local" label="Valid Until" value={aiForm.validUntil} onChange={(e) => setAiForm({ ...aiForm, validUntil: e.target.value })} InputLabelProps={{ shrink: true }} /></Grid>
                    </Grid>

                    <Collapse in={!!aiResult}>
                        <Alert severity="success" sx={{ mt: 3 }}>
                            <Typography variant="subtitle2" fontWeight="bold">AI Generated Suggestions:</Typography>
                            {aiResult && (
                                <Box sx={{ mt: 1 }}>
                                    <Typography variant="body2"><strong>Code:</strong> {aiResult.code}</Typography>
                                    <Typography variant="body2" sx={{ mt: 0.5 }}><strong>Description:</strong> {aiResult.description}</Typography>
                                    {aiResult.suggestedDiscountType && (
                                        <Typography variant="body2" sx={{ mt: 0.5 }}>
                                            <strong>Discount:</strong> {aiResult.suggestedDiscountType === 'PERCENTAGE' ? `${aiResult.suggestedDiscountValue}%` : `$${aiResult.suggestedDiscountValue}`}
                                        </Typography>
                                    )}
                                    {aiResult.suggestedMaxUsageCount && (
                                        <Typography variant="body2" sx={{ mt: 0.5 }}><strong>Max Usage:</strong> {aiResult.suggestedMaxUsageCount}</Typography>
                                    )}
                                    {(aiResult.suggestedValidFrom || aiResult.suggestedValidUntil) && (
                                        <Typography variant="body2" sx={{ mt: 0.5 }}>
                                            <strong>Valid Period:</strong> {aiResult.suggestedValidFrom ? new Date(aiResult.suggestedValidFrom).toLocaleString() : 'Now'} - {aiResult.suggestedValidUntil ? new Date(aiResult.suggestedValidUntil).toLocaleString() : 'Unlimited'}
                                        </Typography>
                                    )}
                                    {!aiResult.suggestedValidFrom && !aiResult.suggestedValidUntil && aiResult.suggestedValidDays && (
                                        <Typography variant="body2" sx={{ mt: 0.5 }}><strong>Valid for:</strong> {aiResult.suggestedValidDays} days</Typography>
                                    )}
                                    {aiResult.reasoning && (
                                        <Typography variant="body2" sx={{ mt: 1, fontStyle: 'italic', color: 'text.secondary' }}>{aiResult.reasoning}</Typography>
                                    )}
                                </Box>
                            )}
                        </Alert>
                    </Collapse>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setAiDialog(false)} disabled={aiLoading}>Cancel</Button>
                    <Button
                        variant="contained"
                        onClick={aiResult ? applyAIGenerated : handleAIGenerate}
                        disabled={aiLoading}
                        startIcon={aiLoading ? <CircularProgress size={20} /> : (aiResult ? <AddIcon /> : <AIIcon />)}
                    >
                        {aiLoading ? 'Generating...' : (aiResult ? 'Apply to Form' : 'Generate with AI')}
                    </Button>
                </DialogActions>
            </Dialog>

            <ConfirmDialog
                open={confirmDialog.open}
                title={confirmDialog.title}
                message={confirmDialog.message}
                confirmText="Disable"
                confirmColor="error"
                onConfirm={() => {
                    if (confirmDialog.action) confirmDialog.action();
                    setConfirmDialog({ ...confirmDialog, open: false });
                }}
                onCancel={() => setConfirmDialog({ ...confirmDialog, open: false })}
            />
        </Box>
    );
};

export default OrganiserCoupons;

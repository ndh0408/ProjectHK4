import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Typography,
    IconButton,
    Menu,
    MenuItem,
    Button,
    Tooltip,
    Divider,
} from '@mui/material';
import {
    MoreVert as MoreVertIcon,
    Refresh as RefreshIcon,
    PeopleAlt as PeopleAltIcon,
    AutoAwesome as AIIcon,
} from '@mui/icons-material';
import { adminApi } from '../../api';
import { ConfirmDialog, AiReviewDialog } from '../../components/common';
import {
    PageHeader,
    PageToolbar,
    DataTableCard,
    StatusChip,
} from '../../components/ui';
import { toast } from 'react-toastify';

const userStatusConfig = {
    ACTIVE: { status: 'success', label: 'Active' },
    INACTIVE: { status: 'neutral', label: 'Inactive' },
    LOCKED: { status: 'danger', label: 'Locked' },
    PENDING_VERIFICATION: { status: 'warning', label: 'Pending' },
};

const Users = () => {
    const [users, setUsers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');
    const [paginationModel, setPaginationModel] = useState({ page: 0, pageSize: 10 });
    const [totalRows, setTotalRows] = useState(0);
    const [anchorEl, setAnchorEl] = useState(null);
    const [selectedUser, setSelectedUser] = useState(null);
    const [confirmDialog, setConfirmDialog] = useState({ open: false, title: '', message: '', action: null });
    const [aiReview, setAiReview] = useState({ open: false, subject: null, loading: false, error: null, data: null });

    const loadUsers = useCallback(async () => {
        setLoading(true);
        try {
            const response = await adminApi.getUsers({
                page: paginationModel.page,
                size: paginationModel.pageSize,
                q: search || undefined,
                role: 'USER',
            });
            setUsers(response.data.data.content || []);
            setTotalRows(response.data.data.totalElements || 0);
        } catch (error) {
            toast.error('Failed to load users');
        } finally {
            setLoading(false);
        }
    }, [paginationModel, search]);

    useEffect(() => {
        loadUsers();
    }, [loadUsers]);

    const handleMenuOpen = (event, user) => {
        setAnchorEl(event.currentTarget);
        setSelectedUser(user);
    };

    const handleMenuClose = () => {
        setAnchorEl(null);
        setSelectedUser(null);
    };

    const handleStatusChange = async (status) => {
        const target = selectedUser;
        handleMenuClose();
        const isActivate = status === 'ACTIVE';
        setConfirmDialog({
            open: true,
            title: isActivate ? 'Activate User' : 'Lock User',
            message: isActivate
                ? 'Are you sure you want to activate this user?'
                : 'Are you sure you want to lock this user account?',
            entityName: target?.fullName || target?.email,
            action: async () => {
                try {
                    await adminApi.updateUserStatus(selectedUser.id, status);
                    toast.success(isActivate ? 'User activated successfully' : 'User account locked');
                    loadUsers();
                } catch (error) {
                    toast.error('Failed to update user status');
                }
            },
        });
    };

    const handleAiReview = async () => {
        const target = selectedUser;
        handleMenuClose();
        if (!target) return;
        setAiReview({ open: true, subject: target, loading: true, error: null, data: null });
        try {
            const response = await adminApi.aiAnalyseUser(target.id);
            setAiReview((s) => ({ ...s, loading: false, data: response.data.data }));
        } catch (e) {
            setAiReview((s) => ({
                ...s,
                loading: false,
                error: e.response?.data?.message || 'Failed to run AI analysis.',
            }));
        }
    };

    const handleDelete = () => {
        const target = selectedUser;
        handleMenuClose();
        setConfirmDialog({
            open: true,
            title: 'Delete User',
            message: 'Are you sure you want to delete this user? This action cannot be undone.',
            entityName: target?.fullName || target?.email,
            confirmColor: 'error',
            action: async () => {
                try {
                    await adminApi.deleteUser(selectedUser.id);
                    toast.success('User deleted successfully');
                    loadUsers();
                } catch (error) {
                    toast.error('Failed to delete user');
                }
            },
        });
    };

    const columns = [
        {
            field: 'fullName',
            headerName: 'Name',
            flex: 1,
            minWidth: 160,
            renderCell: (params) => (
                <Typography variant="body2" fontWeight={600}>
                    {params.value || '—'}
                </Typography>
            ),
        },
        {
            field: 'email',
            headerName: 'Email',
            flex: 1.2,
            minWidth: 220,
            renderCell: (params) => (
                <Typography variant="body2" color="text.secondary">
                    {params.value}
                </Typography>
            ),
        },
        {
            field: 'status',
            headerName: 'Status',
            width: 130,
            renderCell: (params) => {
                const config = userStatusConfig[params.value] || { status: 'neutral', label: params.value };
                return <StatusChip label={config.label} status={config.status} />;
            },
        },
        {
            field: 'createdAt',
            headerName: 'Created',
            width: 150,
            valueFormatter: (params) => {
                if (!params.value) return '';
                return new Date(params.value).toLocaleDateString();
            },
        },
        {
            field: 'actions',
            headerName: '',
            width: 70,
            sortable: false,
            align: 'center',
            headerAlign: 'center',
            renderCell: (params) => (
                <Tooltip title="More actions">
                    <IconButton
                        size="small"
                        aria-label="user actions"
                        onClick={(e) => handleMenuOpen(e, params.row)}
                    >
                        <MoreVertIcon fontSize="small" />
                    </IconButton>
                </Tooltip>
            ),
        },
    ];

    return (
        <Box>
            <PageHeader
                title="User Management"
                subtitle="View, search and moderate all platform users"
                icon={<PeopleAltIcon />}
                actions={
                    <Button
                        variant="outlined"
                        startIcon={<RefreshIcon />}
                        onClick={loadUsers}
                    >
                        Refresh
                    </Button>
                }
            />

            <DataTableCard
                toolbar={
                    <PageToolbar
                        search={search}
                        onSearchChange={setSearch}
                        searchPlaceholder="Search users by name or email..."
                    />
                }
                rows={users}
                columns={columns}
                loading={loading}
                emptyTitle="No users found"
                emptyDescription="Try adjusting your search or wait for new users to register."
                emptyIcon={<PeopleAltIcon sx={{ fontSize: 40 }} />}
                dataGridProps={{
                    paginationModel,
                    onPaginationModelChange: setPaginationModel,
                    pageSizeOptions: [10, 25, 50],
                    rowCount: totalRows,
                    paginationMode: 'server',
                }}
            />

            <Menu
                anchorEl={anchorEl}
                open={Boolean(anchorEl)}
                onClose={handleMenuClose}
                slotProps={{ paper: { sx: { minWidth: 200, borderRadius: 2 } } }}
            >
                <MenuItem onClick={handleAiReview}>
                    <AIIcon fontSize="small" color="primary" sx={{ mr: 1 }} />
                    <Box>
                        <Typography variant="body2">AI Risk Analysis</Typography>
                        <Typography variant="caption" color="text.secondary">
                            Behavior & moderation hint
                        </Typography>
                    </Box>
                </MenuItem>
                <Divider sx={{ my: 0.5 }} />
                <MenuItem disabled sx={{ opacity: 0.7 }}>
                    <Typography variant="caption" fontWeight={600}>
                        Change status
                    </Typography>
                </MenuItem>
                {selectedUser?.status !== 'ACTIVE' && (
                    <MenuItem onClick={() => handleStatusChange('ACTIVE')}>Activate</MenuItem>
                )}
                {selectedUser?.status === 'ACTIVE' && (
                    <MenuItem onClick={() => handleStatusChange('LOCKED')}>Lock account</MenuItem>
                )}
                <Divider sx={{ my: 0.5 }} />
                <MenuItem onClick={handleDelete} sx={{ color: 'error.main' }}>
                    Delete user
                </MenuItem>
            </Menu>

            <ConfirmDialog
                open={confirmDialog.open}
                title={confirmDialog.title}
                message={confirmDialog.message}
                entityName={confirmDialog.entityName}
                confirmColor={confirmDialog.confirmColor}
                onConfirm={() => {
                    confirmDialog.action?.();
                    setConfirmDialog({ ...confirmDialog, open: false });
                }}
                onCancel={() => setConfirmDialog({ ...confirmDialog, open: false })}
            />

            <AiReviewDialog
                open={aiReview.open}
                onClose={() => setAiReview({ open: false, subject: null, loading: false, error: null, data: null })}
                title="AI User Risk Analysis"
                subtitle="AI suggests a moderation direction from available activity data. Admin should review before taking action."
                subjectName={aiReview.subject?.fullName}
                subjectEmail={aiReview.subject?.email}
                loading={aiReview.loading}
                error={aiReview.error}
                data={aiReview.data}
                mode="user"
            />
        </Box>
    );
};

export default Users;

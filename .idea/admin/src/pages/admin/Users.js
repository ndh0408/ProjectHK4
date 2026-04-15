import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Typography,
    Paper,
    TextField,
    InputAdornment,
    IconButton,
    Chip,
    Menu,
    MenuItem,
    Button,
} from '@mui/material';
import { DataGrid } from '@mui/x-data-grid';
import {
    Search as SearchIcon,
    MoreVert as MoreVertIcon,
    Refresh as RefreshIcon,
} from '@mui/icons-material';
import { adminApi } from '../../api';
import { ConfirmDialog } from '../../components/common';
import { toast } from 'react-toastify';

const Users = () => {
    const [users, setUsers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');
    const [paginationModel, setPaginationModel] = useState({ page: 0, pageSize: 10 });
    const [totalRows, setTotalRows] = useState(0);
    const [anchorEl, setAnchorEl] = useState(null);
    const [selectedUser, setSelectedUser] = useState(null);
    const [confirmDialog, setConfirmDialog] = useState({ open: false, title: '', message: '', action: null });

    const loadUsers = useCallback(async () => {
        setLoading(true);
        try {
            const response = await adminApi.getUsers({
                page: paginationModel.page,
                size: paginationModel.pageSize,
                search: search || undefined,
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
        handleMenuClose();
        const isActivate = status === 'ACTIVE';
        setConfirmDialog({
            open: true,
            title: isActivate ? 'Activate User' : 'Lock User',
            message: isActivate
                ? 'Are you sure you want to activate this user?'
                : 'Are you sure you want to lock this user account?',
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

    const handleDelete = () => {
        handleMenuClose();
        setConfirmDialog({
            open: true,
            title: 'Delete User',
            message: 'Are you sure you want to delete this user? This action cannot be undone.',
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
            minWidth: 150,
        },
        {
            field: 'email',
            headerName: 'Email',
            flex: 1,
            minWidth: 200,
        },
        {
            field: 'role',
            headerName: 'Role',
            width: 120,
            renderCell: (params) => (
                <Chip
                    label={params.value}
                    size="small"
                    color={
                        params.value === 'ADMIN' ? 'error' :
                        params.value === 'ORGANISER' ? 'warning' : 'default'
                    }
                />
            ),
        },
        {
            field: 'status',
            headerName: 'Status',
            width: 120,
            renderCell: (params) => {
                const statusConfig = {
                    ACTIVE: { color: 'success', label: 'Active' },
                    INACTIVE: { color: 'default', label: 'Inactive' },
                    LOCKED: { color: 'error', label: 'Locked' },
                    PENDING_VERIFICATION: { color: 'warning', label: 'Pending' },
                };
                const config = statusConfig[params.value] || { color: 'default', label: params.value };
                return (
                    <Chip
                        label={config.label}
                        size="small"
                        color={config.color}
                    />
                );
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
            headerName: 'Actions',
            width: 80,
            sortable: false,
            renderCell: (params) => (
                <IconButton
                    size="small"
                    onClick={(e) => handleMenuOpen(e, params.row)}
                >
                    <MoreVertIcon />
                </IconButton>
            ),
        },
    ];

    return (
        <Box>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                <Typography variant="h5" fontWeight="bold">
                    User Management
                </Typography>
                <Button startIcon={<RefreshIcon />} onClick={loadUsers}>
                    Refresh
                </Button>
            </Box>

            <Paper sx={{ p: 2, mb: 2 }}>
                <TextField
                    placeholder="Search users..."
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    size="small"
                    sx={{ width: 300 }}
                    InputProps={{
                        startAdornment: (
                            <InputAdornment position="start">
                                <SearchIcon />
                            </InputAdornment>
                        ),
                    }}
                />
            </Paper>

            <Paper>
                <DataGrid
                    rows={users}
                    columns={columns}
                    loading={loading}
                    paginationModel={paginationModel}
                    onPaginationModelChange={setPaginationModel}
                    pageSizeOptions={[10, 25, 50]}
                    rowCount={totalRows}
                    paginationMode="server"
                    disableRowSelectionOnClick
                    autoHeight
                />
            </Paper>

            <Menu anchorEl={anchorEl} open={Boolean(anchorEl)} onClose={handleMenuClose}>
                <MenuItem disabled>
                    <Typography variant="caption">Change Status</Typography>
                </MenuItem>
                {selectedUser?.status !== 'ACTIVE' && (
                    <MenuItem onClick={() => handleStatusChange('ACTIVE')}>Activate</MenuItem>
                )}
                {selectedUser?.status === 'ACTIVE' && (
                    <MenuItem onClick={() => handleStatusChange('LOCKED')}>Lock Account</MenuItem>
                )}
                <MenuItem divider />
                <MenuItem onClick={handleDelete} sx={{ color: 'error.main' }}>Delete</MenuItem>
            </Menu>

            <ConfirmDialog
                open={confirmDialog.open}
                title={confirmDialog.title}
                message={confirmDialog.message}
                confirmColor={confirmDialog.confirmColor}
                onConfirm={() => {
                    confirmDialog.action?.();
                    setConfirmDialog({ ...confirmDialog, open: false });
                }}
                onCancel={() => setConfirmDialog({ ...confirmDialog, open: false })}
            />
        </Box>
    );
};

export default Users;

import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Typography,
    Paper,
    TextField,
    InputAdornment,
    Chip,
    Button,
    Avatar,
    Menu,
    MenuItem,
    ListItemIcon,
    ListItemText,
} from '@mui/material';
import { DataGrid } from '@mui/x-data-grid';
import {
    Search as SearchIcon,
    Refresh as RefreshIcon,
    Verified as VerifiedIcon,
    MoreVert as MoreVertIcon,
    CheckCircle as ActiveIcon,
    Block as LockIcon,
} from '@mui/icons-material';
import { adminApi } from '../../api';
import { ConfirmDialog } from '../../components/common';
import { toast } from 'react-toastify';

const Organisers = () => {
    const [organisers, setOrganisers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');
    const [paginationModel, setPaginationModel] = useState({ page: 0, pageSize: 10 });
    const [totalRows, setTotalRows] = useState(0);
    const [confirmDialog, setConfirmDialog] = useState({ open: false, title: '', message: '', action: null });
    const [anchorEl, setAnchorEl] = useState(null);
    const [selectedOrganiser, setSelectedOrganiser] = useState(null);

    const loadOrganisers = useCallback(async () => {
        setLoading(true);
        try {
            const response = await adminApi.getOrganisers({
                page: paginationModel.page,
                size: paginationModel.pageSize,
                search: search || undefined,
            });
            setOrganisers(response.data.data.content || []);
            setTotalRows(response.data.data.totalElements || 0);
        } catch (error) {
            toast.error('Failed to load organisers');
        } finally {
            setLoading(false);
        }
    }, [paginationModel, search]);

    useEffect(() => {
        loadOrganisers();
    }, [loadOrganisers]);

    const handleMenuOpen = (event, organiser) => {
        setAnchorEl(event.currentTarget);
        setSelectedOrganiser(organiser);
    };

    const handleMenuClose = () => {
        setAnchorEl(null);
        setSelectedOrganiser(null);
    };

    const handleVerify = (organiser) => {
        handleMenuClose();
        setConfirmDialog({
            open: true,
            title: 'Verify Organiser',
            message: `Are you sure you want to verify "${organiser.displayName || organiser.fullName}"?`,
            action: async () => {
                try {
                    await adminApi.verifyOrganiser(organiser.id);
                    toast.success('Organiser verified successfully');
                    loadOrganisers();
                } catch (error) {
                    toast.error('Failed to verify organiser');
                }
            },
        });
    };

    const handleUnverify = (organiser) => {
        handleMenuClose();
        setConfirmDialog({
            open: true,
            title: 'Remove Verification',
            message: `Are you sure you want to remove verification from "${organiser.displayName || organiser.fullName}"?`,
            action: async () => {
                try {
                    await adminApi.unverifyOrganiser(organiser.id);
                    toast.success('Verification removed successfully');
                    loadOrganisers();
                } catch (error) {
                    toast.error('Failed to remove verification');
                }
            },
        });
    };

    const handleActivate = (organiser) => {
        handleMenuClose();
        setConfirmDialog({
            open: true,
            title: 'Activate Account',
            message: `Are you sure you want to activate "${organiser.displayName || organiser.fullName}"?`,
            action: async () => {
                try {
                    await adminApi.updateOrganiserStatus(organiser.id, 'ACTIVE');
                    toast.success('Account activated successfully');
                    loadOrganisers();
                } catch (error) {
                    toast.error('Failed to activate account');
                }
            },
        });
    };

    const handleLock = (organiser) => {
        handleMenuClose();
        setConfirmDialog({
            open: true,
            title: 'Lock Account',
            message: `Are you sure you want to lock "${organiser.displayName || organiser.fullName}"? They will not be able to login.`,
            action: async () => {
                try {
                    await adminApi.updateOrganiserStatus(organiser.id, 'LOCKED');
                    toast.success('Account locked successfully');
                    loadOrganisers();
                } catch (error) {
                    toast.error('Failed to lock account');
                }
            },
        });
    };

    const columns = [
        {
            field: 'avatar',
            headerName: '',
            width: 60,
            sortable: false,
            renderCell: (params) => (
                <Avatar src={params.row.avatarUrl || params.row.logoUrl} alt={params.row.displayName}>
                    {(params.row.displayName || params.row.fullName)?.charAt(0)}
                </Avatar>
            ),
        },
        {
            field: 'displayName',
            headerName: 'Organization',
            flex: 1,
            minWidth: 200,
            renderCell: (params) => (
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <Typography>{params.row.displayName || params.row.fullName}</Typography>
                    {params.row.verified && (
                        <VerifiedIcon sx={{ color: 'primary.main', fontSize: 18 }} />
                    )}
                </Box>
            ),
        },
        {
            field: 'email',
            headerName: 'Email',
            flex: 1,
            minWidth: 200,
        },
        {
            field: 'totalEvents',
            headerName: 'Events',
            width: 100,
            align: 'center',
        },
        {
            field: 'totalFollowers',
            headerName: 'Followers',
            width: 100,
            align: 'center',
        },
        {
            field: 'status',
            headerName: 'Account',
            width: 120,
            renderCell: (params) => (
                <Chip
                    label={params.value === 'ACTIVE' ? 'Active' : 'Locked'}
                    size="small"
                    color={params.value === 'ACTIVE' ? 'success' : 'error'}
                />
            ),
        },
        {
            field: 'verified',
            headerName: 'Verified',
            width: 120,
            renderCell: (params) => (
                <Chip
                    label={params.value ? 'Verified' : 'Unverified'}
                    size="small"
                    color={params.value ? 'info' : 'default'}
                    variant={params.value ? 'filled' : 'outlined'}
                />
            ),
        },
        {
            field: 'actions',
            headerName: 'Actions',
            width: 100,
            sortable: false,
            renderCell: (params) => (
                <Button
                    size="small"
                    onClick={(e) => handleMenuOpen(e, params.row)}
                >
                    <MoreVertIcon />
                </Button>
            ),
        },
    ];

    return (
        <Box>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                <Typography variant="h5" fontWeight="bold">
                    Organiser Management
                </Typography>
                <Button startIcon={<RefreshIcon />} onClick={loadOrganisers}>
                    Refresh
                </Button>
            </Box>

            <Paper sx={{ p: 2, mb: 2 }}>
                <TextField
                    placeholder="Search organisers..."
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
                    rows={organisers}
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

            <Menu
                anchorEl={anchorEl}
                open={Boolean(anchorEl)}
                onClose={handleMenuClose}
            >
                {selectedOrganiser?.status === 'ACTIVE' ? (
                    <MenuItem onClick={() => handleLock(selectedOrganiser)}>
                        <ListItemIcon>
                            <LockIcon fontSize="small" color="error" />
                        </ListItemIcon>
                        <ListItemText>Lock Account</ListItemText>
                    </MenuItem>
                ) : (
                    <MenuItem onClick={() => handleActivate(selectedOrganiser)}>
                        <ListItemIcon>
                            <ActiveIcon fontSize="small" color="success" />
                        </ListItemIcon>
                        <ListItemText>Activate Account</ListItemText>
                    </MenuItem>
                )}
                {selectedOrganiser?.verified ? (
                    <MenuItem onClick={() => handleUnverify(selectedOrganiser)}>
                        <ListItemIcon>
                            <VerifiedIcon fontSize="small" color="warning" />
                        </ListItemIcon>
                        <ListItemText>Remove Verification</ListItemText>
                    </MenuItem>
                ) : (
                    <MenuItem onClick={() => handleVerify(selectedOrganiser)}>
                        <ListItemIcon>
                            <VerifiedIcon fontSize="small" color="primary" />
                        </ListItemIcon>
                        <ListItemText>Verify Organiser</ListItemText>
                    </MenuItem>
                )}
            </Menu>

            <ConfirmDialog
                open={confirmDialog.open}
                title={confirmDialog.title}
                message={confirmDialog.message}
                onConfirm={() => {
                    confirmDialog.action?.();
                    setConfirmDialog({ ...confirmDialog, open: false });
                }}
                onCancel={() => setConfirmDialog({ ...confirmDialog, open: false })}
            />
        </Box>
    );
};

export default Organisers;

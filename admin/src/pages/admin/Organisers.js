import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Typography,
    Button,
    Avatar,
    Menu,
    MenuItem,
    ListItemIcon,
    ListItemText,
    IconButton,
    Tooltip,
} from '@mui/material';
import {
    Refresh as RefreshIcon,
    Verified as VerifiedIcon,
    MoreVert as MoreVertIcon,
    CheckCircle as ActiveIcon,
    Block as LockIcon,
    Business as BusinessIcon,
} from '@mui/icons-material';
import { adminApi } from '../../api';
import { ConfirmDialog } from '../../components/common';
import {
    PageHeader,
    PageToolbar,
    DataTableCard,
    StatusChip,
} from '../../components/ui';
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
            field: 'displayName',
            headerName: 'Organisation',
            flex: 1.3,
            minWidth: 240,
            renderCell: (params) => {
                const name = params.row.displayName || params.row.fullName;
                return (
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, minWidth: 0 }}>
                        <Avatar
                            src={params.row.avatarUrl || params.row.logoUrl}
                            alt={name}
                            sx={{ width: 38, height: 38, fontSize: '0.9rem', fontWeight: 600 }}
                        >
                            {name?.charAt(0)?.toUpperCase()}
                        </Avatar>
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, minWidth: 0 }}>
                            <Typography variant="body2" fontWeight={600} noWrap>
                                {name}
                            </Typography>
                            {params.row.verified && (
                                <VerifiedIcon sx={{ color: 'primary.main', fontSize: 16, flexShrink: 0 }} />
                            )}
                        </Box>
                    </Box>
                );
            },
        },
        {
            field: 'email',
            headerName: 'Email',
            flex: 1,
            minWidth: 200,
            renderCell: (params) => (
                <Typography variant="body2" color="text.secondary" noWrap>
                    {params.value}
                </Typography>
            ),
        },
        {
            field: 'totalEvents',
            headerName: 'Events',
            width: 90,
            align: 'center',
            headerAlign: 'center',
        },
        {
            field: 'totalFollowers',
            headerName: 'Followers',
            width: 100,
            align: 'center',
            headerAlign: 'center',
        },
        {
            field: 'status',
            headerName: 'Account',
            width: 120,
            renderCell: (params) => (
                <StatusChip
                    label={params.value === 'ACTIVE' ? 'Active' : 'Locked'}
                    status={params.value === 'ACTIVE' ? 'success' : 'danger'}
                />
            ),
        },
        {
            field: 'verified',
            headerName: 'Verified',
            width: 120,
            renderCell: (params) => (
                <StatusChip
                    label={params.value ? 'Verified' : 'Unverified'}
                    status={params.value ? 'info' : 'neutral'}
                />
            ),
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
                        aria-label="organiser actions"
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
                title="Organiser Management"
                subtitle="Review, verify and moderate event organiser accounts"
                icon={<BusinessIcon />}
                actions={
                    <Button
                        variant="outlined"
                        startIcon={<RefreshIcon />}
                        onClick={loadOrganisers}
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
                        searchPlaceholder="Search organisers by name or email..."
                    />
                }
                rows={organisers}
                columns={columns}
                loading={loading}
                emptyTitle="No organisers found"
                emptyDescription="No organisers match your current search."
                emptyIcon={<BusinessIcon sx={{ fontSize: 40 }} />}
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
                slotProps={{ paper: { sx: { minWidth: 210, borderRadius: 2 } } }}
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

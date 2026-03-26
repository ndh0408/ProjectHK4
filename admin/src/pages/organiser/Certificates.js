import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Typography,
    Paper,
    Button,
    Chip,
    Avatar,
    TextField,
    InputAdornment,
    IconButton,
    Tooltip,
    Link,
} from '@mui/material';
import { DataGrid } from '@mui/x-data-grid';
import {
    Refresh as RefreshIcon,
    Search as SearchIcon,
    Download as DownloadIcon,
    Visibility as VisibilityIcon,
    WorkspacePremium as CertificateIcon,
} from '@mui/icons-material';
import { organiserApi } from '../../api';
import { toast } from 'react-toastify';

const OrganiserCertificates = () => {
    const [certificates, setCertificates] = useState([]);
    const [loading, setLoading] = useState(true);
    const [paginationModel, setPaginationModel] = useState({ page: 0, pageSize: 10 });
    const [totalRows, setTotalRows] = useState(0);
    const [searchQuery, setSearchQuery] = useState('');

    const loadCertificates = useCallback(async () => {
        setLoading(true);
        try {
            const response = await organiserApi.getCertificates({
                page: paginationModel.page,
                size: paginationModel.pageSize,
            });
            setCertificates(response.data.data.content || []);
            setTotalRows(response.data.data.totalElements || 0);
        } catch (error) {
            toast.error('Failed to load certificates');
            console.error('Error loading certificates:', error);
        } finally {
            setLoading(false);
        }
    }, [paginationModel]);

    useEffect(() => {
        loadCertificates();
    }, [loadCertificates]);

    const filteredCertificates = certificates.filter(cert => {
        if (!searchQuery) return true;
        const query = searchQuery.toLowerCase();
        return (
            cert.userName?.toLowerCase().includes(query) ||
            cert.userEmail?.toLowerCase().includes(query) ||
            cert.eventTitle?.toLowerCase().includes(query) ||
            cert.certificateCode?.toLowerCase().includes(query)
        );
    });

    const columns = [
        {
            field: 'certificateCode',
            headerName: 'Certificate Code',
            width: 160,
            renderCell: (params) => (
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <CertificateIcon sx={{ color: 'primary.main', fontSize: 20 }} />
                    <Typography variant="body2" fontWeight="medium">
                        {params.value}
                    </Typography>
                </Box>
            ),
        },
        {
            field: 'userName',
            headerName: 'Attendee',
            flex: 1,
            minWidth: 200,
            renderCell: (params) => (
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <Avatar sx={{ width: 32, height: 32, bgcolor: 'primary.main' }}>
                        {params.value?.charAt(0)?.toUpperCase() || '?'}
                    </Avatar>
                    <Box>
                        <Typography variant="body2" fontWeight="medium">
                            {params.value}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                            {params.row.userEmail}
                        </Typography>
                    </Box>
                </Box>
            ),
        },
        {
            field: 'eventTitle',
            headerName: 'Event',
            flex: 1,
            minWidth: 200,
        },
        {
            field: 'eventDate',
            headerName: 'Event Date',
            width: 130,
            valueFormatter: (params) => {
                if (!params.value) return '';
                return new Date(params.value).toLocaleDateString();
            },
        },
        {
            field: 'generatedAt',
            headerName: 'Issued Date',
            width: 130,
            valueFormatter: (params) => {
                if (!params.value) return '';
                return new Date(params.value).toLocaleDateString();
            },
        },
        {
            field: 'actions',
            headerName: 'Actions',
            width: 120,
            sortable: false,
            renderCell: (params) => {
                const baseUrl = process.env.REACT_APP_API_URL || 'http://localhost:8080';
                const viewUrl = `${baseUrl}/api/certificates/${params.row.certificateCode}/pdf`;
                const downloadUrl = `${baseUrl}/api/certificates/${params.row.certificateCode}/pdf?download=true`;

                return (
                    <Box sx={{ display: 'flex', gap: 0.5 }}>
                        <Tooltip title="View Certificate">
                            <IconButton
                                size="small"
                                color="primary"
                                onClick={() => window.open(viewUrl, '_blank')}
                                disabled={!params.row.certificateCode}
                            >
                                <VisibilityIcon fontSize="small" />
                            </IconButton>
                        </Tooltip>
                        <Tooltip title="Download Certificate">
                            <IconButton
                                size="small"
                                color="secondary"
                                component={Link}
                                href={downloadUrl}
                                download={`${params.row.certificateCode}.pdf`}
                                disabled={!params.row.certificateCode}
                            >
                                <DownloadIcon fontSize="small" />
                            </IconButton>
                        </Tooltip>
                    </Box>
                );
            },
        },
    ];

    return (
        <Box>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                <Box>
                    <Typography variant="h5" fontWeight="bold">
                        Certificates
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                        View all certificates issued for your events
                    </Typography>
                </Box>
                <Button startIcon={<RefreshIcon />} onClick={loadCertificates}>
                    Refresh
                </Button>
            </Box>

            <Box sx={{ display: 'flex', gap: 2, mb: 3 }}>
                <Paper sx={{ p: 2, flex: 1, display: 'flex', alignItems: 'center', gap: 2 }}>
                    <CertificateIcon sx={{ fontSize: 40, color: 'primary.main' }} />
                    <Box>
                        <Typography variant="h4" fontWeight="bold">
                            {totalRows}
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                            Total Certificates Issued
                        </Typography>
                    </Box>
                </Paper>
            </Box>

            <Paper sx={{ p: 2, mb: 2 }}>
                <TextField
                    fullWidth
                    size="small"
                    placeholder="Search by attendee name, email, event title, or certificate code..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
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
                    rows={filteredCertificates}
                    columns={columns}
                    loading={loading}
                    paginationModel={paginationModel}
                    onPaginationModelChange={setPaginationModel}
                    pageSizeOptions={[10, 25, 50]}
                    rowCount={totalRows}
                    paginationMode="server"
                    disableRowSelectionOnClick
                    autoHeight
                    sx={{
                        '& .MuiDataGrid-row:hover': {
                            backgroundColor: 'action.hover',
                        },
                    }}
                    localeText={{
                        noRowsLabel: 'No certificates issued yet',
                    }}
                />
            </Paper>
        </Box>
    );
};

export default OrganiserCertificates;

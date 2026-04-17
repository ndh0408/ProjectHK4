import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Typography,
    Button,
    Avatar,
    IconButton,
    Tooltip,
    Link,
    Grid,
} from '@mui/material';
import {
    Refresh as RefreshIcon,
    Download as DownloadIcon,
    Visibility as VisibilityIcon,
    WorkspacePremium as CertificateIcon,
} from '@mui/icons-material';
import { organiserApi } from '../../api';
import { toast } from 'react-toastify';
import {
    PageHeader,
    PageToolbar,
    DataTableCard,
    StatCard,
} from '../../components/ui';

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

    const filteredCertificates = certificates.filter((cert) => {
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
            headerName: 'Code',
            width: 170,
            renderCell: (params) => (
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.75, fontFamily: 'monospace' }}>
                    <CertificateIcon sx={{ color: 'primary.500', fontSize: 16 }} />
                    <Typography variant="body2" sx={{ fontWeight: 600 }}>
                        {params.value}
                    </Typography>
                </Box>
            ),
        },
        {
            field: 'userName',
            headerName: 'Attendee',
            flex: 1,
            minWidth: 220,
            renderCell: (params) => (
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.25, minWidth: 0 }}>
                    <Avatar sx={{ width: 32, height: 32, bgcolor: 'primary.500' }}>
                        {params.value?.charAt(0)?.toUpperCase() || '?'}
                    </Avatar>
                    <Box sx={{ minWidth: 0 }}>
                        <Typography variant="body2" sx={{ fontWeight: 600 }} noWrap>
                            {params.value}
                        </Typography>
                        <Typography variant="caption" color="text.secondary" noWrap sx={{ display: 'block' }}>
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
            renderCell: (p) => (
                <Typography variant="body2" noWrap sx={{ maxWidth: '100%' }}>{p.value}</Typography>
            ),
        },
        {
            field: 'eventDate',
            headerName: 'Event date',
            width: 130,
            valueFormatter: (params) => params.value ? new Date(params.value).toLocaleDateString() : '',
        },
        {
            field: 'generatedAt',
            headerName: 'Issued',
            width: 130,
            valueFormatter: (params) => params.value ? new Date(params.value).toLocaleDateString() : '',
        },
        {
            field: 'actions',
            headerName: 'Actions',
            width: 110,
            sortable: false,
            align: 'right',
            headerAlign: 'right',
            renderCell: (params) => {
                const baseUrl = process.env.REACT_APP_API_URL || 'http://localhost:8080';
                const viewUrl = `${baseUrl}/api/certificates/${params.row.certificateCode}/pdf`;
                const downloadUrl = `${baseUrl}/api/certificates/${params.row.certificateCode}/pdf?download=true`;
                return (
                    <Box sx={{ display: 'flex', gap: 0.25 }}>
                        <Tooltip title="Preview">
                            <IconButton
                                size="small"
                                onClick={() => window.open(viewUrl, '_blank')}
                                disabled={!params.row.certificateCode}
                            >
                                <VisibilityIcon fontSize="small" />
                            </IconButton>
                        </Tooltip>
                        <Tooltip title="Download">
                            <IconButton
                                size="small"
                                color="primary"
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
            <PageHeader
                title="Certificates"
                subtitle="View and download certificates issued for your events."
                icon={<CertificateIcon />}
                actions={
                    <Button
                        startIcon={<RefreshIcon fontSize="small" />}
                        onClick={loadCertificates}
                        variant="outlined"
                    >
                        Refresh
                    </Button>
                }
            />

            <Grid container spacing={2} sx={{ mb: 2 }}>
                <Grid item xs={12} sm={6} md={4}>
                    <StatCard
                        label="Total certificates"
                        value={totalRows.toLocaleString()}
                        icon={<CertificateIcon />}
                        iconColor="primary"
                        helper="Issued across your events"
                    />
                </Grid>
            </Grid>

            <DataTableCard
                rows={filteredCertificates}
                columns={columns}
                loading={loading}
                emptyTitle={searchQuery ? 'No certificates match your search' : 'No certificates issued yet'}
                emptyDescription={searchQuery
                    ? 'Try a different keyword or clear the search.'
                    : 'Certificates will appear here once attendees complete your events.'}
                emptyIcon={<CertificateIcon sx={{ fontSize: 28 }} />}
                toolbar={
                    <PageToolbar
                        search={searchQuery}
                        onSearchChange={setSearchQuery}
                        searchPlaceholder="Search attendee, event or code..."
                    />
                }
                dataGridProps={{
                    paginationModel,
                    onPaginationModelChange: setPaginationModel,
                    pageSizeOptions: [10, 25, 50],
                    rowCount: totalRows,
                    paginationMode: 'server',
                }}
            />
        </Box>
    );
};

export default OrganiserCertificates;

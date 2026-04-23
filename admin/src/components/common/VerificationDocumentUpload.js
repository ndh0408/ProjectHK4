import React, { useState } from 'react';
import {
    Box,
    Stack,
    Typography,
    IconButton,
    Grid,
    CircularProgress,
    ToggleButtonGroup,
    ToggleButton,
} from '@mui/material';
import {
    CloudUpload as UploadIcon,
    Delete as DeleteIcon,
    Badge as IdIcon,
    Description as LicenseIcon,
} from '@mui/icons-material';
import { toast } from 'react-toastify';
import { api } from '../../api';

const MAX_DOC_SIZE_MB = 10;

const DOC_META = {
    BUSINESS_LICENSE: {
        label: 'Business License',
        icon: <LicenseIcon />,
        helper: 'Business registration certificate',
        maxFiles: 1,
    },
    CITIZEN_ID: {
        label: 'Citizen ID',
        icon: <IdIcon />,
        helper: 'Upload both front and back',
        maxFiles: 2,
    },
};

/**
 * Reusable verification document uploader.
 *
 * Props:
 *  - fixedType: string | null (CITIZEN_ID or BUSINESS_LICENSE) — if set, hides the
 *    type selector and locks the document type. Used for apply flow (CCCD only) and
 *    badge-request flow (business licence only).
 *  - uploader: 'authenticated' (default) posts to /upload with auth
 *              'public' posts to the public apply endpoint (no auth).
 */
const VerificationDocumentUpload = ({
    documentType,
    onChangeDocumentType,
    documentUrls,
    onChangeDocumentUrls,
    folder = 'luma/organisers/verification',
    disabled = false,
    error = null,
    fixedType = null,
    uploader = 'authenticated',
}) => {
    const [uploading, setUploading] = useState(false);
    const effectiveType = fixedType || documentType;
    const meta = DOC_META[effectiveType] || DOC_META.BUSINESS_LICENSE;
    const maxFiles = meta.maxFiles;

    const handleFileUpload = async (file) => {
        if (!file) return;
        if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
            toast.error('Invalid file type. Allowed: JPG, PNG, WebP');
            return;
        }
        if (file.size > MAX_DOC_SIZE_MB * 1024 * 1024) {
            toast.error(`File size must be less than ${MAX_DOC_SIZE_MB}MB`);
            return;
        }

        setUploading(true);
        try {
            let url;
            if (uploader === 'public') {
                const { publicApi } = await import('../../api');
                const response = await publicApi.uploadOrganiserApplicationDocument(file);
                url = response.data.data.url;
            } else {
                const formData = new FormData();
                formData.append('file', file);
                formData.append('folder', folder);
                const response = await api.post('/upload', formData, {
                    headers: { 'Content-Type': 'multipart/form-data' },
                });
                url = response.data.data.url;
            }
            onChangeDocumentUrls([...documentUrls, url]);
        } catch (e) {
            toast.error(e.response?.data?.message || 'Failed to upload document');
        } finally {
            setUploading(false);
        }
    };

    const removeDocument = (index) => {
        onChangeDocumentUrls(documentUrls.filter((_, i) => i !== index));
    };

    const handleDocTypeChange = (_, value) => {
        if (!value) return;
        onChangeDocumentType?.(value);
        onChangeDocumentUrls([]);
    };

    return (
        <Box>
            {!fixedType && (
                <>
                    <Typography variant="subtitle2" sx={{ mb: 1 }}>
                        Document type
                    </Typography>
                    <ToggleButtonGroup
                        value={documentType}
                        exclusive
                        onChange={handleDocTypeChange}
                        disabled={disabled}
                        sx={{ mb: 3, flexWrap: 'wrap' }}
                    >
                        {Object.entries(DOC_META).map(([value, doc]) => (
                            <ToggleButton key={value} value={value} sx={{ px: 2.5, py: 1.25 }}>
                                <Stack direction="row" alignItems="center" spacing={1}>
                                    {doc.icon}
                                    <Box sx={{ textAlign: 'left' }}>
                                        <Typography variant="body2" fontWeight={600}>{doc.label}</Typography>
                                        <Typography variant="caption" color="text.secondary">{doc.helper}</Typography>
                                    </Box>
                                </Stack>
                            </ToggleButton>
                        ))}
                    </ToggleButtonGroup>
                </>
            )}

            {fixedType && (
                <Box
                    sx={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: 1.5,
                        mb: 2.5,
                        p: 1.5,
                        bgcolor: 'grey.50',
                        borderRadius: 2,
                        border: '1px solid',
                        borderColor: 'divider',
                    }}
                >
                    {meta.icon}
                    <Box>
                        <Typography variant="body2" fontWeight={600}>{meta.label}</Typography>
                        <Typography variant="caption" color="text.secondary">{meta.helper}</Typography>
                    </Box>
                </Box>
            )}

            <Typography variant="subtitle2" sx={{ mb: 1.5 }}>
                Document images
                <Typography component="span" color="text.secondary" sx={{ ml: 1, fontSize: '0.8125rem' }}>
                    ({documentUrls.length}/{maxFiles})
                </Typography>
            </Typography>

            <Grid container spacing={2}>
                {documentUrls.map((url, index) => (
                    <Grid item xs={12} sm={6} md={4} key={`${url}-${index}`}>
                        <Box
                            sx={{
                                position: 'relative',
                                borderRadius: 2,
                                border: '1px solid',
                                borderColor: 'divider',
                                overflow: 'hidden',
                                aspectRatio: '4/3',
                            }}
                        >
                            <img
                                src={url}
                                alt={`doc-${index}`}
                                style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
                            />
                            {!disabled && (
                                <IconButton
                                    size="small"
                                    onClick={() => removeDocument(index)}
                                    sx={{
                                        position: 'absolute',
                                        top: 6,
                                        right: 6,
                                        bgcolor: 'rgba(0,0,0,0.6)',
                                        color: 'white',
                                        '&:hover': { bgcolor: 'error.main' },
                                    }}
                                >
                                    <DeleteIcon fontSize="small" />
                                </IconButton>
                            )}
                        </Box>
                    </Grid>
                ))}

                {!disabled && documentUrls.length < maxFiles && (
                    <Grid item xs={12} sm={6} md={4}>
                        <Box
                            component="label"
                            sx={{
                                borderRadius: 2,
                                border: '2px dashed',
                                borderColor: error ? 'error.main' : 'divider',
                                aspectRatio: '4/3',
                                display: 'flex',
                                flexDirection: 'column',
                                alignItems: 'center',
                                justifyContent: 'center',
                                cursor: uploading ? 'wait' : 'pointer',
                                bgcolor: 'grey.50',
                                '&:hover': { borderColor: 'primary.main', bgcolor: 'primary.50' },
                            }}
                        >
                            <input
                                type="file"
                                accept="image/jpeg,image/png,image/webp"
                                hidden
                                disabled={uploading}
                                onChange={(e) => {
                                    const file = e.target.files?.[0];
                                    if (file) handleFileUpload(file);
                                    e.target.value = '';
                                }}
                            />
                            {uploading ? (
                                <>
                                    <CircularProgress size={32} />
                                    <Typography variant="caption" color="text.secondary" sx={{ mt: 1 }}>
                                        Uploading...
                                    </Typography>
                                </>
                            ) : (
                                <>
                                    <UploadIcon sx={{ fontSize: 36, color: 'text.secondary', mb: 0.5 }} />
                                    <Typography variant="body2" color="text.secondary">
                                        Click to upload
                                    </Typography>
                                    <Typography variant="caption" color="text.disabled">
                                        JPG, PNG, WebP — max {MAX_DOC_SIZE_MB}MB
                                    </Typography>
                                </>
                            )}
                        </Box>
                    </Grid>
                )}
            </Grid>

            {error && (
                <Typography variant="caption" color="error" sx={{ mt: 1, display: 'block' }}>
                    {error}
                </Typography>
            )}
        </Box>
    );
};

export default VerificationDocumentUpload;

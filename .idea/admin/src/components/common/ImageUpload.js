import React, { useState, useRef } from 'react';
import {
    Box,
    Button,
    Typography,
    CircularProgress,
    IconButton,
} from '@mui/material';
import {
    CloudUpload as UploadIcon,
    Delete as DeleteIcon,
    Image as ImageIcon,
} from '@mui/icons-material';
import { toast } from 'react-toastify';
import { api } from '../../api';

const ImageUpload = ({
    value,
    onChange,
    label = 'Upload Image',
    error,
    helperText,
    folder = 'luma',
    maxSize = 5,
    acceptedFormats = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'],
}) => {
    const [uploading, setUploading] = useState(false);
    const [dragOver, setDragOver] = useState(false);
    const fileInputRef = useRef(null);

    const validateFile = (file) => {
        if (!acceptedFormats.includes(file.type)) {
            toast.error(`Invalid file type. Accepted formats: ${acceptedFormats.map(f => f.split('/')[1]).join(', ')}`);
            return false;
        }

        const fileSizeMB = file.size / (1024 * 1024);
        if (fileSizeMB > maxSize) {
            toast.error(`File size must be less than ${maxSize}MB`);
            return false;
        }

        return true;
    };

    const uploadToBackend = async (file) => {
        const formData = new FormData();
        formData.append('file', file);
        formData.append('folder', folder);

        try {
            const response = await api.post('/upload', formData, {
                headers: {
                    'Content-Type': 'multipart/form-data',
                },
            });
            return response.data.data.url;
        } catch (error) {
            console.error('Upload error:', error);
            throw error;
        }
    };

    const handleFileSelect = async (file) => {
        if (!file || !validateFile(file)) return;

        setUploading(true);
        try {
            const imageUrl = await uploadToBackend(file);
            onChange(imageUrl);
            toast.success('Image uploaded successfully');
        } catch (error) {
            toast.error('Failed to upload image. Please try again.');
        } finally {
            setUploading(false);
        }
    };

    const handleInputChange = (e) => {
        const file = e.target.files?.[0];
        if (file) {
            handleFileSelect(file);
        }
    };

    const handleDrop = (e) => {
        e.preventDefault();
        setDragOver(false);
        const file = e.dataTransfer.files?.[0];
        if (file) {
            handleFileSelect(file);
        }
    };

    const handleDragOver = (e) => {
        e.preventDefault();
        setDragOver(true);
    };

    const handleDragLeave = (e) => {
        e.preventDefault();
        setDragOver(false);
    };

    const handleRemove = () => {
        onChange('');
        if (fileInputRef.current) {
            fileInputRef.current.value = '';
        }
    };

    const handleClick = () => {
        fileInputRef.current?.click();
    };

    return (
        <Box>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                {label}
            </Typography>

            <input
                ref={fileInputRef}
                type="file"
                accept={acceptedFormats.join(',')}
                onChange={handleInputChange}
                style={{ display: 'none' }}
            />

            {value ? (
                <Box
                    sx={{
                        position: 'relative',
                        width: '100%',
                        maxWidth: 300,
                        borderRadius: 2,
                        overflow: 'hidden',
                        border: error ? '2px solid' : '1px solid',
                        borderColor: error ? 'error.main' : 'divider',
                    }}
                >
                    <img
                        src={value}
                        alt="Uploaded"
                        style={{
                            width: '100%',
                            height: 180,
                            objectFit: 'cover',
                            display: 'block',
                        }}
                    />
                    <Box
                        sx={{
                            position: 'absolute',
                            top: 0,
                            right: 0,
                            p: 0.5,
                        }}
                    >
                        <IconButton
                            size="small"
                            onClick={handleRemove}
                            sx={{
                                bgcolor: 'rgba(0,0,0,0.6)',
                                color: 'white',
                                '&:hover': { bgcolor: 'error.main' },
                            }}
                        >
                            <DeleteIcon fontSize="small" />
                        </IconButton>
                    </Box>
                    <Box
                        sx={{
                            position: 'absolute',
                            bottom: 0,
                            left: 0,
                            right: 0,
                            p: 1,
                            bgcolor: 'rgba(0,0,0,0.6)',
                        }}
                    >
                        <Button
                            size="small"
                            onClick={handleClick}
                            sx={{ color: 'white' }}
                            startIcon={<UploadIcon />}
                        >
                            Change Image
                        </Button>
                    </Box>
                </Box>
            ) : (
                <Box
                    onClick={handleClick}
                    onDrop={handleDrop}
                    onDragOver={handleDragOver}
                    onDragLeave={handleDragLeave}
                    sx={{
                        width: '100%',
                        maxWidth: 300,
                        height: 180,
                        border: '2px dashed',
                        borderColor: error ? 'error.main' : dragOver ? 'primary.main' : 'divider',
                        borderRadius: 2,
                        display: 'flex',
                        flexDirection: 'column',
                        alignItems: 'center',
                        justifyContent: 'center',
                        cursor: 'pointer',
                        bgcolor: dragOver ? 'action.hover' : 'background.paper',
                        transition: 'all 0.2s ease',
                        '&:hover': {
                            borderColor: 'primary.main',
                            bgcolor: 'action.hover',
                        },
                    }}
                >
                    {uploading ? (
                        <>
                            <CircularProgress size={40} sx={{ mb: 1 }} />
                            <Typography variant="body2" color="text.secondary">
                                Uploading...
                            </Typography>
                        </>
                    ) : (
                        <>
                            <ImageIcon sx={{ fontSize: 48, color: 'text.disabled', mb: 1 }} />
                            <Typography variant="body2" color="text.secondary" textAlign="center">
                                Drag & drop or click to upload
                            </Typography>
                            <Typography variant="caption" color="text.disabled">
                                Max {maxSize}MB (JPG, PNG, WebP, GIF)
                            </Typography>
                        </>
                    )}
                </Box>
            )}

            {helperText && (
                <Typography
                    variant="caption"
                    color={error ? 'error' : 'text.secondary'}
                    sx={{ mt: 0.5, display: 'block' }}
                >
                    {helperText}
                </Typography>
            )}
        </Box>
    );
};

export default ImageUpload;

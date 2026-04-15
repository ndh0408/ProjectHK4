import React, { useState, useEffect } from 'react';
import {
    Box,
    Typography,
    Paper,
    Button,
    IconButton,
    Chip,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    TextField,
    FormControlLabel,
    Switch,
} from '@mui/material';
import { DataGrid } from '@mui/x-data-grid';
import {
    Add as AddIcon,
    Edit as EditIcon,
    Delete as DeleteIcon,
    Refresh as RefreshIcon,
} from '@mui/icons-material';
import { adminApi } from '../../api';
import { ConfirmDialog } from '../../components/common';
import { toast } from 'react-toastify';

const Categories = () => {
    const [categories, setCategories] = useState([]);
    const [loading, setLoading] = useState(true);
    const [dialogOpen, setDialogOpen] = useState(false);
    const [editCategory, setEditCategory] = useState(null);
    const [formData, setFormData] = useState({ name: '', description: '', active: true });
    const [formErrors, setFormErrors] = useState({});
    const [confirmDialog, setConfirmDialog] = useState({ open: false, title: '', message: '', action: null });

    useEffect(() => {
        loadCategories();
    }, []);

    const loadCategories = async () => {
        setLoading(true);
        try {
            const response = await adminApi.getCategories();
            setCategories(response.data.data || []);
        } catch (error) {
            toast.error('Failed to load categories');
        } finally {
            setLoading(false);
        }
    };

    const handleOpenDialog = (category = null) => {
        if (category) {
            setEditCategory(category);
            setFormData({
                name: category.name,
                description: category.description || '',
                active: category.active,
            });
        } else {
            setEditCategory(null);
            setFormData({ name: '', description: '', active: true });
        }
        setDialogOpen(true);
        setFormErrors({});
    };

    const handleCloseDialog = () => {
        setDialogOpen(false);
        setEditCategory(null);
        setFormData({ name: '', description: '', active: true });
        setFormErrors({});
    };

    const validateForm = () => {
        const errors = {};

        if (!formData.name.trim()) {
            errors.name = 'Category name is required';
        } else if (formData.name.trim().length < 2) {
            errors.name = 'Category name must be at least 2 characters';
        } else if (formData.name.trim().length > 50) {
            errors.name = 'Category name must be less than 50 characters';
        }

        const duplicate = categories.find(
            cat => cat.name.toLowerCase() === formData.name.trim().toLowerCase() && cat.id !== editCategory?.id
        );
        if (duplicate) {
            errors.name = 'A category with this name already exists';
        }

        if (formData.description && formData.description.length > 200) {
            errors.description = 'Description must be less than 200 characters';
        }

        setFormErrors(errors);
        return Object.keys(errors).length === 0;
    };

    const handleSubmit = async () => {
        if (!validateForm()) {
            toast.error('Please fix the errors in the form');
            return;
        }

        try {
            if (editCategory) {
                await adminApi.updateCategory(editCategory.id, formData);
                toast.success('Category updated successfully');
            } else {
                await adminApi.createCategory(formData);
                toast.success('Category created successfully');
            }
            handleCloseDialog();
            loadCategories();
        } catch (error) {
            toast.error(error.response?.data?.message || 'Failed to save category');
        }
    };

    const handleDelete = (category) => {
        setConfirmDialog({
            open: true,
            title: 'Delete Category',
            message: `Are you sure you want to delete "${category.name}"? This action cannot be undone.`,
            confirmColor: 'error',
            action: async () => {
                try {
                    await adminApi.deleteCategory(category.id);
                    toast.success('Category deleted successfully');
                    loadCategories();
                } catch (error) {
                    toast.error('Failed to delete category');
                }
            },
        });
    };

    const columns = [
        {
            field: 'name',
            headerName: 'Name',
            flex: 1,
            minWidth: 150,
        },
        {
            field: 'description',
            headerName: 'Description',
            flex: 2,
            minWidth: 200,
        },
        {
            field: 'active',
            headerName: 'Status',
            width: 120,
            renderCell: (params) => (
                <Chip
                    label={params.value ? 'Active' : 'Inactive'}
                    size="small"
                    color={params.value ? 'success' : 'default'}
                />
            ),
        },
        {
            field: 'actions',
            headerName: 'Actions',
            width: 120,
            sortable: false,
            renderCell: (params) => (
                <Box>
                    <IconButton
                        size="small"
                        onClick={() => handleOpenDialog(params.row)}
                    >
                        <EditIcon />
                    </IconButton>
                    <IconButton
                        size="small"
                        color="error"
                        onClick={() => handleDelete(params.row)}
                    >
                        <DeleteIcon />
                    </IconButton>
                </Box>
            ),
        },
    ];

    return (
        <Box>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                <Typography variant="h5" fontWeight="bold">
                    Category Management
                </Typography>
                <Box sx={{ display: 'flex', gap: 1 }}>
                    <Button startIcon={<RefreshIcon />} onClick={loadCategories}>
                        Refresh
                    </Button>
                    <Button
                        variant="contained"
                        startIcon={<AddIcon />}
                        onClick={() => handleOpenDialog()}
                    >
                        Add Category
                    </Button>
                </Box>
            </Box>

            <Paper>
                <DataGrid
                    rows={categories}
                    columns={columns}
                    loading={loading}
                    pageSizeOptions={[10, 25, 50]}
                    disableRowSelectionOnClick
                    autoHeight
                    initialState={{
                        pagination: { paginationModel: { pageSize: 10 } },
                    }}
                />
            </Paper>

            <Dialog open={dialogOpen} onClose={handleCloseDialog} maxWidth="sm" fullWidth>
                <DialogTitle>
                    {editCategory ? 'Edit Category' : 'Add Category'}
                </DialogTitle>
                <DialogContent>
                    <TextField
                        fullWidth
                        label="Name"
                        value={formData.name}
                        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                        margin="normal"
                        required
                        error={!!formErrors.name}
                        helperText={formErrors.name || 'Between 2-50 characters'}
                    />
                    <TextField
                        fullWidth
                        label="Description"
                        value={formData.description}
                        onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                        margin="normal"
                        multiline
                        rows={3}
                        error={!!formErrors.description}
                        helperText={formErrors.description || 'Optional, max 200 characters'}
                    />
                    <FormControlLabel
                        control={
                            <Switch
                                checked={formData.active}
                                onChange={(e) => setFormData({ ...formData, active: e.target.checked })}
                            />
                        }
                        label="Active"
                        sx={{ mt: 2 }}
                    />
                </DialogContent>
                <DialogActions>
                    <Button onClick={handleCloseDialog}>Cancel</Button>
                    <Button onClick={handleSubmit} variant="contained">
                        {editCategory ? 'Update' : 'Create'}
                    </Button>
                </DialogActions>
            </Dialog>

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

export default Categories;

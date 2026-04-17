import React, { useState, useEffect, useMemo } from 'react';
import {
    Box,
    Button,
    IconButton,
    TextField,
    FormControlLabel,
    Switch,
    Stack,
    Tooltip,
} from '@mui/material';
import {
    Add as AddIcon,
    Edit as EditIcon,
    Delete as DeleteIcon,
    Refresh as RefreshIcon,
    Category as CategoryIcon,
} from '@mui/icons-material';
import { adminApi } from '../../api';
import { ConfirmDialog } from '../../components/common';
import {
    PageHeader,
    PageToolbar,
    DataTableCard,
    StatusChip,
    FormDialog,
    LoadingButton,
} from '../../components/ui';
import { toast } from 'react-toastify';

const Categories = () => {
    const [categories, setCategories] = useState([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');
    const [dialogOpen, setDialogOpen] = useState(false);
    const [editCategory, setEditCategory] = useState(null);
    const [formData, setFormData] = useState({ name: '', description: '', active: true });
    const [formErrors, setFormErrors] = useState({});
    const [submitting, setSubmitting] = useState(false);
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
        if (duplicate) errors.name = 'A category with this name already exists';
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
        setSubmitting(true);
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
        } finally {
            setSubmitting(false);
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

    const filteredRows = useMemo(() => {
        if (!search.trim()) return categories;
        const q = search.trim().toLowerCase();
        return categories.filter((c) =>
            c.name?.toLowerCase().includes(q)
            || c.description?.toLowerCase().includes(q),
        );
    }, [categories, search]);

    const columns = [
        { field: 'name', headerName: 'Name', flex: 1, minWidth: 180 },
        { field: 'description', headerName: 'Description', flex: 2, minWidth: 220 },
        {
            field: 'active',
            headerName: 'Status',
            width: 120,
            renderCell: (params) => (
                <StatusChip
                    label={params.value ? 'Active' : 'Inactive'}
                    status={params.value ? 'success' : 'neutral'}
                />
            ),
        },
        {
            field: 'actions',
            headerName: 'Actions',
            width: 120,
            sortable: false,
            align: 'right',
            headerAlign: 'right',
            renderCell: (params) => (
                <Stack direction="row" spacing={0.5}>
                    <Tooltip title="Edit">
                        <IconButton size="small" onClick={() => handleOpenDialog(params.row)}>
                            <EditIcon fontSize="small" />
                        </IconButton>
                    </Tooltip>
                    <Tooltip title="Delete">
                        <IconButton
                            size="small"
                            color="error"
                            onClick={() => handleDelete(params.row)}
                        >
                            <DeleteIcon fontSize="small" />
                        </IconButton>
                    </Tooltip>
                </Stack>
            ),
        },
    ];

    return (
        <Box>
            <PageHeader
                title="Categories"
                subtitle="Organise events into discoverable categories."
                icon={<CategoryIcon />}
                actions={[
                    <Button
                        key="refresh"
                        variant="outlined"
                        startIcon={<RefreshIcon fontSize="small" />}
                        onClick={loadCategories}
                    >
                        Refresh
                    </Button>,
                    <Button
                        key="add"
                        variant="contained"
                        startIcon={<AddIcon fontSize="small" />}
                        onClick={() => handleOpenDialog()}
                    >
                        Add category
                    </Button>,
                ]}
            />

            <DataTableCard
                rows={filteredRows}
                columns={columns}
                loading={loading}
                emptyTitle={search ? 'No categories match your search' : 'No categories yet'}
                emptyDescription={search
                    ? 'Try a different keyword or clear the search.'
                    : 'Create your first category to classify events.'}
                emptyIcon={<CategoryIcon sx={{ fontSize: 28 }} />}
                emptyAction={!search && (
                    <Button
                        variant="contained"
                        startIcon={<AddIcon fontSize="small" />}
                        onClick={() => handleOpenDialog()}
                    >
                        Add category
                    </Button>
                )}
                toolbar={
                    <PageToolbar
                        search={search}
                        onSearchChange={setSearch}
                        searchPlaceholder="Search categories..."
                    />
                }
                dataGridProps={{
                    initialState: {
                        pagination: { paginationModel: { pageSize: 10 } },
                    },
                }}
            />

            <FormDialog
                open={dialogOpen}
                onClose={handleCloseDialog}
                title={editCategory ? 'Edit category' : 'Add category'}
                subtitle={editCategory
                    ? 'Update the details for this category.'
                    : 'Create a new category to organise events.'}
                icon={<CategoryIcon />}
                actions={(
                    <>
                        <Button onClick={handleCloseDialog} disabled={submitting}>
                            Cancel
                        </Button>
                        <LoadingButton
                            variant="contained"
                            onClick={handleSubmit}
                            loading={submitting}
                        >
                            {editCategory ? 'Save changes' : 'Create category'}
                        </LoadingButton>
                    </>
                )}
            >
                <Stack spacing={2.25}>
                    <TextField
                        fullWidth
                        label="Name"
                        value={formData.name}
                        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                        required
                        error={!!formErrors.name}
                        helperText={formErrors.name || 'Between 2 and 50 characters'}
                    />
                    <TextField
                        fullWidth
                        label="Description"
                        value={formData.description}
                        onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                        multiline
                        minRows={3}
                        error={!!formErrors.description}
                        helperText={formErrors.description || 'Optional, max 200 characters'}
                    />
                    <FormControlLabel
                        control={(
                            <Switch
                                checked={formData.active}
                                onChange={(e) => setFormData({ ...formData, active: e.target.checked })}
                            />
                        )}
                        label={formData.active ? 'Active' : 'Inactive'}
                    />
                </Stack>
            </FormDialog>

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

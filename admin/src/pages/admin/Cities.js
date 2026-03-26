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
    FormControl,
    InputLabel,
    Select,
    MenuItem,
} from '@mui/material';
import { DataGrid } from '@mui/x-data-grid';
import {
    Add as AddIcon,
    Edit as EditIcon,
    Delete as DeleteIcon,
    Refresh as RefreshIcon,
} from '@mui/icons-material';
import { adminApi } from '../../api';
import { ConfirmDialog, ImageUpload } from '../../components/common';
import { toast } from 'react-toastify';

const CONTINENTS = ['Asia', 'Europe', 'North America', 'South America', 'Africa', 'Australia', 'Antarctica'];

const Cities = () => {
    const [cities, setCities] = useState([]);
    const [loading, setLoading] = useState(true);
    const [dialogOpen, setDialogOpen] = useState(false);
    const [editCity, setEditCity] = useState(null);
    const [formData, setFormData] = useState({
        name: '',
        country: '',
        continent: '',
        imageUrl: '',
        active: true,
    });
    const [formErrors, setFormErrors] = useState({});
    const [confirmDialog, setConfirmDialog] = useState({ open: false, title: '', message: '', action: null });

    useEffect(() => {
        loadCities();
    }, []);

    const loadCities = async () => {
        setLoading(true);
        try {
            const response = await adminApi.getCities();
            setCities(response.data.data || []);
        } catch (error) {
            toast.error('Failed to load cities');
        } finally {
            setLoading(false);
        }
    };

    const handleOpenDialog = (city = null) => {
        if (city) {
            setEditCity(city);
            setFormData({
                name: city.name,
                country: city.country || '',
                continent: city.continent || '',
                imageUrl: city.imageUrl || '',
                active: city.active,
            });
        } else {
            setEditCity(null);
            setFormData({ name: '', country: '', continent: '', imageUrl: '', active: true });
        }
        setDialogOpen(true);
        setFormErrors({});
    };

    const handleCloseDialog = () => {
        setDialogOpen(false);
        setEditCity(null);
        setFormData({ name: '', country: '', continent: '', imageUrl: '', active: true });
        setFormErrors({});
    };

    const validateForm = () => {
        const errors = {};

        if (!formData.name.trim()) {
            errors.name = 'City name is required';
        } else if (formData.name.trim().length < 2) {
            errors.name = 'City name must be at least 2 characters';
        } else if (formData.name.trim().length > 100) {
            errors.name = 'City name must be less than 100 characters';
        }

        const duplicate = cities.find(
            city => city.name.toLowerCase() === formData.name.trim().toLowerCase()
                && city.country?.toLowerCase() === formData.country?.trim().toLowerCase()
                && city.id !== editCity?.id
        );
        if (duplicate) {
            errors.name = 'This city already exists in the selected country';
        }

        if (!formData.country.trim()) {
            errors.country = 'Country is required';
        } else if (formData.country.trim().length < 2) {
            errors.country = 'Country name must be at least 2 characters';
        }

        if (!formData.continent) {
            errors.continent = 'Continent is required';
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
            if (editCity) {
                await adminApi.updateCity(editCity.id, formData);
                toast.success('City updated successfully');
            } else {
                await adminApi.createCity(formData);
                toast.success('City created successfully');
            }
            handleCloseDialog();
            loadCities();
        } catch (error) {
            toast.error(error.response?.data?.message || 'Failed to save city');
        }
    };

    const handleDelete = (city) => {
        setConfirmDialog({
            open: true,
            title: 'Delete City',
            message: `Are you sure you want to delete "${city.name}"? This action cannot be undone.`,
            confirmColor: 'error',
            action: async () => {
                try {
                    await adminApi.deleteCity(city.id);
                    toast.success('City deleted successfully');
                    loadCities();
                } catch (error) {
                    toast.error('Failed to delete city');
                }
            },
        });
    };

    const columns = [
        {
            field: 'name',
            headerName: 'City',
            flex: 1,
            minWidth: 150,
        },
        {
            field: 'country',
            headerName: 'Country',
            flex: 1,
            minWidth: 150,
        },
        {
            field: 'continent',
            headerName: 'Continent',
            width: 150,
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
                    City Management
                </Typography>
                <Box sx={{ display: 'flex', gap: 1 }}>
                    <Button startIcon={<RefreshIcon />} onClick={loadCities}>
                        Refresh
                    </Button>
                    <Button
                        variant="contained"
                        startIcon={<AddIcon />}
                        onClick={() => handleOpenDialog()}
                    >
                        Add City
                    </Button>
                </Box>
            </Box>

            <Paper sx={{ width: '100%', overflow: 'hidden' }}>
                <Box sx={{ width: '100%', overflowX: 'auto' }}>
                    <DataGrid
                        rows={cities}
                        columns={columns}
                        loading={loading}
                        pageSizeOptions={[10, 25, 50]}
                        disableRowSelectionOnClick
                        autoHeight
                        initialState={{
                            pagination: { paginationModel: { pageSize: 10 } },
                        }}
                        sx={{ minWidth: 600 }}
                    />
                </Box>
            </Paper>

            <Dialog open={dialogOpen} onClose={handleCloseDialog} maxWidth="sm" fullWidth>
                <DialogTitle>
                    {editCity ? 'Edit City' : 'Add City'}
                </DialogTitle>
                <DialogContent>
                    <TextField
                        fullWidth
                        label="City Name"
                        value={formData.name}
                        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                        margin="normal"
                        required
                        error={!!formErrors.name}
                        helperText={formErrors.name}
                    />
                    <TextField
                        fullWidth
                        label="Country"
                        value={formData.country}
                        onChange={(e) => setFormData({ ...formData, country: e.target.value })}
                        margin="normal"
                        required
                        error={!!formErrors.country}
                        helperText={formErrors.country}
                    />
                    <FormControl fullWidth margin="normal" required error={!!formErrors.continent}>
                        <InputLabel>Continent</InputLabel>
                        <Select
                            value={formData.continent}
                            onChange={(e) => setFormData({ ...formData, continent: e.target.value })}
                            label="Continent"
                        >
                            {CONTINENTS.map((continent) => (
                                <MenuItem key={continent} value={continent}>
                                    {continent}
                                </MenuItem>
                            ))}
                        </Select>
                        {formErrors.continent && (
                            <Typography variant="caption" color="error" sx={{ mt: 0.5, ml: 1.5 }}>
                                {formErrors.continent}
                            </Typography>
                        )}
                    </FormControl>
                    <Box sx={{ mt: 2 }}>
                        <ImageUpload
                            value={formData.imageUrl}
                            onChange={(url) => setFormData({ ...formData, imageUrl: url })}
                            label="City Image"
                            folder="luma/cities"
                            error={!!formErrors.imageUrl}
                            helperText={formErrors.imageUrl}
                        />
                    </Box>
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
                        {editCity ? 'Update' : 'Create'}
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

export default Cities;

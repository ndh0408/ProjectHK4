import React, { useState, useEffect, useMemo } from 'react';
import {
    Box,
    Button,
    IconButton,
    TextField,
    FormControlLabel,
    Switch,
    FormControl,
    InputLabel,
    Select,
    MenuItem,
    FormHelperText,
    Stack,
    Tooltip,
} from '@mui/material';
import {
    Add as AddIcon,
    Edit as EditIcon,
    Delete as DeleteIcon,
    Refresh as RefreshIcon,
    LocationCity as CityIcon,
} from '@mui/icons-material';
import { adminApi } from '../../api';
import { ConfirmDialog, ImageUpload } from '../../components/common';
import {
    PageHeader,
    PageToolbar,
    DataTableCard,
    StatusChip,
    FormDialog,
    FormSection,
    LoadingButton,
} from '../../components/ui';
import { toast } from 'react-toastify';

const CONTINENTS = ['Asia', 'Europe', 'North America', 'South America', 'Africa', 'Australia', 'Antarctica'];

const Cities = () => {
    const [cities, setCities] = useState([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');
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
    const [submitting, setSubmitting] = useState(false);
    const [confirmDialog, setConfirmDialog] = useState({ open: false, title: '', message: '', action: null });

    useEffect(() => { loadCities(); }, []);

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
        if (!formData.name.trim()) errors.name = 'City name is required';
        else if (formData.name.trim().length < 2) errors.name = 'City name must be at least 2 characters';
        else if (formData.name.trim().length > 100) errors.name = 'City name must be less than 100 characters';

        const duplicate = cities.find(
            city => city.name.toLowerCase() === formData.name.trim().toLowerCase()
                && city.country?.toLowerCase() === formData.country?.trim().toLowerCase()
                && city.id !== editCity?.id
        );
        if (duplicate) errors.name = 'This city already exists in the selected country';

        if (!formData.country.trim()) errors.country = 'Country is required';
        else if (formData.country.trim().length < 2) errors.country = 'Country name must be at least 2 characters';

        if (!formData.continent) errors.continent = 'Continent is required';

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
        } finally {
            setSubmitting(false);
        }
    };

    const handleDelete = (city) => {
        setConfirmDialog({
            open: true,
            title: 'Delete city',
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

    const filteredRows = useMemo(() => {
        if (!search.trim()) return cities;
        const q = search.trim().toLowerCase();
        return cities.filter((c) =>
            c.name?.toLowerCase().includes(q)
            || c.country?.toLowerCase().includes(q)
            || c.continent?.toLowerCase().includes(q),
        );
    }, [cities, search]);

    const columns = [
        { field: 'name', headerName: 'City', flex: 1, minWidth: 160 },
        { field: 'country', headerName: 'Country', flex: 1, minWidth: 150 },
        { field: 'continent', headerName: 'Continent', width: 160 },
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
                title="Cities"
                subtitle="Maintain the list of cities where events can take place."
                icon={<CityIcon />}
                actions={[
                    <Button
                        key="refresh"
                        variant="outlined"
                        startIcon={<RefreshIcon fontSize="small" />}
                        onClick={loadCities}
                    >
                        Refresh
                    </Button>,
                    <Button
                        key="add"
                        variant="contained"
                        startIcon={<AddIcon fontSize="small" />}
                        onClick={() => handleOpenDialog()}
                    >
                        Add city
                    </Button>,
                ]}
            />

            <DataTableCard
                rows={filteredRows}
                columns={columns}
                loading={loading}
                emptyTitle={search ? 'No cities match your search' : 'No cities yet'}
                emptyDescription={search
                    ? 'Try a different keyword or clear the search.'
                    : 'Add the first city to start listing events here.'}
                emptyIcon={<CityIcon sx={{ fontSize: 28 }} />}
                emptyAction={!search && (
                    <Button
                        variant="contained"
                        startIcon={<AddIcon fontSize="small" />}
                        onClick={() => handleOpenDialog()}
                    >
                        Add city
                    </Button>
                )}
                toolbar={
                    <PageToolbar
                        search={search}
                        onSearchChange={setSearch}
                        searchPlaceholder="Search cities, countries..."
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
                title={editCity ? 'Edit city' : 'Add city'}
                subtitle={editCity ? 'Update city information.' : 'Create a new location entry.'}
                icon={<CityIcon />}
                maxWidth="sm"
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
                            {editCity ? 'Save changes' : 'Create city'}
                        </LoadingButton>
                    </>
                )}
            >
                <FormSection title="Location">
                    <Stack spacing={2.25}>
                        <TextField
                            fullWidth
                            label="City name"
                            value={formData.name}
                            onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                            required
                            error={!!formErrors.name}
                            helperText={formErrors.name || ' '}
                        />
                        <TextField
                            fullWidth
                            label="Country"
                            value={formData.country}
                            onChange={(e) => setFormData({ ...formData, country: e.target.value })}
                            required
                            error={!!formErrors.country}
                            helperText={formErrors.country || ' '}
                        />
                        <FormControl fullWidth required error={!!formErrors.continent} size="small">
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
                                <FormHelperText>{formErrors.continent}</FormHelperText>
                            )}
                        </FormControl>
                    </Stack>
                </FormSection>

                <FormSection title="Appearance" description="Optional hero image shown on discovery pages." topDivider>
                    <ImageUpload
                        value={formData.imageUrl}
                        onChange={(url) => setFormData({ ...formData, imageUrl: url })}
                        label="City image"
                        folder="luma/cities"
                        error={!!formErrors.imageUrl}
                        helperText={formErrors.imageUrl}
                    />
                </FormSection>

                <FormSection title="Availability" topDivider>
                    <FormControlLabel
                        control={(
                            <Switch
                                checked={formData.active}
                                onChange={(e) => setFormData({ ...formData, active: e.target.checked })}
                            />
                        )}
                        label={formData.active ? 'Active — visible to users' : 'Inactive — hidden from users'}
                    />
                </FormSection>
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

export default Cities;

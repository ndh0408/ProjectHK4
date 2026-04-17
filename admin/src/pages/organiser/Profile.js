import React, { useState, useEffect } from 'react';
import {
    Box,
    Typography,
    TextField,
    Button,
    Avatar,
    Grid,
    Divider,
    Alert,
    CircularProgress,
    Stack,
} from '@mui/material';
import {
    Save as SaveIcon,
    PhotoCamera as CameraIcon,
    Verified as VerifiedIcon,
    AutoAwesome as AIIcon,
    AccountCircle as ProfileIcon,
} from '@mui/icons-material';
import MDEditor from '@uiw/react-md-editor';
import { organiserApi } from '../../api';
import { LoadingSpinner } from '../../components/common';
import {
    PageHeader,
    SectionCard,
    FormSection,
    LoadingButton,
    StatusChip,
} from '../../components/ui';
import { tokens } from '../../theme';
import { toast } from 'react-toastify';

const OrganiserProfile = () => {
    const [profile, setProfile] = useState(null);
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [uploadingAvatar, setUploadingAvatar] = useState(false);
    const [generatingBio, setGeneratingBio] = useState(false);
    const [formData, setFormData] = useState({
        displayName: '',
        bio: '',
        website: '',
        contactEmail: '',
        contactPhone: '',
    });
    const [formErrors, setFormErrors] = useState({});

    useEffect(() => {
        loadProfile();
    }, []);

    const loadProfile = async () => {
        try {
            const response = await organiserApi.getProfile();
            const data = response.data.data;
            setProfile(data);
            setFormData({
                displayName: data.displayName || data.organizationName || '',
                bio: data.bio || '',
                website: data.website || '',
                contactEmail: data.contactEmail || '',
                contactPhone: data.contactPhone || '',
            });
        } catch (error) {
            toast.error('Failed to load profile');
        } finally {
            setLoading(false);
        }
    };

    const isValidUrl = (url) => {
        if (!url) return true;
        const urlPattern = /^(https?:\/\/)?([\da-z.-]+)\.([a-z.]{2,6})([/\w .-]*)*\/?$/;
        return urlPattern.test(url);
    };

    const validateForm = () => {
        const errors = {};

        if (!formData.displayName.trim()) {
            errors.displayName = 'Organization name is required';
        } else if (formData.displayName.trim().length < 2) {
            errors.displayName = 'Organization name must be at least 2 characters';
        } else if (formData.displayName.trim().length > 100) {
            errors.displayName = 'Organization name must be less than 100 characters';
        }

        if (formData.website && !isValidUrl(formData.website)) {
            errors.website = 'Please enter a valid website URL';
        }

        if (formData.contactEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.contactEmail)) {
            errors.contactEmail = 'Please enter a valid email address';
        }

        setFormErrors(errors);
        return Object.keys(errors).length === 0;
    };

    const handleSubmit = async (e) => {
        e.preventDefault();

        if (!validateForm()) {
            toast.error('Please fix the errors in the form');
            return;
        }

        setSaving(true);

        try {
            await organiserApi.updateProfile(formData);
            toast.success('Profile updated successfully');
            loadProfile();
        } catch (error) {
            toast.error(error.response?.data?.message || 'Failed to update profile');
        } finally {
            setSaving(false);
        }
    };

    const handleAvatarUpload = async (e) => {
        const file = e.target.files?.[0];
        if (!file) return;

        if (file.size > 10 * 1024 * 1024) {
            toast.error('File size must be less than 10MB');
            return;
        }

        const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
        if (!allowedTypes.includes(file.type)) {
            toast.error('Invalid file type. Allowed: JPG, PNG, WebP, GIF');
            return;
        }

        setUploadingAvatar(true);
        try {
            await organiserApi.uploadAvatar(file);
            toast.success('Avatar updated successfully');
            loadProfile();
        } catch (error) {
            console.error('Avatar upload error:', error);
            toast.error(error.response?.data?.message || 'Failed to upload avatar');
        } finally {
            setUploadingAvatar(false);
        }
    };

    const handleGenerateBio = async () => {
        if (!formData.displayName) {
            toast.error('Please enter organization name first');
            return;
        }

        setGeneratingBio(true);
        try {
            const response = await organiserApi.generateBio({
                organizationName: formData.displayName,
                eventTypes: '',
                targetAudience: '',
                additionalInfo: formData.website || '',
            });
            if (response.data?.data) {
                setFormData({ ...formData, bio: response.data.data });
                toast.success('Bio generated successfully!');
            }
        } catch (error) {
            console.error('Failed to generate bio:', error);
            toast.error('Failed to generate bio');
        } finally {
            setGeneratingBio(false);
        }
    };

    if (loading) {
        return <LoadingSpinner message="Loading profile..." />;
    }

    return (
        <Box>
            <PageHeader
                title="Organiser Profile"
                subtitle="Manage your public organisation identity, contact details and bio"
                icon={<ProfileIcon />}
            />

            <Grid container spacing={3}>
                <Grid item xs={12} md={4}>
                    <SectionCard contentSx={{ textAlign: 'center', py: 4 }}>
                        <Box sx={{ position: 'relative', display: 'inline-block' }}>
                            <Avatar
                                src={profile?.logoUrl || profile?.avatarUrl}
                                sx={{
                                    width: 120,
                                    height: 120,
                                    mx: 'auto',
                                    bgcolor: tokens.palette.primary[500],
                                    fontSize: 40,
                                    fontWeight: 700,
                                }}
                            >
                                {(profile?.displayName || profile?.organizationName)?.charAt(0)}
                            </Avatar>
                            <input
                                accept="image/*"
                                style={{ display: 'none' }}
                                id="avatar-upload"
                                type="file"
                                onChange={handleAvatarUpload}
                                disabled={uploadingAvatar}
                            />
                            <label htmlFor="avatar-upload">
                                <Button
                                    component="span"
                                    size="small"
                                    disabled={uploadingAvatar}
                                    sx={{
                                        position: 'absolute',
                                        bottom: 0,
                                        right: 0,
                                        minWidth: 'auto',
                                        p: 1,
                                        bgcolor: tokens.palette.primary[500],
                                        color: tokens.palette.neutral[0],
                                        borderRadius: '50%',
                                        '&:hover': { bgcolor: tokens.palette.primary[600] },
                                        '&.Mui-disabled': { bgcolor: tokens.palette.neutral[300] },
                                    }}
                                >
                                    {uploadingAvatar ? (
                                        <CircularProgress size={20} color="inherit" />
                                    ) : (
                                        <CameraIcon fontSize="small" />
                                    )}
                                </Button>
                            </label>
                        </Box>

                        <Stack direction="row" alignItems="center" justifyContent="center" spacing={1} sx={{ mt: 2 }}>
                            <Typography variant="h6" fontWeight={700}>
                                {profile?.displayName || profile?.organizationName}
                            </Typography>
                            {profile?.verified && (
                                <VerifiedIcon sx={{ color: tokens.palette.primary[500] }} />
                            )}
                        </Stack>

                        <Typography color="text.secondary" sx={{ mb: 1 }}>
                            {profile?.email}
                        </Typography>

                        {profile?.verified ? (
                            <StatusChip label="Verified" status="success" />
                        ) : (
                            <StatusChip label="Not verified" status="warning" />
                        )}

                        <Divider sx={{ my: 2.5 }} />

                        <Grid container spacing={2}>
                            <Grid item xs={4}>
                                <Typography variant="h5" fontWeight={700} sx={{ color: tokens.palette.primary[600] }}>
                                    {profile?.totalEvents || 0}
                                </Typography>
                                <Typography variant="caption" color="text.secondary">
                                    Events
                                </Typography>
                            </Grid>
                            <Grid item xs={4}>
                                <Typography variant="h5" fontWeight={700} sx={{ color: tokens.palette.primary[600] }}>
                                    {profile?.totalFollowers || profile?.followersCount || 0}
                                </Typography>
                                <Typography variant="caption" color="text.secondary">
                                    Followers
                                </Typography>
                            </Grid>
                            <Grid item xs={4}>
                                <Typography variant="h5" fontWeight={700} sx={{ color: tokens.palette.primary[600] }}>
                                    {profile?.totalRegistrations || 0}
                                </Typography>
                                <Typography variant="caption" color="text.secondary">
                                    Registrations
                                </Typography>
                            </Grid>
                        </Grid>

                        {!profile?.verified && (
                            <Alert severity="info" sx={{ mt: 2.5, textAlign: 'left' }}>
                                Your profile is not verified yet. Contact admin for verification.
                            </Alert>
                        )}
                    </SectionCard>
                </Grid>

                <Grid item xs={12} md={8}>
                    <SectionCard
                        title="Edit Profile"
                        subtitle="Update the details shown on your public organiser page"
                    >
                        <form onSubmit={handleSubmit}>
                            <FormSection
                                title="Organisation"
                                description="The main identity shown to attendees across Luma"
                            >
                                <TextField
                                    fullWidth
                                    label="Organization Name"
                                    value={formData.displayName}
                                    onChange={(e) => setFormData({ ...formData, displayName: e.target.value })}
                                    required
                                    error={!!formErrors.displayName}
                                    helperText={formErrors.displayName || 'Between 2-100 characters'}
                                />

                                <Box sx={{ mt: 2.5 }}>
                                    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
                                        <Typography variant="body2" color="text.secondary">
                                            Bio (supports Markdown)
                                        </Typography>
                                        <LoadingButton
                                            size="small"
                                            variant="outlined"
                                            color="secondary"
                                            startIcon={<AIIcon />}
                                            onClick={handleGenerateBio}
                                            loading={generatingBio}
                                            disabled={!formData.displayName}
                                        >
                                            {generatingBio ? 'Generating...' : 'AI Generate'}
                                        </LoadingButton>
                                    </Box>
                                    <Box
                                        data-color-mode="light"
                                        sx={{
                                            border: `1px solid ${tokens.palette.neutral[200]}`,
                                            borderRadius: 2,
                                            overflow: 'hidden',
                                            '& .w-md-editor': {
                                                boxShadow: 'none !important',
                                            },
                                        }}
                                    >
                                        <MDEditor
                                            value={formData.bio}
                                            onChange={(value) => setFormData({ ...formData, bio: value || '' })}
                                            height={200}
                                            preview="edit"
                                            textareaProps={{
                                                placeholder: 'Tell people about your organization... (supports **bold**, *italic*, [links](url), etc.)',
                                            }}
                                        />
                                    </Box>
                                    <Typography variant="caption" color="text.secondary" sx={{ mt: 0.5, display: 'block' }}>
                                        {formData.bio?.length || 0}/500 characters
                                    </Typography>
                                </Box>
                            </FormSection>

                            <FormSection
                                title="Contact"
                                description="How attendees and partners can reach you"
                                topDivider
                            >
                                <TextField
                                    fullWidth
                                    label="Website"
                                    value={formData.website}
                                    onChange={(e) => setFormData({ ...formData, website: e.target.value })}
                                    margin="normal"
                                    placeholder="https://example.com"
                                    error={!!formErrors.website}
                                    helperText={formErrors.website}
                                />

                                <TextField
                                    fullWidth
                                    label="Contact Email"
                                    value={formData.contactEmail}
                                    onChange={(e) => setFormData({ ...formData, contactEmail: e.target.value })}
                                    margin="normal"
                                    placeholder="contact@example.com"
                                    error={!!formErrors.contactEmail}
                                    helperText={formErrors.contactEmail}
                                />

                                <TextField
                                    fullWidth
                                    label="Contact Phone"
                                    value={formData.contactPhone}
                                    onChange={(e) => setFormData({ ...formData, contactPhone: e.target.value })}
                                    margin="normal"
                                    placeholder="+84 123 456 789"
                                />
                            </FormSection>

                            <Box sx={{ display: 'flex', justifyContent: 'flex-end' }}>
                                <LoadingButton
                                    type="submit"
                                    variant="contained"
                                    startIcon={<SaveIcon />}
                                    loading={saving}
                                    size="large"
                                >
                                    {saving ? 'Saving...' : 'Save Changes'}
                                </LoadingButton>
                            </Box>
                        </form>
                    </SectionCard>
                </Grid>
            </Grid>
        </Box>
    );
};

export default OrganiserProfile;

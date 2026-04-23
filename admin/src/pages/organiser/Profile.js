import React, { useCallback, useEffect, useState } from 'react';
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
    Chip,
} from '@mui/material';
import {
    Save as SaveIcon,
    PhotoCamera as CameraIcon,
    Verified as VerifiedIcon,
    AutoAwesome as AIIcon,
    AccountCircle as ProfileIcon,
    Send as SendIcon,
    VerifiedUser as VerifyShieldIcon,
} from '@mui/icons-material';
import MDEditor from '@uiw/react-md-editor';
import { organiserApi } from '../../api';
import { LoadingSpinner, VerificationDocumentUpload } from '../../components/common';
import { useAuth } from '../../context/AuthContext';
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
    const { updateUser } = useAuth();
    const [profile, setProfile] = useState(null);
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [uploadingAvatar, setUploadingAvatar] = useState(false);
    const [uploadingCover, setUploadingCover] = useState(false);
    const [generatingBio, setGeneratingBio] = useState(false);
    const [formData, setFormData] = useState({
        displayName: '',
        bio: '',
        website: '',
        contactEmail: '',
        contactPhone: '',
    });
    const [formErrors, setFormErrors] = useState({});

    const [verification, setVerification] = useState(null);
    const [verificationLoading, setVerificationLoading] = useState(true);
    const [submittingVerification, setSubmittingVerification] = useState(false);
    const [verificationForm, setVerificationForm] = useState({
        documentType: 'BUSINESS_LICENSE',  // locked — profile flow is badge request
        documentUrls: [],
        legalName: '',
        documentNumber: '',
    });
    const [verificationErrors, setVerificationErrors] = useState({});

    const syncAuthUser = useCallback((profileData) => {
        if (!profileData) {
            return;
        }

        updateUser?.({
            avatarUrl:
                profileData.avatarUrl ||
                profileData.logoUrl ||
                profileData.coverUrl ||
                null,
            logoUrl: profileData.logoUrl || null,
            coverUrl: profileData.coverUrl || null,
            fullName:
                profileData.fullName ||
                profileData.organizationName ||
                profileData.displayName,
        });
    }, [updateUser]);

    const loadProfile = useCallback(async () => {
        try {
            const response = await organiserApi.getProfile();
            const data = response.data.data;
            setProfile(data);
            syncAuthUser(data);
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
    }, [syncAuthUser]);

    const loadVerification = useCallback(async () => {
        setVerificationLoading(true);
        try {
            const response = await organiserApi.getMyVerification();
            setVerification(response.data.data);
        } catch (error) {
            // Non-fatal - user might not have submitted yet
            setVerification(null);
        } finally {
            setVerificationLoading(false);
        }
    }, []);

    useEffect(() => {
        loadProfile();
        loadVerification();
    }, [loadProfile, loadVerification]);

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
            const response = await organiserApi.updateProfile(formData);
            const data = response.data.data;
            setProfile(data);
            syncAuthUser(data);
            toast.success('Profile updated successfully');
            await loadProfile();
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
            const response = await organiserApi.uploadAvatar(file);
            const data = response.data.data;
            setProfile(data);
            syncAuthUser(data);
            toast.success('Avatar updated successfully');
            await loadProfile();
        } catch (error) {
            console.error('Avatar upload error:', error);
            toast.error(error.response?.data?.message || 'Failed to upload avatar');
        } finally {
            setUploadingAvatar(false);
        }
    };

    const handleCoverUpload = async (e) => {
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

        setUploadingCover(true);
        try {
            const response = await organiserApi.uploadCover(file);
            const data = response.data.data;
            setProfile(data);
            syncAuthUser(data);
            toast.success('Cover updated successfully');
            await loadProfile();
        } catch (error) {
            console.error('Cover upload error:', error);
            toast.error(error.response?.data?.message || 'Failed to upload cover');
        } finally {
            setUploadingCover(false);
        }
    };

    const validateVerification = () => {
        const errors = {};
        if (verificationForm.documentUrls.length === 0) {
            errors.documentUrls = 'Please upload at least one document image';
        }
        setVerificationErrors(errors);
        return Object.keys(errors).length === 0;
    };

    const handleSubmitVerification = async () => {
        if (!validateVerification()) {
            toast.error('Please fix the errors in the verification form');
            return;
        }
        setSubmittingVerification(true);
        try {
            const payload = {
                documentType: verificationForm.documentType,
                documentUrls: verificationForm.documentUrls,
                legalName: verificationForm.legalName?.trim() || null,
                documentNumber: verificationForm.documentNumber?.trim() || null,
            };
            await organiserApi.submitVerification(payload);
            toast.success('Verification request submitted');
            setVerificationForm({
                documentType: 'BUSINESS_LICENSE',
                documentUrls: [],
                legalName: '',
                documentNumber: '',
            });
            await loadVerification();
        } catch (error) {
            toast.error(error.response?.data?.message || 'Failed to submit verification');
        } finally {
            setSubmittingVerification(false);
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
                        <Box
                            sx={{
                                position: 'relative',
                                height: 168,
                                mb: 3,
                                borderRadius: 3,
                                overflow: 'hidden',
                                border: (theme) => `1px solid ${theme.palette.divider}`,
                                background: profile?.coverUrl
                                    ? `center/cover no-repeat url(${profile.coverUrl})`
                                    : 'linear-gradient(135deg, #1D4ED8 0%, #2563EB 60%, #F97316 100%)',
                            }}
                        >
                            <input
                                accept="image/*"
                                style={{ display: 'none' }}
                                id="cover-upload"
                                type="file"
                                onChange={handleCoverUpload}
                                disabled={uploadingCover}
                            />
                            <label htmlFor="cover-upload">
                                <Button
                                    component="span"
                                    size="small"
                                    variant="contained"
                                    disabled={uploadingCover}
                                    startIcon={uploadingCover ? <CircularProgress size={16} color="inherit" /> : <CameraIcon fontSize="small" />}
                                    sx={{
                                        position: 'absolute',
                                        right: 12,
                                        bottom: 12,
                                        backdropFilter: 'blur(8px)',
                                    }}
                                >
                                    {uploadingCover ? 'Uploading...' : 'Upload Cover'}
                                </Button>
                            </label>
                        </Box>

                        <Box sx={{ position: 'relative', display: 'inline-block' }}>
                            <Avatar
                                src={profile?.logoUrl || profile?.avatarUrl || profile?.coverUrl}
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
                            {profile?.website || profile?.contactEmail || profile?.email}
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

                    <Box sx={{ mt: 3 }}>
                        <SectionCard
                            title="Verified Badge"
                            subtitle="Submit your business registration certificate to earn the blue Verified tick. Reserved for established brands with a business licence."
                        >
                            {verificationLoading ? (
                                <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
                                    <CircularProgress size={24} />
                                </Box>
                            ) : (
                                <VerificationPanel
                                    profileVerified={profile?.verified}
                                    verification={verification}
                                    form={verificationForm}
                                    setForm={setVerificationForm}
                                    errors={verificationErrors}
                                    setErrors={setVerificationErrors}
                                    submitting={submittingVerification}
                                    onSubmit={handleSubmitVerification}
                                />
                            )}
                        </SectionCard>
                    </Box>
                </Grid>
            </Grid>
        </Box>
    );
};

const VerificationStatusChip = ({ status, aiStatus }) => {
    if (status === 'APPROVED') return <StatusChip label="Approved" status="success" />;
    if (status === 'REJECTED') return <StatusChip label="Rejected" status="error" />;
    if (status === 'PENDING') return <StatusChip label="Pending review" status="warning" />;
    return null;
};

const AIStatusChip = ({ aiStatus, aiConfidence }) => {
    if (!aiStatus) return null;
    const color = aiStatus === 'VALID' ? 'success'
        : aiStatus === 'SUSPICIOUS' ? 'warning'
        : aiStatus === 'INVALID' ? 'error'
        : 'default';
    return (
        <Chip
            size="small"
            label={`AI: ${aiStatus}${aiConfidence != null ? ` (${aiConfidence}%)` : ''}`}
            color={color}
            variant="outlined"
        />
    );
};

const VerificationPanel = ({
    profileVerified,
    verification,
    form,
    setForm,
    errors,
    setErrors,
    submitting,
    onSubmit,
}) => {
    const isPending = verification?.status === 'PENDING';
    const isApproved = verification?.status === 'APPROVED';
    const isRejected = verification?.status === 'REJECTED';
    const canResubmit = !isPending;
    const [showResubmit, setShowResubmit] = React.useState(false);
    const hideFormByDefault = profileVerified && !isRejected;

    return (
        <Box>
            {profileVerified ? (
                <Alert
                    severity="success"
                    icon={<VerifyShieldIcon />}
                    sx={{ mb: 3 }}
                >
                    Your organisation is <strong>Verified</strong>. The blue Verified badge is shown on your public page.
                </Alert>
            ) : (
                <Alert severity="info" sx={{ mb: 3 }}>
                    You don't have the Verified badge yet. The badge is a trust signal for attendees and is typically granted to brands with a business licence, an active website and a track record of events.
                </Alert>
            )}

            {verification && (
                <Box
                    sx={{
                        mb: 3,
                        p: 2.5,
                        borderRadius: 2,
                        border: '1px solid',
                        borderColor: 'divider',
                        bgcolor: 'grey.50',
                    }}
                >
                    <Stack direction="row" alignItems="center" spacing={1.5} sx={{ mb: 1.5, flexWrap: 'wrap' }}>
                        <Typography variant="subtitle2">Last submission</Typography>
                        <VerificationStatusChip status={verification.status} />
                        <AIStatusChip aiStatus={verification.aiStatus} aiConfidence={verification.aiConfidence} />
                    </Stack>
                    <Typography variant="body2" color="text.secondary">
                        Submitted on {new Date(verification.submittedAt).toLocaleString()} —
                        Document type: <strong>{verification.documentType === 'BUSINESS_LICENSE' ? 'Business License' : 'Citizen ID'}</strong>
                    </Typography>
                    {verification.aiReason && (
                        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 0.75 }}>
                            AI hint: {verification.aiReason}
                        </Typography>
                    )}
                    {isRejected && verification.rejectReason && (
                        <Alert severity="error" sx={{ mt: 1.5 }}>
                            <Typography variant="body2" fontWeight={600}>Admin feedback</Typography>
                            <Typography variant="body2">{verification.rejectReason}</Typography>
                        </Alert>
                    )}
                    {isPending && (
                        <Alert severity="info" sx={{ mt: 1.5 }}>
                            Your submission is in the admin review queue. You will be notified once reviewed.
                        </Alert>
                    )}
                    {isApproved && verification.reviewedByName && (
                        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 0.75 }}>
                            Reviewed by {verification.reviewedByName} on {new Date(verification.reviewedAt).toLocaleString()}
                        </Typography>
                    )}
                </Box>
            )}

            {canResubmit && hideFormByDefault && !showResubmit && (
                <Box sx={{ display: 'flex', justifyContent: 'flex-end' }}>
                    <Button size="small" variant="text" onClick={() => setShowResubmit(true)}>
                        Submit new documents
                    </Button>
                </Box>
            )}

            {canResubmit && (!hideFormByDefault || showResubmit) && (
                <>
                    <Typography variant="subtitle1" sx={{ mb: 0.5 }}>
                        {verification ? 'Submit new documents' : 'Request Verified badge'}
                    </Typography>
                    <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 2 }}>
                        A business licence is strongly preferred over a personal ID for badge requests.
                    </Typography>

                    <VerificationDocumentUpload
                        fixedType="BUSINESS_LICENSE"
                        documentUrls={form.documentUrls}
                        onChangeDocumentUrls={(urls) => {
                            setForm((f) => ({ ...f, documentUrls: urls }));
                            if (errors.documentUrls) setErrors((e) => ({ ...e, documentUrls: '' }));
                        }}
                        error={errors.documentUrls}
                    />

                    <Grid container spacing={2.5} sx={{ mt: 1 }}>
                        <Grid item xs={12} md={6}>
                            <TextField
                                label="Company / legal name"
                                value={form.legalName}
                                onChange={(e) => setForm((f) => ({ ...f, legalName: e.target.value }))}
                                fullWidth
                                helperText="Exactly as it appears on the business licence"
                            />
                        </Grid>
                        <Grid item xs={12} md={6}>
                            <TextField
                                label="Business registration number"
                                value={form.documentNumber}
                                onChange={(e) => setForm((f) => ({ ...f, documentNumber: e.target.value }))}
                                fullWidth
                            />
                        </Grid>
                    </Grid>

                    <Box sx={{ display: 'flex', justifyContent: 'flex-end', mt: 2.5 }}>
                        <LoadingButton
                            variant="contained"
                            startIcon={<SendIcon />}
                            loading={submitting}
                            onClick={onSubmit}
                        >
                            {submitting ? 'Submitting...' : (profileVerified ? 'Submit new documents' : 'Request Verified Badge')}
                        </LoadingButton>
                    </Box>
                </>
            )}
        </Box>
    );
};

export default OrganiserProfile;

import React, { useState } from 'react';
import { Link as RouterLink, useNavigate } from 'react-router-dom';
import {
    Box,
    Stack,
    Typography,
    TextField,
    InputAdornment,
    IconButton,
    Alert,
    Button,
    Paper,
    Grid,
    Link,
} from '@mui/material';
import {
    Visibility,
    VisibilityOff,
    Email as EmailIcon,
    Lock as LockIcon,
    Person as PersonIcon,
    Phone as PhoneIcon,
    Business as BusinessIcon,
    Language as WebIcon,
    ArrowBack as BackIcon,
    CheckCircle as CheckIcon,
} from '@mui/icons-material';
import { toast } from 'react-toastify';
import { publicApi } from '../../api';
import { LoadingButton } from '../../components/ui';
import { VerificationDocumentUpload } from '../../components/common';
import LumaLogo from '../../components/brand/LumaLogo';
import { tokens } from '../../theme';

const RegisterOrganiser = () => {
    const navigate = useNavigate();

    const [submitting, setSubmitting] = useState(false);
    const [submitted, setSubmitted] = useState(false);
    const [showPassword, setShowPassword] = useState(false);
    const [error, setError] = useState('');
    const [fieldErrors, setFieldErrors] = useState({});

    const [form, setForm] = useState({
        fullName: '',
        email: '',
        password: '',
        phone: '',
        organisationName: '',
        organisationBio: '',
        organisationWebsite: '',
        organisationContactEmail: '',
        organisationContactPhone: '',
        documentUrls: [],
        legalName: '',
        documentNumber: '',
    });

    const updateField = (key, value) => {
        setForm((prev) => ({ ...prev, [key]: value }));
        if (fieldErrors[key]) {
            setFieldErrors((prev) => ({ ...prev, [key]: '' }));
        }
    };

    const validate = () => {
        const errors = {};
        if (!form.fullName.trim()) errors.fullName = 'Full name is required';
        if (!form.email.trim()) errors.email = 'Email is required';
        else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email.trim())) errors.email = 'Invalid email format';
        if (!form.password || form.password.length < 8) errors.password = 'Password must be at least 8 characters';
        if (!form.organisationName.trim()) errors.organisationName = 'Organisation name is required';
        if (form.organisationContactEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.organisationContactEmail.trim())) {
            errors.organisationContactEmail = 'Invalid contact email';
        }
        if (!form.documentUrls || form.documentUrls.length === 0) {
            errors.documentUrls = 'Please upload your Citizen ID (at least one image)';
        }
        setFieldErrors(errors);
        return Object.keys(errors).length === 0;
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError('');
        if (!validate()) {
            toast.error('Please fix the errors in the form');
            return;
        }
        setSubmitting(true);
        try {
            const payload = {
                fullName: form.fullName.trim(),
                email: form.email.trim().toLowerCase(),
                password: form.password,
                phone: form.phone?.trim() || null,
                organisationName: form.organisationName.trim(),
                organisationBio: form.organisationBio?.trim() || null,
                organisationWebsite: form.organisationWebsite?.trim() || null,
                organisationContactEmail: form.organisationContactEmail?.trim() || null,
                organisationContactPhone: form.organisationContactPhone?.trim() || null,
                documentUrls: form.documentUrls,
                legalName: form.legalName?.trim() || null,
                documentNumber: form.documentNumber?.trim() || null,
            };
            await publicApi.applyAsOrganiser(payload);
            setSubmitted(true);
        } catch (err) {
            setError(err.response?.data?.message || 'Failed to submit application. Please try again.');
        } finally {
            setSubmitting(false);
        }
    };

    if (submitted) {
        return (
            <Box
                sx={{
                    minHeight: '100vh',
                    bgcolor: 'background.default',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    p: 3,
                }}
            >
                <Paper
                    elevation={0}
                    sx={{
                        maxWidth: 560,
                        width: '100%',
                        p: { xs: 4, md: 6 },
                        textAlign: 'center',
                        border: '1px solid',
                        borderColor: 'divider',
                        borderRadius: 3,
                    }}
                >
                    <Box
                        sx={{
                            width: 72,
                            height: 72,
                            mx: 'auto',
                            mb: 3,
                            borderRadius: '50%',
                            bgcolor: 'success.50',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                        }}
                    >
                        <CheckIcon sx={{ fontSize: 40, color: 'success.main' }} />
                    </Box>
                    <Typography variant="h1" sx={{ mb: 1.5, fontSize: '1.75rem' }}>
                        Application submitted!
                    </Typography>
                    <Typography color="text.secondary" sx={{ mb: 3 }}>
                        Your application is now in the admin review queue.
                        You will be notified by email once your account is approved.
                    </Typography>

                    <Alert severity="info" sx={{ mb: 3, textAlign: 'left' }}>
                        <Typography variant="body2" fontWeight={600} sx={{ mb: 0.5 }}>
                            About the Verified badge
                        </Typography>
                        <Typography variant="caption" component="div">
                            Getting approved lets you publish events on LUMA. The blue Verified badge is a
                            separate tier — you can request it from your profile after approval by uploading
                            your business licence or identity document.
                        </Typography>
                    </Alert>

                    <Button
                        variant="contained"
                        size="large"
                        fullWidth
                        onClick={() => navigate('/login')}
                        sx={{ py: 1.5 }}
                    >
                        Back to login
                    </Button>
                </Paper>
            </Box>
        );
    }

    return (
        <Box
            sx={{
                minHeight: '100vh',
                bgcolor: 'background.default',
                py: { xs: 3, md: 6 },
                px: { xs: 2, md: 3 },
            }}
        >
            <Box sx={{ maxWidth: 860, mx: 'auto' }}>
                <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 3 }}>
                    <Stack direction="row" alignItems="center" spacing={1.5}>
                        <LumaLogo size={40} />
                        <Typography variant="h3">LUMA</Typography>
                    </Stack>
                    <Button
                        component={RouterLink}
                        to="/login"
                        startIcon={<BackIcon />}
                        sx={{ color: 'text.secondary' }}
                    >
                        Back to login
                    </Button>
                </Stack>

                <Typography variant="h1" sx={{ mb: 1, fontSize: { xs: '1.75rem', md: '2.25rem' } }}>
                    Apply to become an organiser
                </Typography>
                <Typography color="text.secondary" sx={{ mb: 4, maxWidth: 640 }}>
                    Tell us about you and your organisation. An admin will review your application
                    and, once approved, you can start publishing events on LUMA.
                </Typography>

                {error && (
                    <Alert severity="error" sx={{ mb: 3 }}>
                        {error}
                    </Alert>
                )}

                <Box component="form" onSubmit={handleSubmit} noValidate>
                    <Paper variant="outlined" sx={{ p: { xs: 3, md: 4 }, mb: 3, borderRadius: 3 }}>
                        <Typography variant="h6" sx={{ mb: 0.5 }}>Account</Typography>
                        <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
                            You will use this email and password to sign into LUMA after approval.
                        </Typography>
                        <Grid container spacing={2.5}>
                            <Grid item xs={12} md={6}>
                                <TextField
                                    label="Full name"
                                    value={form.fullName}
                                    onChange={(e) => updateField('fullName', e.target.value)}
                                    error={Boolean(fieldErrors.fullName)}
                                    helperText={fieldErrors.fullName || ' '}
                                    fullWidth
                                    required
                                    InputProps={{
                                        startAdornment: (
                                            <InputAdornment position="start"><PersonIcon fontSize="small" /></InputAdornment>
                                        ),
                                    }}
                                />
                            </Grid>
                            <Grid item xs={12} md={6}>
                                <TextField
                                    label="Phone"
                                    value={form.phone}
                                    onChange={(e) => updateField('phone', e.target.value)}
                                    fullWidth
                                    helperText=" "
                                    InputProps={{
                                        startAdornment: (
                                            <InputAdornment position="start"><PhoneIcon fontSize="small" /></InputAdornment>
                                        ),
                                    }}
                                />
                            </Grid>
                            <Grid item xs={12} md={6}>
                                <TextField
                                    label="Email"
                                    type="email"
                                    value={form.email}
                                    onChange={(e) => updateField('email', e.target.value)}
                                    error={Boolean(fieldErrors.email)}
                                    helperText={fieldErrors.email || ' '}
                                    fullWidth
                                    required
                                    InputProps={{
                                        startAdornment: (
                                            <InputAdornment position="start"><EmailIcon fontSize="small" /></InputAdornment>
                                        ),
                                    }}
                                />
                            </Grid>
                            <Grid item xs={12} md={6}>
                                <TextField
                                    label="Password"
                                    type={showPassword ? 'text' : 'password'}
                                    value={form.password}
                                    onChange={(e) => updateField('password', e.target.value)}
                                    error={Boolean(fieldErrors.password)}
                                    helperText={fieldErrors.password || 'At least 8 characters'}
                                    fullWidth
                                    required
                                    InputProps={{
                                        startAdornment: (
                                            <InputAdornment position="start"><LockIcon fontSize="small" /></InputAdornment>
                                        ),
                                        endAdornment: (
                                            <InputAdornment position="end">
                                                <IconButton size="small" onClick={() => setShowPassword((s) => !s)} edge="end">
                                                    {showPassword ? <VisibilityOff fontSize="small" /> : <Visibility fontSize="small" />}
                                                </IconButton>
                                            </InputAdornment>
                                        ),
                                    }}
                                />
                            </Grid>
                        </Grid>
                    </Paper>

                    <Paper variant="outlined" sx={{ p: { xs: 3, md: 4 }, mb: 3, borderRadius: 3 }}>
                        <Typography variant="h6" sx={{ mb: 0.5 }}>Organisation</Typography>
                        <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
                            Public information shown on your organiser page.
                        </Typography>
                        <Grid container spacing={2.5}>
                            <Grid item xs={12} md={6}>
                                <TextField
                                    label="Organisation name"
                                    value={form.organisationName}
                                    onChange={(e) => updateField('organisationName', e.target.value)}
                                    error={Boolean(fieldErrors.organisationName)}
                                    helperText={fieldErrors.organisationName || ' '}
                                    fullWidth
                                    required
                                    InputProps={{
                                        startAdornment: (
                                            <InputAdornment position="start"><BusinessIcon fontSize="small" /></InputAdornment>
                                        ),
                                    }}
                                />
                            </Grid>
                            <Grid item xs={12} md={6}>
                                <TextField
                                    label="Website"
                                    value={form.organisationWebsite}
                                    onChange={(e) => updateField('organisationWebsite', e.target.value)}
                                    placeholder="https://example.com"
                                    fullWidth
                                    helperText=" "
                                    InputProps={{
                                        startAdornment: (
                                            <InputAdornment position="start"><WebIcon fontSize="small" /></InputAdornment>
                                        ),
                                    }}
                                />
                            </Grid>
                            <Grid item xs={12}>
                                <TextField
                                    label="Short description"
                                    value={form.organisationBio}
                                    onChange={(e) => updateField('organisationBio', e.target.value)}
                                    fullWidth
                                    multiline
                                    rows={3}
                                    helperText="Briefly describe your organisation (optional)"
                                />
                            </Grid>
                            <Grid item xs={12} md={6}>
                                <TextField
                                    label="Contact email"
                                    value={form.organisationContactEmail}
                                    onChange={(e) => updateField('organisationContactEmail', e.target.value)}
                                    error={Boolean(fieldErrors.organisationContactEmail)}
                                    helperText={fieldErrors.organisationContactEmail || 'Optional'}
                                    fullWidth
                                />
                            </Grid>
                            <Grid item xs={12} md={6}>
                                <TextField
                                    label="Contact phone"
                                    value={form.organisationContactPhone}
                                    onChange={(e) => updateField('organisationContactPhone', e.target.value)}
                                    fullWidth
                                    helperText="Optional"
                                />
                            </Grid>
                        </Grid>
                    </Paper>

                    <Paper variant="outlined" sx={{ p: { xs: 3, md: 4 }, mb: 3, borderRadius: 3 }}>
                        <Typography variant="h6" sx={{ mb: 0.5 }}>Identity Verification</Typography>
                        <Typography variant="body2" color="text.secondary" sx={{ mb: 0.5 }}>
                            Upload your <strong>Citizen ID (CCCD)</strong> — front and back (up to 2 images).
                            Our AI pre-checks the documents, but the final decision is made by a human admin.
                        </Typography>
                        <Typography variant="caption" color="text.secondary" sx={{ mb: 2.5, display: 'block' }}>
                            The blue <strong>Verified</strong> badge is a separate tier. After approval, you can
                            upload a business licence from your profile to request it.
                        </Typography>

                        <VerificationDocumentUpload
                            fixedType="CITIZEN_ID"
                            uploader="public"
                            documentUrls={form.documentUrls}
                            onChangeDocumentUrls={(urls) => {
                                setForm((prev) => ({ ...prev, documentUrls: urls }));
                                if (fieldErrors.documentUrls) {
                                    setFieldErrors((prev) => ({ ...prev, documentUrls: '' }));
                                }
                            }}
                            error={fieldErrors.documentUrls}
                        />

                        <Grid container spacing={2.5} sx={{ mt: 1 }}>
                            <Grid item xs={12} md={6}>
                                <TextField
                                    label="Full name on ID"
                                    value={form.legalName}
                                    onChange={(e) => updateField('legalName', e.target.value)}
                                    fullWidth
                                    helperText="Exactly as it appears on your Citizen ID (optional)"
                                />
                            </Grid>
                            <Grid item xs={12} md={6}>
                                <TextField
                                    label="ID number"
                                    value={form.documentNumber}
                                    onChange={(e) => updateField('documentNumber', e.target.value)}
                                    fullWidth
                                    helperText="Optional"
                                />
                            </Grid>
                        </Grid>
                    </Paper>

                    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 6 }}>
                        <Link component={RouterLink} to="/login" variant="body2" color="text.secondary">
                            Already approved? Sign in
                        </Link>
                        <LoadingButton
                            type="submit"
                            variant="contained"
                            size="large"
                            loading={submitting}
                            sx={{ px: 4, py: 1.5, background: tokens.gradient.primary }}
                        >
                            {submitting ? 'Submitting...' : 'Submit application'}
                        </LoadingButton>
                    </Box>
                </Box>
            </Box>
        </Box>
    );
};

export default RegisterOrganiser;

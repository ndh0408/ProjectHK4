import React, { useState } from 'react';
import {
    Box,
    TextField,
    IconButton,
    Typography,
    Paper,
    Grid,
    Button,
    Tooltip,
} from '@mui/material';
import {
    Delete as DeleteIcon,
    Add as AddIcon,
    Person as PersonIcon,
    AutoAwesome as AIIcon,
} from '@mui/icons-material';
import ImageUpload from './ImageUpload';
import { organiserApi } from '../../api';
import { toast } from 'react-toastify';

const SpeakerForm = ({ speakers = [], onChange, errors = [], eventTitle = '', subscription = null, onAIUsed = null, onUpgradeNeeded = null }) => {
    const [aiLoading, setAiLoading] = useState({});

    const handleAddSpeaker = () => {
        onChange([
            ...speakers,
            {
                name: '',
                title: '',
                bio: '',
                imageUrl: '',
            },
        ]);
    };

    const handleRemoveSpeaker = (index) => {
        const newSpeakers = speakers.filter((_, i) => i !== index);
        onChange(newSpeakers);
    };

    const handleSpeakerChange = (index, field, value) => {
        const newSpeakers = [...speakers];
        newSpeakers[index] = { ...newSpeakers[index], [field]: value };
        onChange(newSpeakers);
    };

    const handleGenerateBio = async (index) => {
        const speaker = speakers[index];
        if (!speaker.name.trim() || !speaker.title.trim()) {
            toast.error('Please enter name and title first');
            return;
        }

        setAiLoading({ ...aiLoading, [index]: true });
        try {
            const response = await organiserApi.generateSpeakerBio({
                name: speaker.name,
                title: speaker.title,
                eventTitle: eventTitle,
            });
            handleSpeakerChange(index, 'bio', response.data.data.bio);
            toast.success('Bio generated!');
            if (onAIUsed) {
                onAIUsed();
            }
        } catch (error) {
            toast.error(error.response?.data?.message || 'Failed to generate bio');
        } finally {
            setAiLoading({ ...aiLoading, [index]: false });
        }
    };

    return (
        <Box>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
                <Typography variant="subtitle1" fontWeight="bold" sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <PersonIcon color="primary" />
                    Speakers ({speakers.length})
                </Typography>
                <Button
                    variant="outlined"
                    size="small"
                    startIcon={<AddIcon />}
                    onClick={handleAddSpeaker}
                >
                    Add Speaker
                </Button>
            </Box>

            {speakers.length === 0 ? (
                <Paper
                    sx={{
                        p: 3,
                        textAlign: 'center',
                        bgcolor: 'grey.50',
                        border: '2px dashed',
                        borderColor: 'grey.300',
                    }}
                >
                    <PersonIcon sx={{ fontSize: 40, color: 'grey.400', mb: 1 }} />
                    <Typography color="text.secondary">
                        No speakers added yet. Click "Add Speaker" to add event speakers.
                    </Typography>
                </Paper>
            ) : (
                <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                    {speakers.map((speaker, index) => (
                        <Paper key={index} sx={{ p: 2, bgcolor: 'grey.50' }}>
                            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
                                <Typography variant="subtitle2" color="primary">
                                    Speaker #{index + 1}
                                </Typography>
                                <IconButton
                                    size="small"
                                    color="error"
                                    onClick={() => handleRemoveSpeaker(index)}
                                >
                                    <DeleteIcon />
                                </IconButton>
                            </Box>

                            <Grid container spacing={2}>
                                <Grid item xs={12} md={4}>
                                    <ImageUpload
                                        value={speaker.imageUrl}
                                        onChange={(url) => handleSpeakerChange(index, 'imageUrl', url)}
                                        label="Photo"
                                        folder="luma/speakers"
                                        maxSize={2}
                                    />
                                </Grid>

                                <Grid item xs={12} md={8}>
                                    <Grid container spacing={2}>
                                        <Grid item xs={12} md={6}>
                                            <TextField
                                                fullWidth
                                                size="small"
                                                label="Name"
                                                required
                                                value={speaker.name}
                                                onChange={(e) => handleSpeakerChange(index, 'name', e.target.value)}
                                                placeholder="e.g., John Doe"
                                                error={!!errors[index]?.name}
                                                helperText={errors[index]?.name}
                                            />
                                        </Grid>
                                        <Grid item xs={12} md={6}>
                                            <TextField
                                                fullWidth
                                                size="small"
                                                label="Title / Position"
                                                required
                                                value={speaker.title}
                                                onChange={(e) => handleSpeakerChange(index, 'title', e.target.value)}
                                                placeholder="e.g., CEO at TechCorp"
                                                error={!!errors[index]?.title}
                                                helperText={errors[index]?.title}
                                            />
                                        </Grid>
                                        <Grid item xs={12}>
                                            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 0.5 }}>
                                                <Typography variant="caption" color="text.secondary">
                                                    Bio *
                                                </Typography>
                                                <Tooltip title="Generate bio using AI">
                                                    <Button
                                                        size="small"
                                                        variant="outlined"
                                                        color="secondary"
                                                        startIcon={<AIIcon />}
                                                        onClick={() => handleGenerateBio(index)}
                                                        disabled={aiLoading[index] || !speaker.name.trim() || !speaker.title.trim()}
                                                        sx={{ minWidth: 100 }}
                                                    >
                                                        {aiLoading[index] ? 'Generating...' : 'AI Bio'}
                                                    </Button>
                                                </Tooltip>
                                            </Box>
                                            <TextField
                                                fullWidth
                                                size="small"
                                                value={speaker.bio}
                                                onChange={(e) => handleSpeakerChange(index, 'bio', e.target.value)}
                                                multiline
                                                rows={2}
                                                placeholder="Brief introduction about the speaker..."
                                                error={!!errors[index]?.bio}
                                                helperText={errors[index]?.bio}
                                            />
                                        </Grid>
                                    </Grid>
                                </Grid>
                            </Grid>
                        </Paper>
                    ))}
                </Box>
            )}
        </Box>
    );
};

export default SpeakerForm;

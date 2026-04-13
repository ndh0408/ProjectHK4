import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Typography,
    Paper,
    Button,
    Chip,
    IconButton,
    Tooltip,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    TextField,
    Autocomplete,
    Grid,
    Card,
    CardContent,
    LinearProgress,
    Select,
    MenuItem,
    FormControl,
    InputLabel,
} from '@mui/material';
import {
    Add as AddIcon,
    Refresh as RefreshIcon,
    Poll as PollIcon,
    Stop as StopIcon,
    HowToVote as VoteIcon,
} from '@mui/icons-material';
import { organiserApi } from '../../api';
import { toast } from 'react-toastify';

const OrganiserPolls = () => {
    const [events, setEvents] = useState([]);
    const [selectedEvent, setSelectedEvent] = useState('');
    const [polls, setPolls] = useState([]);
    const [loading, setLoading] = useState(false);
    const [createDialog, setCreateDialog] = useState(false);
    const [newPoll, setNewPoll] = useState({
        question: '',
        type: 'SINGLE_CHOICE',
        options: ['', ''],
        maxRating: 5,
        closesAt: '',
    });

    useEffect(() => {
        loadEvents();
    }, []);

    const loadEvents = async () => {
        try {
            const response = await organiserApi.getMyEvents({ page: 0, size: 100 });
            setEvents(response.data.data.content || []);
        } catch (error) {
            console.error('Failed to load events:', error);
        }
    };

    const loadPolls = useCallback(async (silent = false) => {
        if (!selectedEvent) return;
        if (!silent) setLoading(true);
        try {
            const response = await organiserApi.getEventPolls(selectedEvent);
            setPolls(response.data.data || []);
        } catch (error) {
            if (!silent) toast.error('Failed to load polls');
        } finally {
            if (!silent) setLoading(false);
        }
    }, [selectedEvent]);

    useEffect(() => {
        loadPolls();
    }, [loadPolls]);

    useEffect(() => {
        if (!selectedEvent) return;
        const interval = setInterval(() => {
            loadPolls(true);
        }, 5000);
        return () => clearInterval(interval);
    }, [selectedEvent, loadPolls]);

    const handleCreatePoll = async () => {
        if (!newPoll.question.trim()) {
            toast.error('Question is required');
            return;
        }

        const data = {
            question: newPoll.question,
            type: newPoll.type,
            options: newPoll.type !== 'RATING'
                ? newPoll.options.filter(o => o.trim())
                : undefined,
            maxRating: newPoll.type === 'RATING' ? newPoll.maxRating : undefined,
            closesAt: newPoll.closesAt || undefined,
        };

        if (data.type !== 'RATING' && (!data.options || data.options.length < 2)) {
            toast.error('At least 2 options are required');
            return;
        }

        try {
            await organiserApi.createPoll(selectedEvent, data);
            toast.success('Poll created!');
            setCreateDialog(false);
            setNewPoll({ question: '', type: 'SINGLE_CHOICE', options: ['', ''], maxRating: 5, closesAt: '' });
            loadPolls();
        } catch (error) {
            toast.error('Failed to create poll');
        }
    };

    const handleClosePoll = async (pollId) => {
        try {
            await organiserApi.closePoll(pollId);
            toast.success('Poll closed');
            loadPolls();
        } catch (error) {
            toast.error('Failed to close poll');
        }
    };

    const addOption = () => {
        if (newPoll.options.length < 10) {
            setNewPoll({ ...newPoll, options: [...newPoll.options, ''] });
        }
    };

    const removeOption = (index) => {
        if (newPoll.options.length > 2) {
            const options = newPoll.options.filter((_, i) => i !== index);
            setNewPoll({ ...newPoll, options });
        }
    };

    const updateOption = (index, value) => {
        const options = [...newPoll.options];
        options[index] = value;
        setNewPoll({ ...newPoll, options });
    };

    return (
        <Box>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                <Typography variant="h5" fontWeight="bold">
                    <PollIcon sx={{ mr: 1, verticalAlign: 'middle' }} />
                    Live Polls
                </Typography>
                <Box sx={{ display: 'flex', gap: 1 }}>
                    <Button startIcon={<RefreshIcon />} onClick={loadPolls}>
                        Refresh
                    </Button>
                    <Button
                        variant="contained"
                        startIcon={<AddIcon />}
                        onClick={() => setCreateDialog(true)}
                        disabled={!selectedEvent}
                    >
                        Create Poll
                    </Button>
                </Box>
            </Box>

            <Paper sx={{ p: 2, mb: 2 }}>
                <Autocomplete
                    options={events}
                    getOptionLabel={(option) => option.title || ''}
                    value={events.find(e => e.id === selectedEvent) || null}
                    onChange={(_, newValue) => setSelectedEvent(newValue?.id || '')}
                    renderInput={(params) => (
                        <TextField {...params} label="Select Event" placeholder="Search events..." />
                    )}
                    isOptionEqualToValue={(option, value) => option.id === value.id}
                    sx={{ minWidth: 400 }}
                />
            </Paper>

            {selectedEvent ? (
                loading ? (
                    <LinearProgress />
                ) : polls.length > 0 ? (
                    <Grid container spacing={2}>
                        {polls.map((poll) => (
                            <Grid item xs={12} md={6} key={poll.id}>
                                <Card variant="outlined" sx={{
                                    borderColor: poll.isActive ? 'success.main' : 'grey.300',
                                    borderWidth: poll.isActive ? 2 : 1,
                                }}>
                                    <CardContent>
                                        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 2 }}>
                                            <Box sx={{ flex: 1 }}>
                                                <Typography variant="h6" gutterBottom>
                                                    {poll.question}
                                                </Typography>
                                                <Box sx={{ display: 'flex', gap: 1 }}>
                                                    <Chip
                                                        label={poll.status}
                                                        size="small"
                                                        color={poll.isActive ? 'success' : 'default'}
                                                    />
                                                    <Chip
                                                        label={poll.type.replace('_', ' ')}
                                                        size="small"
                                                        variant="outlined"
                                                    />
                                                    <Chip
                                                        icon={<VoteIcon sx={{ fontSize: 16 }} />}
                                                        label={`${poll.totalVotes} votes`}
                                                        size="small"
                                                        color="info"
                                                    />
                                                </Box>
                                            </Box>
                                            {poll.isActive && (
                                                <Tooltip title="Close Poll">
                                                    <IconButton
                                                        color="error"
                                                        onClick={() => handleClosePoll(poll.id)}
                                                    >
                                                        <StopIcon />
                                                    </IconButton>
                                                </Tooltip>
                                            )}
                                        </Box>

                                        {poll.options && poll.options.map((option) => (
                                            <Box key={option.id} sx={{ mb: 1 }}>
                                                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 0.5 }}>
                                                    <Typography variant="body2">{option.text}</Typography>
                                                    <Typography variant="body2" color="text.secondary">
                                                        {option.voteCount} ({option.percentage.toFixed(1)}%)
                                                    </Typography>
                                                </Box>
                                                <LinearProgress
                                                    variant="determinate"
                                                    value={option.percentage}
                                                    sx={{
                                                        height: 8,
                                                        borderRadius: 4,
                                                        backgroundColor: 'grey.200',
                                                    }}
                                                />
                                            </Box>
                                        ))}

                                        {poll.closesAt && (
                                            <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
                                                {poll.isActive ? 'Closes' : 'Closed'}: {new Date(poll.closesAt).toLocaleString()}
                                            </Typography>
                                        )}
                                    </CardContent>
                                </Card>
                            </Grid>
                        ))}
                    </Grid>
                ) : (
                    <Paper sx={{ p: 4, textAlign: 'center' }}>
                        <PollIcon sx={{ fontSize: 48, color: 'text.disabled', mb: 1 }} />
                        <Typography color="text.secondary">
                            No polls yet. Create your first poll for this event!
                        </Typography>
                    </Paper>
                )
            ) : (
                <Paper sx={{ p: 4, textAlign: 'center' }}>
                    <Typography color="text.secondary">
                        Please select an event to manage polls
                    </Typography>
                </Paper>
            )}

            <Dialog open={createDialog} onClose={() => setCreateDialog(false)} maxWidth="sm" fullWidth>
                <DialogTitle>Create New Poll</DialogTitle>
                <DialogContent>
                    <TextField
                        autoFocus
                        fullWidth
                        label="Question"
                        value={newPoll.question}
                        onChange={(e) => setNewPoll({ ...newPoll, question: e.target.value })}
                        sx={{ mt: 1, mb: 2 }}
                        multiline
                        rows={2}
                    />

                    <FormControl fullWidth sx={{ mb: 2 }}>
                        <InputLabel>Poll Type</InputLabel>
                        <Select
                            value={newPoll.type}
                            label="Poll Type"
                            onChange={(e) => setNewPoll({ ...newPoll, type: e.target.value })}
                        >
                            <MenuItem value="SINGLE_CHOICE">Single Choice</MenuItem>
                            <MenuItem value="MULTIPLE_CHOICE">Multiple Choice</MenuItem>
                            <MenuItem value="RATING">Rating Scale</MenuItem>
                        </Select>
                    </FormControl>

                    {newPoll.type !== 'RATING' ? (
                        <Box>
                            <Typography variant="subtitle2" gutterBottom>Options</Typography>
                            {newPoll.options.map((option, index) => (
                                <Box key={index} sx={{ display: 'flex', gap: 1, mb: 1 }}>
                                    <TextField
                                        fullWidth
                                        size="small"
                                        label={`Option ${index + 1}`}
                                        value={option}
                                        onChange={(e) => updateOption(index, e.target.value)}
                                    />
                                    {newPoll.options.length > 2 && (
                                        <Button
                                            size="small"
                                            color="error"
                                            onClick={() => removeOption(index)}
                                        >
                                            Remove
                                        </Button>
                                    )}
                                </Box>
                            ))}
                            {newPoll.options.length < 10 && (
                                <Button size="small" onClick={addOption}>
                                    + Add Option
                                </Button>
                            )}
                        </Box>
                    ) : (
                        <TextField
                            fullWidth
                            type="number"
                            label="Max Rating"
                            value={newPoll.maxRating}
                            onChange={(e) => setNewPoll({ ...newPoll, maxRating: parseInt(e.target.value) || 5 })}
                            inputProps={{ min: 2, max: 10 }}
                            sx={{ mb: 2 }}
                        />
                    )}

                    <TextField
                        fullWidth
                        type="datetime-local"
                        label="Auto-close at (optional)"
                        value={newPoll.closesAt}
                        onChange={(e) => setNewPoll({ ...newPoll, closesAt: e.target.value })}
                        InputLabelProps={{ shrink: true }}
                        sx={{ mt: 2 }}
                    />
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setCreateDialog(false)}>Cancel</Button>
                    <Button variant="contained" onClick={handleCreatePoll}>Create Poll</Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default OrganiserPolls;

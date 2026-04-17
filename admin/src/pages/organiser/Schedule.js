import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Button,
    TextField,
    Grid,
    Autocomplete,
    IconButton,
    Tooltip,
    Typography,
    Stack,
    Chip,
} from '@mui/material';
import {
    Add as AddIcon,
    Refresh as RefreshIcon,
    Delete as DeleteIcon,
    Schedule as ScheduleIcon,
    Room as RoomIcon,
    Person as PersonIcon,
} from '@mui/icons-material';
import { organiserApi } from '../../api';
import {
    PageHeader,
    SectionCard,
    EmptyState,
    FormDialog,
    FormSection,
    LoadingButton,
    StatusChip,
} from '../../components/ui';
import { toast } from 'react-toastify';

const OrganiserSchedule = () => {
    const [events, setEvents] = useState([]);
    const [selectedEvent, setSelectedEvent] = useState('');
    const [schedule, setSchedule] = useState(null);
    // eslint-disable-next-line no-unused-vars
    const [loading, setLoading] = useState(false);
    const [createDialog, setCreateDialog] = useState(false);
    const [submitting, setSubmitting] = useState(false);
    const [form, setForm] = useState({
        title: '', description: '', startTime: '', endTime: '', room: '', track: '', capacity: 0, speakerId: '',
    });

    useEffect(() => {
        const loadEvents = async () => {
            try {
                const res = await organiserApi.getMyEvents({ page: 0, size: 100 });
                setEvents(res.data.data.content || []);
            } catch (e) { console.error(e); }
        };
        loadEvents();
    }, []);

    const loadSchedule = useCallback(async () => {
        if (!selectedEvent) return;
        setLoading(true);
        try {
            const res = await organiserApi.getSchedule(selectedEvent);
            setSchedule(res.data.data);
        } catch { toast.error('Failed to load schedule'); }
        finally { setLoading(false); }
    }, [selectedEvent]);

    useEffect(() => { loadSchedule(); }, [loadSchedule]);

    const handleCreate = async () => {
        if (!form.title.trim()) { toast.error('Title is required'); return; }
        if (!form.startTime || !form.endTime) { toast.error('Start and end time are required'); return; }
        if (new Date(form.startTime) >= new Date(form.endTime)) { toast.error('End time must be after start time'); return; }
        setSubmitting(true);
        try {
            const data = {
                ...form,
                capacity: parseInt(form.capacity) || 0,
                startTime: new Date(form.startTime).toISOString(),
                endTime: new Date(form.endTime).toISOString(),
            };
            await organiserApi.createSession(selectedEvent, data);
            toast.success('Session created!');
            setCreateDialog(false);
            setForm({ title: '', description: '', startTime: '', endTime: '', room: '', track: '', capacity: 0, speakerId: '' });
            loadSchedule();
        } catch (e) {
            toast.error(e.response?.data?.message || 'Failed');
        } finally {
            setSubmitting(false);
        }
    };

    const handleDelete = async (sessionId) => {
        try {
            await organiserApi.deleteSession(sessionId);
            toast.success('Session deleted');
            loadSchedule();
        } catch {
            toast.error('Failed');
        }
    };

    const tracks = schedule?.tracks || [];
    const sessions = schedule?.sessions || [];

    const groupedByTrack = {};
    sessions.forEach((s) => {
        const track = s.track || 'General';
        if (!groupedByTrack[track]) groupedByTrack[track] = [];
        groupedByTrack[track].push(s);
    });

    return (
        <Box>
            <PageHeader
                title="Schedule Builder"
                subtitle="Organise sessions, tracks and speakers for each event."
                icon={<ScheduleIcon />}
                actions={[
                    <Button
                        key="refresh"
                        variant="outlined"
                        startIcon={<RefreshIcon fontSize="small" />}
                        onClick={loadSchedule}
                        disabled={!selectedEvent}
                    >
                        Refresh
                    </Button>,
                    <Button
                        key="add"
                        variant="contained"
                        startIcon={<AddIcon fontSize="small" />}
                        onClick={() => setCreateDialog(true)}
                        disabled={!selectedEvent}
                    >
                        Add session
                    </Button>,
                ]}
            />

            <SectionCard sx={{ mb: 2 }}>
                <Autocomplete
                    options={events}
                    getOptionLabel={(o) => o.title || ''}
                    value={events.find((e) => e.id === selectedEvent) || null}
                    onChange={(_, v) => setSelectedEvent(v?.id || '')}
                    renderInput={(p) => <TextField {...p} label="Select event" placeholder="Pick an event" />}
                    isOptionEqualToValue={(o, v) => o.id === v.id}
                    sx={{ maxWidth: 520 }}
                />
            </SectionCard>

            {selectedEvent && schedule ? (
                Object.keys(groupedByTrack).length > 0 ? (
                    <Grid container spacing={2}>
                        {Object.entries(groupedByTrack).map(([track, trackSessions]) => (
                            <Grid item xs={12} md={tracks.length > 1 ? 6 : 12} key={track}>
                                <SectionCard
                                    title={(
                                        <Stack direction="row" alignItems="center" spacing={1}>
                                            <Chip label={track} color="primary" size="small" sx={{ fontWeight: 600 }} />
                                            <Typography variant="caption" color="text.secondary">
                                                {trackSessions.length} session{trackSessions.length !== 1 ? 's' : ''}
                                            </Typography>
                                        </Stack>
                                    )}
                                >
                                    <Stack spacing={1.25}>
                                        {trackSessions.map((session) => (
                                            <Box
                                                key={session.id}
                                                sx={{
                                                    p: 1.75,
                                                    border: '1px solid',
                                                    borderColor: 'divider',
                                                    borderRadius: 2,
                                                    borderLeft: '3px solid',
                                                    borderLeftColor: 'primary.500',
                                                    display: 'flex',
                                                    justifyContent: 'space-between',
                                                    alignItems: 'flex-start',
                                                    gap: 1,
                                                    bgcolor: 'grey.50',
                                                }}
                                            >
                                                <Box sx={{ flex: 1, minWidth: 0 }}>
                                                    <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                                                        {session.title}
                                                    </Typography>
                                                    <Typography variant="caption" color="text.secondary">
                                                        {new Date(session.startTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                                                        {' – '}
                                                        {new Date(session.endTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                                                    </Typography>
                                                    <Stack direction="row" spacing={0.75} flexWrap="wrap" sx={{ mt: 0.75, rowGap: 0.5 }}>
                                                        {session.room && (
                                                            <Chip icon={<RoomIcon />} label={session.room} size="small" variant="outlined" />
                                                        )}
                                                        {session.speakerName && (
                                                            <Chip icon={<PersonIcon />} label={session.speakerName} size="small" variant="outlined" />
                                                        )}
                                                        {session.capacity > 0 && (
                                                            <StatusChip
                                                                label={`Cap ${session.capacity}`}
                                                                status="neutral"
                                                                size="small"
                                                            />
                                                        )}
                                                    </Stack>
                                                </Box>
                                                <Tooltip title="Delete session">
                                                    <IconButton size="small" color="error" onClick={() => handleDelete(session.id)}>
                                                        <DeleteIcon fontSize="small" />
                                                    </IconButton>
                                                </Tooltip>
                                            </Box>
                                        ))}
                                    </Stack>
                                </SectionCard>
                            </Grid>
                        ))}
                    </Grid>
                ) : (
                    <SectionCard>
                        <EmptyState
                            icon={<ScheduleIcon sx={{ fontSize: 28 }} />}
                            title="No sessions yet"
                            description="Add your first session to start building the schedule."
                            action={
                                <Button
                                    variant="contained"
                                    startIcon={<AddIcon fontSize="small" />}
                                    onClick={() => setCreateDialog(true)}
                                >
                                    Add session
                                </Button>
                            }
                        />
                    </SectionCard>
                )
            ) : (
                <SectionCard>
                    <EmptyState
                        icon={<ScheduleIcon sx={{ fontSize: 28 }} />}
                        title="Pick an event"
                        description="Select an event above to view or manage its schedule."
                    />
                </SectionCard>
            )}

            <FormDialog
                open={createDialog}
                onClose={() => setCreateDialog(false)}
                title="Add session"
                subtitle="Create a new talk, workshop or break."
                icon={<ScheduleIcon />}
                maxWidth="sm"
                actions={(
                    <>
                        <Button onClick={() => setCreateDialog(false)} disabled={submitting}>
                            Cancel
                        </Button>
                        <LoadingButton variant="contained" onClick={handleCreate} loading={submitting}>
                            Create session
                        </LoadingButton>
                    </>
                )}
            >
                <FormSection title="Details">
                    <Grid container spacing={2}>
                        <Grid item xs={12}>
                            <TextField
                                fullWidth
                                label="Title"
                                value={form.title}
                                onChange={(e) => setForm({ ...form, title: e.target.value })}
                                required
                            />
                        </Grid>
                        <Grid item xs={12} sm={6}>
                            <TextField
                                fullWidth
                                type="datetime-local"
                                label="Start time"
                                value={form.startTime}
                                onChange={(e) => setForm({ ...form, startTime: e.target.value })}
                                InputLabelProps={{ shrink: true }}
                            />
                        </Grid>
                        <Grid item xs={12} sm={6}>
                            <TextField
                                fullWidth
                                type="datetime-local"
                                label="End time"
                                value={form.endTime}
                                onChange={(e) => setForm({ ...form, endTime: e.target.value })}
                                InputLabelProps={{ shrink: true }}
                            />
                        </Grid>
                        <Grid item xs={12} sm={4}>
                            <TextField
                                fullWidth
                                label="Room"
                                value={form.room}
                                onChange={(e) => setForm({ ...form, room: e.target.value })}
                            />
                        </Grid>
                        <Grid item xs={12} sm={4}>
                            <TextField
                                fullWidth
                                label="Track"
                                value={form.track}
                                onChange={(e) => setForm({ ...form, track: e.target.value })}
                            />
                        </Grid>
                        <Grid item xs={12} sm={4}>
                            <TextField
                                fullWidth
                                type="number"
                                label="Capacity"
                                value={form.capacity}
                                onChange={(e) => setForm({ ...form, capacity: e.target.value })}
                            />
                        </Grid>
                        <Grid item xs={12}>
                            <TextField
                                fullWidth
                                multiline
                                minRows={3}
                                label="Description"
                                value={form.description}
                                onChange={(e) => setForm({ ...form, description: e.target.value })}
                            />
                        </Grid>
                    </Grid>
                </FormSection>
            </FormDialog>
        </Box>
    );
};

export default OrganiserSchedule;

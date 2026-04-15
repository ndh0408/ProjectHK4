import React, { useState, useEffect, useCallback } from 'react';
import {
    Box, Typography, Paper, Button, Chip, Dialog, DialogTitle, DialogContent,
    DialogActions, TextField, Grid, Autocomplete, IconButton, Tooltip, Card, CardContent,
} from '@mui/material';
import {
    Add as AddIcon, Refresh as RefreshIcon, Delete as DeleteIcon,
    Schedule as ScheduleIcon, Room as RoomIcon, Person as PersonIcon,
} from '@mui/icons-material';
import { organiserApi } from '../../api';
import { toast } from 'react-toastify';

const OrganiserSchedule = () => {
    const [events, setEvents] = useState([]);
    const [selectedEvent, setSelectedEvent] = useState('');
    const [schedule, setSchedule] = useState(null);
    const [loading, setLoading] = useState(false);
    const [createDialog, setCreateDialog] = useState(false);
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
        } catch (e) { toast.error(e.response?.data?.message || 'Failed'); }
    };

    const handleDelete = async (sessionId) => {
        try {
            await organiserApi.deleteSession(sessionId);
            toast.success('Session deleted');
            loadSchedule();
        } catch { toast.error('Failed'); }
    };

    const tracks = schedule?.tracks || [];
    const sessions = schedule?.sessions || [];

    const groupedByTrack = {};
    sessions.forEach(s => {
        const track = s.track || 'General';
        if (!groupedByTrack[track]) groupedByTrack[track] = [];
        groupedByTrack[track].push(s);
    });

    return (
        <Box>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 3 }}>
                <Typography variant="h5" fontWeight="bold"><ScheduleIcon sx={{ mr: 1, verticalAlign: 'middle' }} />Schedule Builder</Typography>
                <Box sx={{ display: 'flex', gap: 1 }}>
                    <Button startIcon={<RefreshIcon />} onClick={loadSchedule}>Refresh</Button>
                    <Button variant="contained" startIcon={<AddIcon />} onClick={() => setCreateDialog(true)} disabled={!selectedEvent}>Add Session</Button>
                </Box>
            </Box>

            <Paper sx={{ p: 2, mb: 2 }}>
                <Autocomplete options={events} getOptionLabel={(o) => o.title || ''} value={events.find(e => e.id === selectedEvent) || null}
                    onChange={(_, v) => setSelectedEvent(v?.id || '')}
                    renderInput={(p) => <TextField {...p} label="Select Event" />}
                    isOptionEqualToValue={(o, v) => o.id === v.id} sx={{ minWidth: 400 }} />
            </Paper>

            {selectedEvent && schedule ? (
                Object.keys(groupedByTrack).length > 0 ? (
                    <Grid container spacing={2}>
                        {Object.entries(groupedByTrack).map(([track, trackSessions]) => (
                            <Grid item xs={12} md={tracks.length > 1 ? 6 : 12} key={track}>
                                <Paper sx={{ p: 2 }}>
                                    <Typography variant="h6" gutterBottom>
                                        <Chip label={track} color="primary" size="small" sx={{ mr: 1 }} />
                                        {trackSessions.length} sessions
                                    </Typography>
                                    {trackSessions.map(session => (
                                        <Card key={session.id} variant="outlined" sx={{ mb: 1, borderLeft: 3, borderColor: 'primary.main' }}>
                                            <CardContent sx={{ py: 1, '&:last-child': { pb: 1 } }}>
                                                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                                                    <Box>
                                                        <Typography variant="subtitle2">{session.title}</Typography>
                                                        <Typography variant="caption" color="text.secondary">
                                                            {new Date(session.startTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })} - {new Date(session.endTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                                                        </Typography>
                                                        <Box sx={{ display: 'flex', gap: 1, mt: 0.5 }}>
                                                            {session.room && <Chip icon={<RoomIcon />} label={session.room} size="small" variant="outlined" />}
                                                            {session.speakerName && <Chip icon={<PersonIcon />} label={session.speakerName} size="small" variant="outlined" />}
                                                        </Box>
                                                    </Box>
                                                    <Tooltip title="Delete"><IconButton size="small" color="error" onClick={() => handleDelete(session.id)}><DeleteIcon /></IconButton></Tooltip>
                                                </Box>
                                            </CardContent>
                                        </Card>
                                    ))}
                                </Paper>
                            </Grid>
                        ))}
                    </Grid>
                ) : (
                    <Paper sx={{ p: 4, textAlign: 'center' }}><Typography color="text.secondary">No sessions yet. Add your first session!</Typography></Paper>
                )
            ) : (
                <Paper sx={{ p: 4, textAlign: 'center' }}><Typography color="text.secondary">Select an event to manage its schedule</Typography></Paper>
            )}

            <Dialog open={createDialog} onClose={() => setCreateDialog(false)} maxWidth="sm" fullWidth>
                <DialogTitle>Add Session</DialogTitle>
                <DialogContent>
                    <Grid container spacing={2} sx={{ mt: 0.5 }}>
                        <Grid item xs={12}><TextField fullWidth label="Title" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} /></Grid>
                        <Grid item xs={6}><TextField fullWidth type="datetime-local" label="Start" value={form.startTime} onChange={(e) => setForm({ ...form, startTime: e.target.value })} InputLabelProps={{ shrink: true }} /></Grid>
                        <Grid item xs={6}><TextField fullWidth type="datetime-local" label="End" value={form.endTime} onChange={(e) => setForm({ ...form, endTime: e.target.value })} InputLabelProps={{ shrink: true }} /></Grid>
                        <Grid item xs={6}><TextField fullWidth label="Room" value={form.room} onChange={(e) => setForm({ ...form, room: e.target.value })} /></Grid>
                        <Grid item xs={6}><TextField fullWidth label="Track" value={form.track} onChange={(e) => setForm({ ...form, track: e.target.value })} /></Grid>
                        <Grid item xs={6}><TextField fullWidth type="number" label="Capacity" value={form.capacity} onChange={(e) => setForm({ ...form, capacity: e.target.value })} /></Grid>
                        <Grid item xs={12}><TextField fullWidth multiline rows={2} label="Description" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} /></Grid>
                    </Grid>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setCreateDialog(false)}>Cancel</Button>
                    <Button variant="contained" onClick={handleCreate}>Create</Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default OrganiserSchedule;

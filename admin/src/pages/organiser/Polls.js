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
    FormControlLabel,
    Checkbox,
} from '@mui/material';
import {
    Add as AddIcon,
    Refresh as RefreshIcon,
    Poll as PollIcon,
    Stop as StopIcon,
    HowToVote as VoteIcon,
    AutoAwesome as AIIcon,
    Edit as EditIcon,
    Delete as DeleteIcon,
    NavigateNext as NextIcon,
    NavigateBefore as PrevIcon,
    PlayArrow as PlayIcon,
    Cancel as CancelIcon,
} from '@mui/icons-material';
import { organiserApi } from '../../api';
import {
    PageHeader,
    SectionCard,
    FormDialog,
    LoadingButton,
    EmptyState,
    StatusChip,
} from '../../components/ui';
import { toast } from 'react-toastify';

const pollStatusMap = {
    ACTIVE: 'success',
    SCHEDULED: 'warning',
    CLOSED: 'danger',
    DRAFT: 'neutral',
    CANCELLED: 'neutral',
};

const OrganiserPolls = () => {
    const [events, setEvents] = useState([]);
    const [selectedEvent, setSelectedEvent] = useState('');
    const [polls, setPolls] = useState([]);
    const [loading, setLoading] = useState(false);
    const [createDialog, setCreateDialog] = useState(false);
    const [aiDialog, setAiDialog] = useState(false);
    const [aiLoading, setAiLoading] = useState(false);
    const [aiRequest, setAiRequest] = useState({
        topic: '',
        numOptions: 4,
        pollType: 'SINGLE_CHOICE',
        numberOfQuestions: 1,
        language: 'English',
        additionalContext: '',
    });
    const [newPoll, setNewPoll] = useState({
        question: '',
        type: 'SINGLE_CHOICE',
        options: ['', ''],
        maxRating: 5,
        closesAt: '',
        scheduledOpenAt: '',
        closeAtVoteCount: '',
        autoOpenEventStart: false,
        autoCloseEventEnd: false,
        autoCloseTenDaysAfterEventEnd: false,
        hideResultsUntilClosed: false,
        draft: false,
    });
    const [editPoll, setEditPoll] = useState(null);
    const [editDialog, setEditDialog] = useState(false);
    const [aiGeneratedPolls, setAiGeneratedPolls] = useState([]);
    const [currentAIPollIndex, setCurrentAIPollIndex] = useState(0);
    const [isAIGeneratedMode, setIsAIGeneratedMode] = useState(false);
    // Tracks which indices from aiGeneratedPolls have already been persisted so
    // the final "Create Poll" button can catch up any polls the user skipped
    // past via the Next arrow without explicitly creating them.
    const [createdAIPollIndices, setCreatedAIPollIndices] = useState(() => new Set());
    const [deleteConfirmDialog, setDeleteConfirmDialog] = useState(false);
    const [pollToDelete, setPollToDelete] = useState(null);
    const [extendDialog, setExtendDialog] = useState(false);
    const [pollToExtend, setPollToExtend] = useState(null);
    const [extendMode, setExtendMode] = useState('preset'); // 'preset' | 'custom'
    const [extendHours, setExtendHours] = useState(1);
    const [extendDays, setExtendDays] = useState(0);
    const [customCloseTime, setCustomCloseTime] = useState('');
    // State transition dialogs
    const [scheduleDialog, setScheduleDialog] = useState(false);
    const [pollToSchedule, setPollToSchedule] = useState(null);
    const [scheduleOpenAt, setScheduleOpenAt] = useState('');
    const [cancelConfirmDialog, setCancelConfirmDialog] = useState(false);
    const [pollToCancel, setPollToCancel] = useState(null);

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
        if (!selectedEvent) {
            console.log('[Polls] No event selected, skipping load');
            return;
        }
        if (!silent) setLoading(true);
        try {
            console.log('=== [Polls] START Loading polls ===');
            console.log('[Polls] Event ID:', selectedEvent);
            console.log('[Polls] Timestamp:', new Date().toISOString());

            const response = await organiserApi.getEventPolls(selectedEvent, { _t: Date.now() });

            console.log('[Polls] Raw response:', response);
            console.log('[Polls] Response data:', response.data);
            console.log('[Polls] Response status:', response.status);

            const pollsData = response.data?.data || [];
            console.log('[Polls] Loaded polls count:', pollsData.length);
            console.log('[Polls] Polls data array:', pollsData);

            // Log each poll in detail
            pollsData.forEach((poll, index) => {
                console.log(`[Polls] Poll #${index + 1}:`, {
                    id: poll.id,
                    question: poll.question,
                    status: poll.status,
                    type: poll.type,
                    totalVotes: poll.totalVotes,
                    optionsCount: poll.options?.length || 0,
                    options: poll.options,
                    eventTitle: poll.eventTitle,
                    createdByName: poll.createdByName
                });
            });

            setPolls(pollsData);
            console.log('=== [Polls] END Loading polls ===\n');
        } catch (error) {
            console.error('=== [Polls] ERROR Loading polls ===');
            console.error('[Polls] Error name:', error.name);
            console.error('[Polls] Error message:', error.message);
            console.error('[Polls] Error code:', error.code);
            console.error('[Polls] Error config:', error.config);
            console.error('[Polls] Error response:', error.response);
            console.error('[Polls] Error response data:', error.response?.data);
            console.error('[Polls] Error response status:', error.response?.status);
            console.error('[Polls] Error response headers:', error.response?.headers);
            console.error('=== [Polls] END ERROR ===\n');

            if (!silent) toast.error('Failed to load polls: ' + (error.response?.data?.message || error.message));
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

        // Validate close time if set
        if (!validatePollCloseTime(newPoll.closesAt)) {
            return;
        }

        // Validate scheduled open time
        if (newPoll.scheduledOpenAt && new Date(newPoll.scheduledOpenAt) <= new Date()) {
            toast.error('Scheduled open time must be in the future');
            return;
        }

        const data = {
            question: newPoll.question,
            type: newPoll.type,
            options: newPoll.type !== 'RATING'
                ? newPoll.options.filter(o => o.trim())
                : undefined,
            maxRating: newPoll.type === 'RATING' ? newPoll.maxRating : undefined,
            closesAt: localDatetimeToUtc(newPoll.closesAt),
            scheduledOpenAt: newPoll.scheduledOpenAt ? localDatetimeToUtc(newPoll.scheduledOpenAt) : null,
            closeAtVoteCount: newPoll.closeAtVoteCount ? parseInt(newPoll.closeAtVoteCount) : null,
            autoOpenEventStart: newPoll.autoOpenEventStart,
            autoCloseEventEnd: newPoll.autoCloseEventEnd,
            autoCloseTenDaysAfterEventEnd: newPoll.autoCloseTenDaysAfterEventEnd,
            hideResultsUntilClosed: newPoll.hideResultsUntilClosed,
            draft: newPoll.draft,
        };

        if (data.type !== 'RATING' && (!data.options || data.options.length < 2)) {
            toast.error('At least 2 options are required');
            return;
        }

        try {
            console.log('[Polls] Creating poll for event:', selectedEvent, 'data:', data);
            const response = await organiserApi.createPoll(selectedEvent, data);
            console.log('[Polls] Created poll:', response.data);
            if (response.data?.data) {
                const createdPoll = response.data.data;
                const statusMsg = createdPoll.status === 'DRAFT' ? 'saved as draft' : 'created';
                toast.success(`Poll "${createdPoll.question}" ${statusMsg}!`);

                // Remember that this AI-mode index has now been persisted.
                const updatedCreatedSet = new Set(createdAIPollIndices);
                if (isAIGeneratedMode) updatedCreatedSet.add(currentAIPollIndex);
                setCreatedAIPollIndices(updatedCreatedSet);

                // If in AI mode and more polls exist, show next
                if (isAIGeneratedMode && currentAIPollIndex < aiGeneratedPolls.length - 1) {
                    const nextIndex = currentAIPollIndex + 1;
                    setCurrentAIPollIndex(nextIndex);
                    loadNextAIPoll(nextIndex);
                    // Load polls in background without waiting
                    loadPolls(true);
                } else {
                    // Catch-up: if user navigated past some AI-generated polls
                    // with the Next arrow without creating them, bulk-create
                    // those remaining ones using the original AI data.
                    if (isAIGeneratedMode) {
                        const skipped = aiGeneratedPolls
                            .map((p, i) => ({ poll: p, index: i }))
                            .filter(({ index }) => !updatedCreatedSet.has(index));

                        if (skipped.length > 0) {
                            const baseCloseAt = data.closesAt;
                            let bulkCreated = 0;
                            for (const { poll } of skipped) {
                                try {
                                    const payload = {
                                        question: poll.question,
                                        type: poll.pollType || 'SINGLE_CHOICE',
                                        options: (poll.pollType || 'SINGLE_CHOICE') !== 'RATING'
                                            ? (poll.options || []).filter((o) => o?.trim())
                                            : undefined,
                                        maxRating: (poll.pollType || 'SINGLE_CHOICE') === 'RATING'
                                            ? (poll.maxRating || 5)
                                            : undefined,
                                        closesAt: baseCloseAt,
                                        scheduledOpenAt: null,
                                        closeAtVoteCount: null,
                                        autoOpenEventStart: data.autoOpenEventStart,
                                        autoCloseEventEnd: data.autoCloseEventEnd,
                                        autoCloseTenDaysAfterEventEnd: data.autoCloseTenDaysAfterEventEnd,
                                        hideResultsUntilClosed: data.hideResultsUntilClosed,
                                        draft: data.draft,
                                    };
                                    if (payload.type !== 'RATING' && (!payload.options || payload.options.length < 2)) {
                                        continue;
                                    }
                                    await organiserApi.createPoll(selectedEvent, payload);
                                    bulkCreated += 1;
                                } catch (bulkErr) {
                                    console.warn('[Polls] Skipped AI poll failed to create:', bulkErr);
                                }
                            }
                            if (bulkCreated > 0) {
                                toast.success(`Also created ${bulkCreated} skipped AI poll${bulkCreated > 1 ? 's' : ''}.`);
                            }
                        }
                    }

                    // Close dialog and reset state
                    setCreateDialog(false);
                    setNewPoll({
                        question: '',
                        type: 'SINGLE_CHOICE',
                        options: ['', ''],
                        maxRating: 5,
                        closesAt: '',
                        scheduledOpenAt: '',
                        closeAtVoteCount: '',
                        autoOpenEventStart: false,
                        autoCloseEventEnd: false,
                        autoCloseTenDaysAfterEventEnd: false,
                        hideResultsUntilClosed: false,
                        draft: false,
                    });
                    setIsAIGeneratedMode(false);
                    setAiGeneratedPolls([]);
                    setCurrentAIPollIndex(0);
                    setCreatedAIPollIndices(new Set());
                    // Reload polls immediately and again after delay to ensure sync
                    await loadPolls();
                    setTimeout(async () => {
                        await loadPolls();
                    }, 1000);
                }
            } else {
                throw new Error('Invalid response from server');
            }
        } catch (error) {
            console.error('[Polls] Error creating poll:', error);
            toast.error('Failed to create poll: ' + (error.response?.data?.message || error.message));
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

    // State Transition Handlers
    const handlePublishPoll = async (pollId) => {
        try {
            await organiserApi.publishPoll(pollId);
            toast.success('Poll published successfully');
            loadPolls();
        } catch (error) {
            toast.error('Failed to publish poll: ' + (error.response?.data?.message || error.message));
        }
    };

    const handleOpenScheduleDialog = (poll) => {
        setPollToSchedule(poll);
        setScheduleOpenAt(getMinCloseDate());
        setScheduleDialog(true);
    };

    const handleCloseScheduleDialog = () => {
        setScheduleDialog(false);
        setPollToSchedule(null);
        setScheduleOpenAt('');
    };

    const handleSchedulePoll = async () => {
        if (!pollToSchedule) return;
        if (!scheduleOpenAt) {
            toast.error('Please select a scheduled open time');
            return;
        }
        try {
            const utcTime = localDatetimeToUtc(scheduleOpenAt);
            await organiserApi.schedulePoll(pollToSchedule.id, utcTime);
            toast.success('Poll scheduled successfully');
            handleCloseScheduleDialog();
            loadPolls();
        } catch (error) {
            toast.error('Failed to schedule poll: ' + (error.response?.data?.message || error.message));
        }
    };

    const handleOpenPollNow = async (pollId) => {
        try {
            await organiserApi.openPoll(pollId);
            toast.success('Poll opened successfully');
            loadPolls();
        } catch (error) {
            toast.error('Failed to open poll: ' + (error.response?.data?.message || error.message));
        }
    };

    const handleReopenPoll = async (pollId) => {
        try {
            await organiserApi.reopenPoll(pollId);
            toast.success('Poll reopened successfully');
            loadPolls();
        } catch (error) {
            toast.error('Failed to reopen poll: ' + (error.response?.data?.message || error.message));
        }
    };

    const handleOpenCancelDialog = (poll) => {
        setPollToCancel(poll);
        setCancelConfirmDialog(true);
    };

    const handleCloseCancelDialog = () => {
        setCancelConfirmDialog(false);
        setPollToCancel(null);
    };

    const handleCancelPoll = async () => {
        if (!pollToCancel) return;
        try {
            await organiserApi.cancelPoll(pollToCancel.id);
            toast.success('Poll cancelled');
            handleCloseCancelDialog();
            loadPolls();
        } catch (error) {
            toast.error('Failed to cancel poll: ' + (error.response?.data?.message || error.message));
        }
    };

    const handleOpenDeleteConfirm = (pollId) => {
        setPollToDelete(pollId);
        setDeleteConfirmDialog(true);
    };

    const handleCloseDeleteConfirm = () => {
        setDeleteConfirmDialog(false);
        setPollToDelete(null);
    };

    const handleConfirmDelete = async () => {
        if (!pollToDelete) return;
        try {
            await organiserApi.deletePoll(pollToDelete);
            toast.success('Poll deleted');
            loadPolls();
        } catch (error) {
            toast.error('Failed to delete poll: ' + (error.response?.data?.message || error.message));
        } finally {
            handleCloseDeleteConfirm();
        }
    };

    const handleOpenExtendDialog = (poll) => {
        if (!poll.isActive) {
            toast.error('Cannot extend a closed poll');
            return;
        }
        setPollToExtend(poll);
        setExtendMode('preset');
        setExtendHours(1);
        setExtendDays(0);
        setCustomCloseTime('');
        setExtendDialog(true);
    };

    const handleCloseExtendDialog = () => {
        setExtendDialog(false);
        setPollToExtend(null);
    };

    const handleExtendPoll = async () => {
        if (!pollToExtend) return;
        try {
            let params;
            if (extendMode === 'custom') {
                if (!customCloseTime) {
                    toast.error('Please select a closing time');
                    return;
                }
                params = { customTime: localDatetimeToUtc(customCloseTime) };
            } else {
                if (extendHours < 1 && extendDays < 1) {
                    toast.error('Please specify at least hours or days');
                    return;
                }
                params = { hours: extendHours || 0, days: extendDays || 0 };
            }
            await organiserApi.extendPoll(pollToExtend.id, params);
            toast.success('Poll extended successfully');
            loadPolls();
        } catch (error) {
            toast.error('Failed to extend poll: ' + (error.response?.data?.message || error.message));
        } finally {
            handleCloseExtendDialog();
        }
    };

    // Edit poll option handlers
    const addEditOption = () => {
        if (editPoll.options.length < 10) {
            setEditPoll({ ...editPoll, options: [...editPoll.options, ''] });
        }
    };

    const removeEditOption = (index) => {
        if (editPoll.options.length > 2) {
            const options = editPoll.options.filter((_, i) => i !== index);
            setEditPoll({ ...editPoll, options });
        }
    };

    const updateEditOption = (index, value) => {
        const options = [...editPoll.options];
        options[index] = value;
        setEditPoll({ ...editPoll, options });
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

    // Helper to get minimum datetime for poll closing (must be after now)
    // Returns local datetime string for datetime-local input
    const getMinCloseDate = () => {
        const now = new Date();
        // Format as YYYY-MM-DDTHH:mm in local time
        const year = now.getFullYear();
        const month = String(now.getMonth() + 1).padStart(2, '0');
        const day = String(now.getDate()).padStart(2, '0');
        const hours = String(now.getHours()).padStart(2, '0');
        const minutes = String(now.getMinutes()).padStart(2, '0');
        return `${year}-${month}-${day}T${hours}:${minutes}`;
    };

    // Helper to convert UTC ISO string to local datetime-local format
    const utcToLocalDatetime = (utcString) => {
        if (!utcString) return '';
        const date = new Date(utcString);
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        const hours = String(date.getHours()).padStart(2, '0');
        const minutes = String(date.getMinutes()).padStart(2, '0');
        return `${year}-${month}-${day}T${hours}:${minutes}`;
    };

    // Helper to convert local datetime-local value to UTC ISO string
    const localDatetimeToUtc = (localString) => {
        if (!localString) return undefined;
        const date = new Date(localString);
        return date.toISOString();
    };

    // Helper to validate poll close time
    // closesAt is in local datetime-local format
    const validatePollCloseTime = (closesAt) => {
        if (!closesAt) return true; // Optional field
        const closeDate = new Date(closesAt);
        const now = new Date();
        // Add 1 minute buffer to account for processing time
        if (closeDate <= now.setMinutes(now.getMinutes() - 1)) {
            toast.error('Poll close time must be in the future');
            return false;
        }
        return true;
    };

    const handleOpenEditDialog = (poll) => {
        // Format closesAt for datetime-local input
        const closesAtLocal = utcToLocalDatetime(poll.closesAt);
        setEditPoll({
            ...poll,
            closesAt: closesAtLocal,
            options: poll.options?.map(o => o.text) || ['', ''],
            maxRating: poll.maxRating || 5,
        });
        setEditDialog(true);
    };

    const handleEditPoll = async () => {
        if (!editPoll.question.trim()) {
            toast.error('Question is required');
            return;
        }

        // Validate options for non-RATING polls
        if (editPoll.type !== 'RATING') {
            const validOptions = editPoll.options.filter(o => o.trim());
            if (validOptions.length < 2) {
                toast.error('At least 2 options are required');
                return;
            }
        }

        // Validate close time if set
        if (!validatePollCloseTime(editPoll.closesAt)) {
            return;
        }

        const data = {
            question: editPoll.question,
            type: editPoll.type,
            options: editPoll.type !== 'RATING' ? editPoll.options.filter(o => o.trim()) : undefined,
            maxRating: editPoll.type === 'RATING' ? (editPoll.maxRating || 5) : undefined,
            closesAt: localDatetimeToUtc(editPoll.closesAt),
        };

        try {
            await organiserApi.updatePoll(editPoll.id, data);
            toast.success('Poll updated successfully');
            setEditDialog(false);
            setEditPoll(null);
            loadPolls();
        } catch (error) {
            toast.error('Failed to update poll');
        }
    };

    const loadNextAIPoll = (index) => {
        const pollData = aiGeneratedPolls[index];
        if (pollData) {
            setNewPoll({
                question: pollData.question || '',
                type: pollData.pollType || 'SINGLE_CHOICE',
                options: pollData.options?.length > 0 ? pollData.options : ['', ''],
                maxRating: pollData.maxRating || 5,
                closesAt: '',
                scheduledOpenAt: '',
                closeAtVoteCount: '',
                autoOpenEventStart: false,
                autoCloseEventEnd: false,
                hideResultsUntilClosed: false,
                draft: false,
            });
        }
    };

    const handleNextAIPoll = () => {
        if (currentAIPollIndex < aiGeneratedPolls.length - 1) {
            const newIndex = currentAIPollIndex + 1;
            setCurrentAIPollIndex(newIndex);
            loadNextAIPoll(newIndex);
        }
    };

    const handlePrevAIPoll = () => {
        if (currentAIPollIndex > 0) {
            const newIndex = currentAIPollIndex - 1;
            setCurrentAIPollIndex(newIndex);
            loadNextAIPoll(newIndex);
        }
    };

    const handleSkipAIPoll = () => {
        if (currentAIPollIndex < aiGeneratedPolls.length - 1) {
            handleNextAIPoll();
        } else {
            setCreateDialog(false);
            setIsAIGeneratedMode(false);
            setAiGeneratedPolls([]);
            setCurrentAIPollIndex(0);
            setCreatedAIPollIndices(new Set());
            setNewPoll({
                question: '',
                type: 'SINGLE_CHOICE',
                options: ['', ''],
                maxRating: 5,
                closesAt: '',
                scheduledOpenAt: '',
                closeAtVoteCount: '',
                autoOpenEventStart: false,
                autoCloseEventEnd: false,
                hideResultsUntilClosed: false,
                draft: false,
            });
        }
    };

    const getStatusLabel = (status) => {
        switch (status) {
            case 'DRAFT': return 'DRAFT';
            case 'SCHEDULED': return 'SCHEDULED';
            case 'ACTIVE': return 'ACTIVE';
            case 'CLOSED': return 'CLOSED';
            case 'CANCELLED': return 'CANCELLED';
            default: return status || 'UNKNOWN';
        }
    };

    const canEditPoll = (poll) => {
        return (poll.status === 'DRAFT' || poll.status === 'SCHEDULED') && poll.totalVotes === 0;
    };

    const canPublishPoll = (poll) => poll.status === 'DRAFT';
    const canSchedulePoll = (poll) => poll.status === 'DRAFT';
    const canOpenPoll = (poll) => poll.status === 'SCHEDULED';
    const canClosePoll = (poll) => poll.status === 'ACTIVE';
    const canReopenPoll = (poll) => poll.status === 'CLOSED';
    const canCancelPoll = (poll) => poll.status === 'DRAFT' || poll.status === 'SCHEDULED';

    // Format remaining time for SCHEDULED poll
    const getScheduledTimeRemaining = (scheduledOpenAt) => {
        if (!scheduledOpenAt) return null;
        const scheduled = new Date(scheduledOpenAt);
        const now = new Date();
        const diffMs = scheduled - now;
        if (diffMs <= 0) return 'Ready to open';

        const diffHrs = Math.floor(diffMs / (1000 * 60 * 60));
        const diffMins = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
        const diffDays = Math.floor(diffHrs / 24);

        if (diffDays > 0) return `Opens in ${diffDays}d ${diffHrs % 24}h`;
        if (diffHrs > 0) return `Opens in ${diffHrs}h ${diffMins}m`;
        return `Opens in ${diffMins}m`;
    };

    const handleGeneratePollWithAI = async () => {
        if (!aiRequest.topic.trim()) {
            toast.error('Please enter a topic');
            return;
        }

        setAiLoading(true);
        try {
            const response = await organiserApi.generatePollWithAI(aiRequest);
            const aiResult = response.data.data;

            // Parse JSON response from AI with improved error handling
            let parsedPolls = [];
            try {
                // If aiResult is already an object/array, use it directly
                if (typeof aiResult === 'object' && aiResult !== null) {
                    parsedPolls = Array.isArray(aiResult) ? aiResult : [aiResult];
                } else if (typeof aiResult === 'string') {
                    // Try multiple parsing strategies for string response
                    let jsonStr = aiResult;

                    // Remove markdown code blocks
                    jsonStr = jsonStr.replace(/```json\n?|\n?```/g, '');

                    // Try to find JSON array or object in the response
                    const arrayMatch = jsonStr.match(/\[[\s\S]*\]/);
                    const objectMatch = jsonStr.match(/\{[\s\S]*\}/);

                    if (arrayMatch) {
                        jsonStr = arrayMatch[0];
                    } else if (objectMatch) {
                        jsonStr = objectMatch[0];
                    }

                    jsonStr = jsonStr.trim();
                    parsedPolls = JSON.parse(jsonStr);

                    if (!Array.isArray(parsedPolls)) {
                        parsedPolls = [parsedPolls];
                    }
                } else {
                    throw new Error('Unexpected response type from AI');
                }

                // Validate each poll has required fields
                parsedPolls = parsedPolls.filter(poll =>
                    poll && poll.question && poll.question.trim()
                );

                if (parsedPolls.length === 0) {
                    throw new Error('No valid polls found in AI response');
                }
            } catch (e) {
                console.error('Parse error:', e);
                console.error('AI Response:', aiResult);
                toast.error('Failed to parse AI response. Please try again or create poll manually.');
                return;
            }

            setAiGeneratedPolls(parsedPolls);
            setCurrentAIPollIndex(0);
            setIsAIGeneratedMode(true);
            setCreatedAIPollIndices(new Set());

            // Load first poll into create dialog
            const firstPoll = parsedPolls[0];
            setNewPoll({
                question: firstPoll.question || '',
                type: firstPoll.pollType || 'SINGLE_CHOICE',
                options: firstPoll.options?.length > 0 ? firstPoll.options : ['', ''],
                maxRating: firstPoll.maxRating || 5,
                closesAt: '',
            });

            setAiDialog(false);
            setCreateDialog(true);
            toast.success(`Generated ${parsedPolls.length} poll(s). Edit and create them!`);
        } catch (error) {
            toast.error('Failed to generate poll with AI');
            console.error(error);
        } finally {
            setAiLoading(false);
        }
    };

    return (
        <Box>
            <PageHeader
                title="Live Polls"
                subtitle="Create live polls, let attendees vote in real time and generate questions with AI."
                icon={<PollIcon />}
                actions={[
                    <Button key="refresh" startIcon={<RefreshIcon />} onClick={loadPolls}>
                        Refresh
                    </Button>,
                    <Button
                        key="ai"
                        variant="outlined"
                        startIcon={<AIIcon />}
                        onClick={() => setAiDialog(true)}
                        disabled={!selectedEvent}
                    >
                        Generate with AI
                    </Button>,
                    <Button
                        key="create"
                        variant="contained"
                        startIcon={<AddIcon />}
                        onClick={() => {
                            setIsAIGeneratedMode(false);
                            setNewPoll({ question: '', type: 'SINGLE_CHOICE', options: ['', ''], maxRating: 5, closesAt: '' });
                            setCreateDialog(true);
                        }}
                        disabled={!selectedEvent}
                    >
                        Create Poll
                    </Button>,
                ]}
            />

            <Paper sx={{ p: 2, mb: 2 }}>
                <Autocomplete
                    options={events}
                    getOptionLabel={(option) => option.title || ''}
                    value={events.find(e => e.id === selectedEvent) || null}
                    onChange={(_, newValue) => {
                        const newEventId = newValue?.id || '';
                        console.log('[Polls] Selected event:', newEventId, newValue);
                        setSelectedEvent(newEventId);
                    }}
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
                                    borderColor: poll.status === 'ACTIVE' ? 'success.main'
                                        : poll.status === 'SCHEDULED' ? 'warning.main'
                                            : poll.status === 'CLOSED' ? 'error.main'
                                                : 'grey.300',
                                    borderWidth: (poll.status === 'ACTIVE' || poll.status === 'SCHEDULED') ? 2 : 1,
                                    opacity: poll.status === 'CANCELLED' ? 0.7 : 1,
                                }}>
                                    <CardContent>
                                        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 2 }}>
                                            <Box sx={{ flex: 1 }}>
                                                <Typography variant="h6" gutterBottom>
                                                    {poll.question}
                                                    {poll.hideResultsUntilClosed && poll.status !== 'CANCELLED' && (
                                                        <Chip
                                                            size="small"
                                                            label="Hidden Results"
                                                            sx={{ ml: 1, fontSize: '0.65rem', height: 20 }}
                                                            color="secondary"
                                                        />
                                                    )}
                                                </Typography>
                                                <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                                                    <StatusChip
                                                        label={getStatusLabel(poll.status)}
                                                        status={pollStatusMap[poll.status] || 'neutral'}
                                                    />
                                                    <Chip
                                                        label={poll.type?.replace(/_/g, ' ') || 'Unknown'}
                                                        size="small"
                                                        variant="outlined"
                                                    />
                                                    <Chip
                                                        icon={<VoteIcon sx={{ fontSize: 16 }} />}
                                                        label={`${poll.totalVotes} votes`}
                                                        size="small"
                                                        color="info"
                                                    />
                                                    {poll.closeAtVoteCount && poll.status === 'ACTIVE' && (
                                                        <Chip
                                                            size="small"
                                                            label={`Auto-close at ${poll.closeAtVoteCount} votes`}
                                                            sx={{ fontSize: '0.7rem' }}
                                                            color="warning"
                                                            variant="outlined"
                                                        />
                                                    )}
                                                </Box>
                                            </Box>
                                            <Box sx={{ display: 'flex', gap: 0.5, flexWrap: 'wrap', justifyContent: 'flex-end' }}>
                                                {/* Edit */}
                                                <Tooltip title={canEditPoll(poll) ? "Edit Poll" : "Cannot edit - poll has votes or is not in editable state"}>
                                                    <span>
                                                        <IconButton
                                                            size="small"
                                                            color="primary"
                                                            onClick={() => handleOpenEditDialog(poll)}
                                                            disabled={!canEditPoll(poll)}
                                                        >
                                                            <EditIcon fontSize="small" />
                                                        </IconButton>
                                                    </span>
                                                </Tooltip>

                                                {/* Publish (DRAFT) */}
                                                {canPublishPoll(poll) && (
                                                    <Tooltip title="Publish Now">
                                                        <IconButton
                                                            size="small"
                                                            color="success"
                                                            onClick={() => handlePublishPoll(poll.id)}
                                                        >
                                                            <AddIcon fontSize="small" />
                                                        </IconButton>
                                                    </Tooltip>
                                                )}

                                                {/* Schedule (DRAFT) */}
                                                {canSchedulePoll(poll) && (
                                                    <Tooltip title="Schedule Open Time">
                                                        <IconButton
                                                            size="small"
                                                            color="info"
                                                            onClick={() => handleOpenScheduleDialog(poll)}
                                                        >
                                                            <Typography fontSize="small">⏰</Typography>
                                                        </IconButton>
                                                    </Tooltip>
                                                )}

                                                {/* Open Now (SCHEDULED) */}
                                                {canOpenPoll(poll) && (
                                                    <Tooltip title="Open Now">
                                                        <IconButton
                                                            size="small"
                                                            color="success"
                                                            onClick={() => handleOpenPollNow(poll.id)}
                                                        >
                                                            <PlayIcon fontSize="small" />
                                                        </IconButton>
                                                    </Tooltip>
                                                )}

                                                {/* Close (ACTIVE) */}
                                                {canClosePoll(poll) && (
                                                    <Tooltip title="Close Poll">
                                                        <IconButton
                                                            size="small"
                                                            color="warning"
                                                            onClick={() => handleClosePoll(poll.id)}
                                                        >
                                                            <StopIcon fontSize="small" />
                                                        </IconButton>
                                                    </Tooltip>
                                                )}

                                                {/* Reopen (CLOSED) */}
                                                {canReopenPoll(poll) && (
                                                    <Tooltip title="Reopen Poll">
                                                        <IconButton
                                                            size="small"
                                                            color="success"
                                                            onClick={() => handleReopenPoll(poll.id)}
                                                        >
                                                            <RefreshIcon fontSize="small" />
                                                        </IconButton>
                                                    </Tooltip>
                                                )}

                                                {/* Extend (ACTIVE with closesAt) */}
                                                {poll.status === 'ACTIVE' && poll.closesAt && (
                                                    <Tooltip title="Extend Time">
                                                        <IconButton
                                                            size="small"
                                                            color="info"
                                                            onClick={() => handleOpenExtendDialog(poll)}
                                                        >
                                                            <AddIcon fontSize="small" />
                                                        </IconButton>
                                                    </Tooltip>
                                                )}

                                                {/* Cancel (DRAFT/SCHEDULED) */}
                                                {canCancelPoll(poll) && (
                                                    <Tooltip title="Cancel Poll">
                                                        <IconButton
                                                            size="small"
                                                            color="error"
                                                            onClick={() => handleOpenCancelDialog(poll)}
                                                        >
                                                            <CancelIcon fontSize="small" />
                                                        </IconButton>
                                                    </Tooltip>
                                                )}

                                                {/* Delete */}
                                                <Tooltip title="Delete Poll">
                                                    <IconButton
                                                        size="small"
                                                        color="error"
                                                        onClick={() => handleOpenDeleteConfirm(poll.id)}
                                                    >
                                                        <DeleteIcon fontSize="small" />
                                                    </IconButton>
                                                </Tooltip>

                                                {poll.isActive && poll.closesAt && (
                                                    <Tooltip title="Extend Poll Time">
                                                        <IconButton
                                                            color="info"
                                                            onClick={() => handleOpenExtendDialog(poll)}
                                                        >
                                                            <AddIcon />
                                                        </IconButton>
                                                    </Tooltip>
                                                )}
                                            </Box>
                                        </Box>

                                        {poll.options?.map((option) => (
                                            <Box key={option.id || option.text} sx={{ mb: 1 }}>
                                                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 0.5 }}>
                                                    <Typography variant="body2">{option.text || 'Option'}</Typography>
                                                    <Typography variant="body2" color="text.secondary">
                                                        {option.voteCount || 0} ({(option.percentage || 0).toFixed(1)}%)
                                                    </Typography>
                                                </Box>
                                                <LinearProgress
                                                    variant="determinate"
                                                    value={option.percentage || 0}
                                                    sx={{
                                                        height: 8,
                                                        borderRadius: 4,
                                                        backgroundColor: 'grey.200',
                                                    }}
                                                />
                                            </Box>
                                        ))}

                                        {poll.closesAt && poll.isActive && (
                                            <>
                                                {(() => {
                                                    const closesAt = new Date(poll.closesAt);
                                                    const now = new Date();
                                                    const diffMs = closesAt - now;
                                                    const diffHrs = Math.floor(diffMs / (1000 * 60 * 60));
                                                    const diffMins = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
                                                    const isUrgent = diffHrs < 1 && diffMs > 0;

                                                    return (
                                                        <>
                                                            <Typography variant="caption" color={isUrgent ? 'error' : 'text.secondary'} sx={{ mt: 1, display: 'block', fontWeight: isUrgent ? 'bold' : 'normal' }}>
                                                                {isUrgent ? '⏰ ' : '📅 '}
                                                                Closes: {closesAt.toLocaleString()}
                                                                {diffMs > 0 && (
                                                                    <span style={{ marginLeft: 8, color: isUrgent ? '#d32f2f' : 'inherit' }}>
                                                                        ({diffHrs > 0 ? `${diffHrs}h ` : ''}{diffMins}m remaining)
                                                                    </span>
                                                                )}
                                                            </Typography>
                                                            {isUrgent && (
                                                                <Chip
                                                                    label="Ending soon"
                                                                    size="small"
                                                                    color="error"
                                                                    sx={{ mt: 0.5, height: 20, fontSize: '0.65rem' }}
                                                                />
                                                            )}
                                                        </>
                                                    );
                                                })()}
                                            </>
                                        )}
                                        {!poll.isActive && poll.closedAt && (
                                            <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
                                                Closed at: {new Date(poll.closedAt).toLocaleString()}
                                            </Typography>
                                        )}

                                        {/* Scheduled poll countdown */}
                                        {poll.status === 'SCHEDULED' && poll.scheduledOpenAt && (
                                            <Typography
                                                variant="caption"
                                                color="warning.main"
                                                sx={{ mt: 1, display: 'block', fontWeight: 'bold' }}
                                            >
                                                ⏰ {getScheduledTimeRemaining(poll.scheduledOpenAt)}
                                                <span style={{ marginLeft: 8, fontWeight: 'normal' }}>
                                                    (Opens: {new Date(poll.scheduledOpenAt).toLocaleString()})
                                                </span>
                                            </Typography>
                                        )}

                                        {/* Auto-open/close indicators */}
                                        {(poll.autoOpenEventStart || poll.autoCloseEventEnd || poll.autoCloseTenDaysAfterEventEnd) && poll.status !== 'CANCELLED' && (
                                            <Box sx={{ mt: 1 }}>
                                                {poll.autoOpenEventStart && (
                                                    <Chip
                                                        size="small"
                                                        label="Auto-open when event starts"
                                                        sx={{ mr: 0.5, fontSize: '0.65rem', height: 18 }}
                                                        color="info"
                                                        variant="outlined"
                                                    />
                                                )}
                                                {poll.autoCloseEventEnd && (
                                                    <Chip
                                                        size="small"
                                                        label="Auto-close when event ends"
                                                        sx={{ mr: 0.5, fontSize: '0.65rem', height: 18 }}
                                                        color="warning"
                                                        variant="outlined"
                                                    />
                                                )}
                                                {poll.autoCloseTenDaysAfterEventEnd && (
                                                    <Chip
                                                        size="small"
                                                        label="Auto-close 10 days after event ends"
                                                        sx={{ fontSize: '0.65rem', height: 18 }}
                                                        color="warning"
                                                        variant="outlined"
                                                    />
                                                )}
                                            </Box>
                                        )}
                                    </CardContent>
                                </Card>
                            </Grid>
                        ))}
                    </Grid>
                ) : (
                    <SectionCard noPadding>
                        <EmptyState
                            title="No polls yet"
                            description="Create your first poll for this event or generate one with AI."
                            icon={<PollIcon sx={{ fontSize: 40 }} />}
                            action={
                                <Button
                                    variant="contained"
                                    startIcon={<AddIcon />}
                                    onClick={() => {
                                        setIsAIGeneratedMode(false);
                                        setNewPoll({ question: '', type: 'SINGLE_CHOICE', options: ['', ''], maxRating: 5, closesAt: '' });
                                        setCreateDialog(true);
                                    }}
                                >
                                    Create Poll
                                </Button>
                            }
                        />
                    </SectionCard>
                )
            ) : (
                <SectionCard noPadding>
                    <EmptyState
                        title="Select an event"
                        description="Please select an event above to manage its polls."
                        icon={<PollIcon sx={{ fontSize: 40 }} />}
                    />
                </SectionCard>
            )}

            {/* AI Generation Dialog */}
            <FormDialog
                open={aiDialog}
                onClose={() => setAiDialog(false)}
                title="Generate Poll with AI"
                subtitle="Describe the topic and let AI draft polls for your event."
                icon={<AIIcon />}
                maxWidth="sm"
                actions={
                    <>
                        <Button onClick={() => setAiDialog(false)}>Cancel</Button>
                        <LoadingButton
                            variant="contained"
                            onClick={handleGeneratePollWithAI}
                            loading={aiLoading}
                            startIcon={<AIIcon />}
                        >
                            {aiLoading ? 'Generating...' : 'Generate'}
                        </LoadingButton>
                    </>
                }
            >
                    <TextField
                        autoFocus
                        fullWidth
                        label="Topic or Context"
                        placeholder="e.g., Event satisfaction, Feature preference, Demographics"
                        value={aiRequest.topic}
                        onChange={(e) => setAiRequest({ ...aiRequest, topic: e.target.value })}
                        sx={{ mt: 2, mb: 2 }}
                        helperText="What should the poll be about?"
                    />

                    <FormControl fullWidth sx={{ mb: 2 }}>
                        <InputLabel>Poll Type</InputLabel>
                        <Select
                            value={aiRequest.pollType}
                            label="Poll Type"
                            onChange={(e) => setAiRequest({ ...aiRequest, pollType: e.target.value })}
                        >
                            <MenuItem value="SINGLE_CHOICE">Single Choice</MenuItem>
                            <MenuItem value="MULTIPLE_CHOICE">Multiple Choice</MenuItem>
                            <MenuItem value="RATING">Rating Scale</MenuItem>
                        </Select>
                    </FormControl>

                    {aiRequest.pollType !== 'RATING' && (
                        <TextField
                            fullWidth
                            type="number"
                            label="Number of Options"
                            value={aiRequest.numOptions}
                            onChange={(e) => setAiRequest({ ...aiRequest, numOptions: parseInt(e.target.value) || 4 })}
                            inputProps={{ min: 2, max: 10 }}
                            sx={{ mb: 2 }}
                        />
                    )}

                    <TextField
                        fullWidth
                        type="number"
                        label="Number of Questions to Generate"
                        value={aiRequest.numberOfQuestions}
                        onChange={(e) => setAiRequest({ ...aiRequest, numberOfQuestions: parseInt(e.target.value) || 1 })}
                        inputProps={{ min: 1, max: 5 }}
                        sx={{ mb: 2 }}
                    />

                    <FormControl fullWidth sx={{ mb: 2 }}>
                        <InputLabel>Language</InputLabel>
                        <Select
                            value={aiRequest.language}
                            label="Language"
                            onChange={(e) => setAiRequest({ ...aiRequest, language: e.target.value })}
                        >
                            <MenuItem value="English">English</MenuItem>
                            <MenuItem value="Vietnamese">Tiếng Việt</MenuItem>
                            <MenuItem value="Spanish">Spanish</MenuItem>
                            <MenuItem value="French">French</MenuItem>
                            <MenuItem value="Chinese">Chinese</MenuItem>
                        </Select>
                    </FormControl>

                    <TextField
                        fullWidth
                        multiline
                        rows={3}
                        label="Additional Context (optional)"
                        placeholder="Any specific instructions for the AI?"
                        value={aiRequest.additionalContext}
                        onChange={(e) => setAiRequest({ ...aiRequest, additionalContext: e.target.value })}
                    />
            </FormDialog>

            {/* Create/Edit Poll Dialog */}
            <Dialog
                open={createDialog}
                onClose={() => {
                    setCreateDialog(false);
                    setIsAIGeneratedMode(false);
                    setAiGeneratedPolls([]);
                    setCurrentAIPollIndex(0);
                    setCreatedAIPollIndices(new Set());
                }}
                maxWidth="sm"
                fullWidth
            >
                <DialogTitle>
                    <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                            {isAIGeneratedMode && <AIIcon />}
                            {isAIGeneratedMode ? 'Review AI Generated Poll' : 'Create New Poll'}
                        </Box>
                        {isAIGeneratedMode && (
                            <Chip
                                size="small"
                                label={`${currentAIPollIndex + 1} / ${aiGeneratedPolls.length}`}
                                color="primary"
                            />
                        )}
                    </Box>
                </DialogTitle>
                <DialogContent>
                    {isAIGeneratedMode && (
                        <Paper sx={{ p: 2, mb: 2, bgcolor: 'primary.light', color: 'primary.contrastText' }}>
                            <Typography variant="body2">
                                Review and edit the AI-generated poll below. You can modify the question, options, or type before creating.
                            </Typography>
                        </Paper>
                    )}

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

                    <TextField
                        fullWidth
                        type="datetime-local"
                        label="Schedule open at (optional)"
                        value={newPoll.scheduledOpenAt}
                        onChange={(e) => setNewPoll({ ...newPoll, scheduledOpenAt: e.target.value })}
                        InputLabelProps={{ shrink: true }}
                        sx={{ mt: 2 }}
                        helperText="Poll will be created in SCHEDULED state and auto-open at this time"
                        inputProps={{ min: getMinCloseDate() }}
                    />

                    <TextField
                        fullWidth
                        type="number"
                        label="Auto-close after vote count (optional)"
                        value={newPoll.closeAtVoteCount}
                        onChange={(e) => setNewPoll({ ...newPoll, closeAtVoteCount: e.target.value })}
                        InputLabelProps={{ shrink: true }}
                        sx={{ mt: 2 }}
                        inputProps={{ min: 1 }}
                        helperText="Poll will automatically close when it reaches this number of votes"
                    />

                    <Paper sx={{ p: 2, mt: 2, bgcolor: 'grey.50' }}>
                        <Typography variant="subtitle2" gutterBottom>Advanced Options</Typography>

                        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                            <FormControlLabel
                                control={
                                    <Checkbox
                                        checked={newPoll.autoOpenEventStart}
                                        onChange={(e) => setNewPoll({ ...newPoll, autoOpenEventStart: e.target.checked })}
                                    />
                                }
                                label="Auto-open when event starts"
                            />
                            <FormControlLabel
                                control={
                                    <Checkbox
                                        checked={newPoll.autoCloseEventEnd}
                                        onChange={(e) => {
                                            const checked = e.target.checked;
                                            setNewPoll({
                                                ...newPoll,
                                                autoCloseEventEnd: checked,
                                                // When autoCloseEventEnd is picked, clear autoCloseTenDaysAfterEventEnd
                                                autoCloseTenDaysAfterEventEnd: checked ? false : newPoll.autoCloseTenDaysAfterEventEnd
                                            });
                                        }}
                                    />
                                }
                                label="Auto-close when event ends"
                            />
                            <FormControlLabel
                                control={
                                    <Checkbox
                                        checked={newPoll.autoCloseTenDaysAfterEventEnd}
                                        onChange={(e) => {
                                            const checked = e.target.checked;
                                            setNewPoll({
                                                ...newPoll,
                                                autoCloseTenDaysAfterEventEnd: checked,
                                                // When autoCloseTenDaysAfterEventEnd is picked, clear autoCloseEventEnd
                                                autoCloseEventEnd: checked ? false : newPoll.autoCloseEventEnd,
                                                // Auto-clear closesAt when this option is picked
                                                closesAt: checked ? '' : newPoll.closesAt
                                            });
                                        }}
                                    />
                                }
                                label="Auto-close 10 days after event ends"
                            />
                            <FormControlLabel
                                control={
                                    <Checkbox
                                        checked={newPoll.hideResultsUntilClosed}
                                        onChange={(e) => setNewPoll({ ...newPoll, hideResultsUntilClosed: e.target.checked })}
                                    />
                                }
                                label="Hide results until poll is closed"
                            />
                        </Box>
                    </Paper>
                </DialogContent>
                <DialogActions>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', width: '100%', alignItems: 'center' }}>
                        {isAIGeneratedMode ? (
                            <>
                                <Box>
                                    <Button
                                        onClick={handlePrevAIPoll}
                                        disabled={currentAIPollIndex === 0}
                                        startIcon={<PrevIcon />}
                                    >
                                        Previous
                                    </Button>
                                    <Button
                                        onClick={handleNextAIPoll}
                                        disabled={currentAIPollIndex === aiGeneratedPolls.length - 1}
                                        endIcon={<NextIcon />}
                                    >
                                        Next
                                    </Button>
                                </Box>
                                <Box>
                                    <Button onClick={handleSkipAIPoll} sx={{ mr: 1 }}>
                                        {currentAIPollIndex < aiGeneratedPolls.length - 1 ? 'Skip' : 'Cancel'}
                                    </Button>
                                    <Button variant="contained" onClick={handleCreatePoll}>
                                        {(() => {
                                            const isLast = currentAIPollIndex === aiGeneratedPolls.length - 1;
                                            if (!isLast) return 'Create & Next';
                                            const skippedCount = aiGeneratedPolls.length - createdAIPollIndices.size - 1;
                                            if (skippedCount > 0) return `Create All (${skippedCount + 1})`;
                                            return 'Create Poll';
                                        })()}
                                    </Button>
                                </Box>
                            </>
                        ) : (
                            <>
                                <Button onClick={() => setCreateDialog(false)}>Cancel</Button>
                                <Box sx={{ display: 'flex', gap: 1 }}>
                                    <Button
                                        variant="outlined"
                                        onClick={() => {
                                            setNewPoll({ ...newPoll, draft: true });
                                            setTimeout(handleCreatePoll, 0);
                                        }}
                                    >
                                        Save as Draft
                                    </Button>
                                    <Button variant="contained" onClick={() => {
                                            setNewPoll({ ...newPoll, draft: false });
                                            setTimeout(handleCreatePoll, 0);
                                        }}
                                    >
                                        Create & Publish
                                    </Button>
                                </Box>
                            </>
                        )}
                    </Box>
                </DialogActions>
            </Dialog>

            {/* Edit Poll Dialog */}
            <FormDialog
                open={editDialog}
                onClose={() => setEditDialog(false)}
                title="Edit Poll"
                subtitle="Update poll question, options or auto-close settings."
                icon={<EditIcon />}
                maxWidth="sm"
                actions={
                    <>
                        <Button onClick={() => setEditDialog(false)}>Cancel</Button>
                        <LoadingButton variant="contained" onClick={handleEditPoll}>
                            Save Changes
                        </LoadingButton>
                    </>
                }
            >
                    {editPoll && (
                        <>
                            <TextField
                                autoFocus
                                fullWidth
                                label="Question"
                                value={editPoll.question}
                                onChange={(e) => setEditPoll({ ...editPoll, question: e.target.value })}
                                sx={{ mt: 1, mb: 2 }}
                                multiline
                                rows={2}
                            />

                            <FormControl fullWidth sx={{ mb: 2 }}>
                                <InputLabel>Poll Type</InputLabel>
                                <Select
                                    value={editPoll.type}
                                    label="Poll Type"
                                    onChange={(e) => setEditPoll({ ...editPoll, type: e.target.value })}
                                >
                                    <MenuItem value="SINGLE_CHOICE">Single Choice</MenuItem>
                                    <MenuItem value="MULTIPLE_CHOICE">Multiple Choice</MenuItem>
                                    <MenuItem value="RATING">Rating Scale</MenuItem>
                                </Select>
                            </FormControl>

                            {editPoll.type !== 'RATING' ? (
                                <Box sx={{ mb: 2 }}>
                                    <Typography variant="subtitle2" gutterBottom>Options</Typography>
                                    {editPoll.options?.map((option, index) => (
                                        <Box key={index} sx={{ display: 'flex', gap: 1, mb: 1 }}>
                                            <TextField
                                                fullWidth
                                                size="small"
                                                label={`Option ${index + 1}`}
                                                value={option}
                                                onChange={(e) => updateEditOption(index, e.target.value)}
                                            />
                                            {editPoll.options.length > 2 && (
                                                <Button
                                                    size="small"
                                                    color="error"
                                                    onClick={() => removeEditOption(index)}
                                                >
                                                    Remove
                                                </Button>
                                            )}
                                        </Box>
                                    ))}
                                    {editPoll.options?.length < 10 && (
                                        <Button size="small" onClick={addEditOption}>
                                            + Add Option
                                        </Button>
                                    )}
                                </Box>
                            ) : (
                                <TextField
                                    fullWidth
                                    type="number"
                                    label="Max Rating"
                                    value={editPoll.maxRating || 5}
                                    onChange={(e) => setEditPoll({ ...editPoll, maxRating: parseInt(e.target.value) || 5 })}
                                    inputProps={{ min: 2, max: 10 }}
                                    sx={{ mb: 2 }}
                                />
                            )}

                            <TextField
                                fullWidth
                                type="datetime-local"
                                label="Auto-close at (optional)"
                                value={editPoll.closesAt || ''}
                                onChange={(e) => setEditPoll({ ...editPoll, closesAt: e.target.value })}
                                InputLabelProps={{ shrink: true }}
                                sx={{ mt: 2 }}
                            />
                        </>
                    )}
            </FormDialog>

            {/* Delete Confirmation Dialog */}
            <Dialog open={deleteConfirmDialog} onClose={handleCloseDeleteConfirm} maxWidth="xs" fullWidth>
                <DialogTitle sx={{ color: 'error.main' }}>
                    Delete Poll
                </DialogTitle>
                <DialogContent>
                    <Typography>
                        Are you sure you want to delete this poll? This action cannot be undone.
                    </Typography>
                </DialogContent>
                <DialogActions>
                    <Button onClick={handleCloseDeleteConfirm}>Cancel</Button>
                    <Button variant="contained" color="error" onClick={handleConfirmDelete}>
                        Delete
                    </Button>
                </DialogActions>
            </Dialog>

            {/* Extend Poll Dialog */}
            <Dialog open={extendDialog} onClose={handleCloseExtendDialog} maxWidth="sm" fullWidth>
                <DialogTitle>
                    Extend Poll Time
                </DialogTitle>
                <DialogContent>
                    <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                        Current closing time: {pollToExtend?.closesAt ? new Date(pollToExtend.closesAt).toLocaleString() : 'Not set'}
                    </Typography>

                    <FormControl fullWidth sx={{ mb: 2 }}>
                        <InputLabel>Extension Mode</InputLabel>
                        <Select
                            value={extendMode}
                            label="Extension Mode"
                            onChange={(e) => setExtendMode(e.target.value)}
                        >
                            <MenuItem value="preset">Preset Duration</MenuItem>
                            <MenuItem value="custom">Custom Time</MenuItem>
                        </Select>
                    </FormControl>

                    {extendMode === 'preset' ? (
                        <Box sx={{ display: 'flex', gap: 2 }}>
                            <TextField
                                fullWidth
                                type="number"
                                label="Days"
                                value={extendDays}
                                onChange={(e) => setExtendDays(parseInt(e.target.value) || 0)}
                                inputProps={{ min: 0, max: 30 }}
                            />
                            <TextField
                                fullWidth
                                type="number"
                                label="Hours"
                                value={extendHours}
                                onChange={(e) => setExtendHours(parseInt(e.target.value) || 0)}
                                inputProps={{ min: 0, max: 23 }}
                            />
                        </Box>
                    ) : (
                        <TextField
                            fullWidth
                            type="datetime-local"
                            label="New Closing Time"
                            value={customCloseTime}
                            onChange={(e) => setCustomCloseTime(e.target.value)}
                            InputLabelProps={{ shrink: true }}
                            inputProps={{ min: getMinCloseDate() }}
                        />
                    )}
                </DialogContent>
                <DialogActions>
                    <Button onClick={handleCloseExtendDialog}>Cancel</Button>
                    <Button variant="contained" color="primary" onClick={handleExtendPoll}>
                        Extend
                    </Button>
                </DialogActions>
            </Dialog>

            {/* Schedule Poll Dialog */}
            <Dialog open={scheduleDialog} onClose={handleCloseScheduleDialog} maxWidth="sm" fullWidth>
                <DialogTitle>
                    Schedule Poll Opening
                </DialogTitle>
                <DialogContent>
                    <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                        Poll "{pollToSchedule?.question}" will be automatically opened at the scheduled time.
                    </Typography>
                    <TextField
                        fullWidth
                        type="datetime-local"
                        label="Scheduled Open Time"
                        value={scheduleOpenAt}
                        onChange={(e) => setScheduleOpenAt(e.target.value)}
                        InputLabelProps={{ shrink: true }}
                        inputProps={{ min: getMinCloseDate() }}
                        helperText="Must be in the future"
                    />
                </DialogContent>
                <DialogActions>
                    <Button onClick={handleCloseScheduleDialog}>Cancel</Button>
                    <Button variant="contained" color="primary" onClick={handleSchedulePoll}>
                        Schedule
                    </Button>
                </DialogActions>
            </Dialog>

            {/* Cancel Poll Confirmation Dialog */}
            <Dialog open={cancelConfirmDialog} onClose={handleCloseCancelDialog} maxWidth="xs" fullWidth>
                <DialogTitle sx={{ color: 'error.main' }}>
                    Cancel Poll
                </DialogTitle>
                <DialogContent>
                    <Typography>
                        Are you sure you want to cancel poll "{pollToCancel?.question}"?
                    </Typography>
                    <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                        This action cannot be undone. The poll will be permanently cancelled.
                    </Typography>
                </DialogContent>
                <DialogActions>
                    <Button onClick={handleCloseCancelDialog}>Keep Poll</Button>
                    <Button variant="contained" color="error" onClick={handleCancelPoll}>
                        Cancel Poll
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default OrganiserPolls;

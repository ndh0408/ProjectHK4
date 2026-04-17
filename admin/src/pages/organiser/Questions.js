import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Typography,
    Autocomplete,
    Card,
    CardContent,
    TextField,
    Avatar,
    IconButton,
    Tabs,
    Tab,
    FormControl,
    InputLabel,
    Select,
    MenuItem,
    Grid,
    Button,
} from '@mui/material';
import {
    Refresh as RefreshIcon,
    Send as SendIcon,
    QuestionAnswer as QuestionIcon,
    AutoAwesome as AIIcon,
    Delete as DeleteIcon,
    CheckCircle as AnsweredIcon,
    HelpOutline as UnansweredIcon,
} from '@mui/icons-material';
import { organiserApi } from '../../api';
import { LoadingSpinner, ConfirmDialog } from '../../components/common';
import {
    PageHeader,
    SectionCard,
    StatCard,
    StatusChip,
    EmptyState,
    LoadingButton,
} from '../../components/ui';
import { tokens } from '../../theme';
import { toast } from 'react-toastify';

const OrganiserQuestions = () => {
    const [events, setEvents] = useState([]);
    const [selectedEvent, setSelectedEvent] = useState('all');
    const [questions, setQuestions] = useState([]);
    const [loading, setLoading] = useState(false);
    const [paginationModel, setPaginationModel] = useState({ page: 0, pageSize: 20 });
    // eslint-disable-next-line no-unused-vars
    const [totalRows, setTotalRows] = useState(0);
    const [answers, setAnswers] = useState({});
    const [aiLoading, setAiLoading] = useState({});
    const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
    const [questionToDelete, setQuestionToDelete] = useState(null);
    const [activeTab, setActiveTab] = useState(0);
    const [stats, setStats] = useState({ total: 0, unanswered: 0, answered: 0 });
    const [sortBy, setSortBy] = useState('newest');

    useEffect(() => {
        loadEvents();
        loadStats();
    }, []);

    const loadEvents = async () => {
        try {
            const response = await organiserApi.getMyEvents({ page: 0, size: 100 });
            setEvents(response.data.data.content || []);
        } catch (error) {
            console.error('Failed to load events:', error);
        }
    };

    const loadStats = async () => {
        try {
            const response = await organiserApi.getQuestionStats();
            setStats(response.data.data);
        } catch (error) {
            console.error('Failed to load stats:', error);
        }
    };

    const loadQuestions = useCallback(async () => {
        setLoading(true);
        try {
            let response;
            const params = {
                page: paginationModel.page,
                size: paginationModel.pageSize,
                sort: sortBy === 'newest' ? 'createdAt,desc' : sortBy === 'oldest' ? 'createdAt,asc' : 'createdAt,desc',
            };

            if (selectedEvent === 'all') {
                if (activeTab === 0) {
                    response = await organiserApi.getAllQuestions(params);
                } else if (activeTab === 1) {
                    response = await organiserApi.getUnansweredQuestions(params);
                } else {
                    response = await organiserApi.getAnsweredQuestions(params);
                }
            } else {
                response = await organiserApi.getEventQuestions(selectedEvent, params);
            }

            let questionsData = response.data.data.content || [];

            if (selectedEvent !== 'all' && activeTab === 1) {
                questionsData = questionsData.filter(q => !q.answer);
            } else if (selectedEvent !== 'all' && activeTab === 2) {
                questionsData = questionsData.filter(q => q.answer);
            }

            if (sortBy === 'unanswered') {
                questionsData = [...questionsData].sort((a, b) => {
                    if (!a.answer && b.answer) return -1;
                    if (a.answer && !b.answer) return 1;
                    return new Date(b.createdAt) - new Date(a.createdAt);
                });
            }

            setQuestions(questionsData);
            setTotalRows(response.data.data.totalElements || 0);
        } catch (error) {
            toast.error('Failed to load questions');
        } finally {
            setLoading(false);
        }
    }, [selectedEvent, paginationModel, activeTab, sortBy]);

    useEffect(() => {
        loadQuestions();
    }, [loadQuestions]);

    const handleAnswerChange = (questionId, value) => {
        setAnswers({ ...answers, [questionId]: value });
    };

    const [answerErrors, setAnswerErrors] = useState({});
    const [submittingAnswer, setSubmittingAnswer] = useState({});

    const validateAnswer = (questionId, answer) => {
        const errors = {};

        if (!answer?.trim()) {
            errors[questionId] = 'Answer is required';
        } else if (answer.trim().length < 10) {
            errors[questionId] = 'Answer must be at least 10 characters';
        } else if (answer.trim().length > 1000) {
            errors[questionId] = 'Answer must be less than 1000 characters';
        }

        setAnswerErrors({ ...answerErrors, ...errors });
        return Object.keys(errors).length === 0;
    };

    const handleSubmitAnswer = async (questionId) => {
        const answer = answers[questionId];

        if (!validateAnswer(questionId, answer)) {
            return;
        }

        setSubmittingAnswer({ ...submittingAnswer, [questionId]: true });
        try {
            await organiserApi.answerQuestion(questionId, answer);
            toast.success('Answer submitted successfully');
            setAnswers({ ...answers, [questionId]: '' });
            setAnswerErrors({ ...answerErrors, [questionId]: '' });
            loadQuestions();
            loadStats();
        } catch (error) {
            toast.error('Failed to submit answer');
        } finally {
            setSubmittingAnswer({ ...submittingAnswer, [questionId]: false });
        }
    };

    const handleAISuggest = async (questionId) => {
        setAiLoading({ ...aiLoading, [questionId]: true });
        try {
            const response = await organiserApi.getAISuggestion(questionId);
            const suggestion = response.data.data.suggestedAnswer;
            setAnswers({ ...answers, [questionId]: suggestion });
            toast.success('AI suggestion generated!');
        } catch (error) {
            console.error('AI Suggest Error:', error);
            const errorMsg = error.response?.data?.message || 'Failed to generate AI suggestion';
            toast.error(errorMsg);
        } finally {
            setAiLoading({ ...aiLoading, [questionId]: false });
        }
    };

    const handleDeleteClick = (question) => {
        setQuestionToDelete(question);
        setDeleteDialogOpen(true);
    };

    const handleDeleteConfirm = async () => {
        if (!questionToDelete) return;

        try {
            await organiserApi.deleteQuestion(questionToDelete.id);
            toast.success('Question deleted successfully');
            setDeleteDialogOpen(false);
            setQuestionToDelete(null);
            loadQuestions();
            loadStats();
        } catch (error) {
            toast.error('Failed to delete question');
        }
    };

    const handleDeleteCancel = () => {
        setDeleteDialogOpen(false);
        setQuestionToDelete(null);
    };

    const handleTabChange = (event, newValue) => {
        setActiveTab(newValue);
        setPaginationModel({ ...paginationModel, page: 0 });
    };

    const handleRefresh = () => {
        loadQuestions();
        loadStats();
    };

    return (
        <Box>
            <PageHeader
                title="Questions"
                subtitle="Answer attendee questions across your events"
                icon={<QuestionIcon />}
                actions={[
                    <Button
                        key="refresh"
                        variant="outlined"
                        startIcon={<RefreshIcon />}
                        onClick={handleRefresh}
                    >
                        Refresh
                    </Button>,
                ]}
            />

            <Grid container spacing={2} sx={{ mb: 3 }}>
                <Grid item xs={12} sm={4}>
                    <StatCard
                        label="Total Questions"
                        value={stats.total}
                        icon={<QuestionIcon />}
                        iconColor="primary"
                    />
                </Grid>
                <Grid item xs={12} sm={4}>
                    <StatCard
                        label="Unanswered"
                        value={stats.unanswered}
                        icon={<UnansweredIcon />}
                        iconColor="warning"
                    />
                </Grid>
                <Grid item xs={12} sm={4}>
                    <StatCard
                        label="Answered"
                        value={stats.answered}
                        icon={<AnsweredIcon />}
                        iconColor="success"
                    />
                </Grid>
            </Grid>

            <SectionCard
                contentSx={{ p: 0, '&:last-child': { pb: 0 } }}
                sx={{ mb: 2 }}
            >
                <Box sx={{ borderBottom: `1px solid ${tokens.palette.neutral[200]}` }}>
                    <Tabs value={activeTab} onChange={handleTabChange} sx={{ px: 2 }}>
                        <Tab
                            icon={<QuestionIcon />}
                            iconPosition="start"
                            label={`All (${stats.total})`}
                        />
                        <Tab
                            icon={<UnansweredIcon />}
                            iconPosition="start"
                            label={`Unanswered (${stats.unanswered})`}
                            sx={{ color: stats.unanswered > 0 ? tokens.palette.warning[600] : 'inherit' }}
                        />
                        <Tab
                            icon={<AnsweredIcon />}
                            iconPosition="start"
                            label={`Answered (${stats.answered})`}
                        />
                    </Tabs>
                </Box>
                <Box sx={{ p: 2, display: 'flex', gap: 2, alignItems: 'center', flexWrap: 'wrap' }}>
                    <Autocomplete
                        options={[{ id: 'all', title: 'All Events' }, ...events]}
                        getOptionLabel={(option) => option.title || ''}
                        value={selectedEvent === 'all'
                            ? { id: 'all', title: 'All Events' }
                            : events.find(e => e.id === selectedEvent) || null}
                        onChange={(_, newValue) => {
                            setSelectedEvent(newValue?.id || 'all');
                            setPaginationModel({ ...paginationModel, page: 0 });
                        }}
                        renderInput={(params) => (
                            <TextField {...params} label="Filter by Event" placeholder="Select event..." size="small" />
                        )}
                        renderOption={(props, option) => (
                            <li {...props} key={option.id}>
                                <Box sx={{ width: '100%' }}>
                                    <Typography variant="body1" noWrap>{option.title}</Typography>
                                    {option.startTime && (
                                        <Typography variant="caption" color="text.secondary">
                                            {new Date(option.startTime).toLocaleDateString()}
                                        </Typography>
                                    )}
                                </Box>
                            </li>
                        )}
                        isOptionEqualToValue={(option, value) => option.id === value.id}
                        sx={{ minWidth: 350 }}
                        noOptionsText="No events found"
                    />
                    <FormControl size="small" sx={{ minWidth: 180 }}>
                        <InputLabel>Sort by</InputLabel>
                        <Select
                            value={sortBy}
                            label="Sort by"
                            onChange={(e) => setSortBy(e.target.value)}
                        >
                            <MenuItem value="newest">Newest first</MenuItem>
                            <MenuItem value="oldest">Oldest first</MenuItem>
                            <MenuItem value="unanswered">Unanswered first</MenuItem>
                        </Select>
                    </FormControl>
                </Box>
            </SectionCard>

            {loading ? (
                <LoadingSpinner message="Loading questions..." />
            ) : questions.length === 0 ? (
                <SectionCard>
                    <EmptyState
                        icon={<QuestionIcon sx={{ fontSize: 32 }} />}
                        title={
                            activeTab === 1 ? 'No unanswered questions' :
                            activeTab === 2 ? 'No answered questions yet' :
                            'No questions yet'
                        }
                        description="Questions from attendees will appear here as they come in."
                    />
                </SectionCard>
            ) : (
                <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2.5 }}>
                    {questions.map((question) => {
                        const answerValue = answers[question.id] || '';
                        const answerLength = answerValue.length;
                        const isAnswered = Boolean(question.answer);
                        return (
                            <Card
                                key={question.id}
                                sx={{
                                    borderLeft: `4px solid ${isAnswered
                                        ? tokens.palette.success[500]
                                        : tokens.palette.warning[500]}`,
                                    transition: 'box-shadow 200ms ease, transform 200ms ease',
                                    '&:hover': {
                                        boxShadow: tokens.shadow.md,
                                    },
                                }}
                            >
                                <CardContent sx={{ p: { xs: 2.5, md: 3 } }}>
                                    {/* ─── Header row: avatar + name + status + date ─── */}
                                    <Box sx={{ display: 'flex', gap: 2, alignItems: 'flex-start', mb: 2 }}>
                                        <Avatar
                                            src={question.userAvatarUrl}
                                            sx={{
                                                bgcolor: tokens.palette.primary[500],
                                                width: 48,
                                                height: 48,
                                                fontSize: '1rem',
                                                fontWeight: 600,
                                                flexShrink: 0,
                                            }}
                                        >
                                            {question.userName?.charAt(0)?.toUpperCase()}
                                        </Avatar>
                                        <Box sx={{ flex: 1, minWidth: 0 }}>
                                            <Box
                                                sx={{
                                                    display: 'flex',
                                                    justifyContent: 'space-between',
                                                    alignItems: 'flex-start',
                                                    gap: 1.5,
                                                    flexWrap: 'wrap',
                                                }}
                                            >
                                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, flexWrap: 'wrap', minWidth: 0 }}>
                                                    <Typography
                                                        sx={{
                                                            fontSize: '1.0625rem',
                                                            fontWeight: 700,
                                                            color: 'text.primary',
                                                            lineHeight: 1.3,
                                                            letterSpacing: '-0.01em',
                                                        }}
                                                    >
                                                        {question.userName}
                                                    </Typography>
                                                    <StatusChip
                                                        label={isAnswered ? 'Answered' : 'Pending'}
                                                        status={isAnswered ? 'success' : 'warning'}
                                                    />
                                                </Box>
                                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, flexShrink: 0 }}>
                                                    <Typography
                                                        variant="caption"
                                                        color="text.secondary"
                                                        sx={{
                                                            fontVariantNumeric: 'tabular-nums',
                                                            fontSize: '0.8125rem',
                                                        }}
                                                    >
                                                        {new Date(question.createdAt).toLocaleString()}
                                                    </Typography>
                                                    <IconButton
                                                        size="small"
                                                        color="error"
                                                        onClick={() => handleDeleteClick(question)}
                                                        aria-label="Delete question"
                                                    >
                                                        <DeleteIcon fontSize="small" />
                                                    </IconButton>
                                                </Box>
                                            </Box>
                                            {selectedEvent === 'all' && question.eventTitle && (
                                                <Box
                                                    sx={{
                                                        display: 'inline-flex',
                                                        alignItems: 'center',
                                                        gap: 0.75,
                                                        mt: 0.75,
                                                        px: 1.25,
                                                        py: 0.375,
                                                        borderRadius: tokens.radius.pill,
                                                        bgcolor: 'primary.50',
                                                        border: `1px solid ${tokens.palette.primary[100]}`,
                                                    }}
                                                >
                                                    <Typography
                                                        sx={{
                                                            fontSize: '0.75rem',
                                                            fontWeight: 600,
                                                            color: 'primary.700',
                                                            textTransform: 'uppercase',
                                                            letterSpacing: '0.04em',
                                                        }}
                                                    >
                                                        Event
                                                    </Typography>
                                                    <Typography
                                                        sx={{
                                                            fontSize: '0.8125rem',
                                                            fontWeight: 500,
                                                            color: 'primary.800',
                                                        }}
                                                    >
                                                        {question.eventTitle}
                                                    </Typography>
                                                </Box>
                                            )}
                                        </Box>
                                    </Box>

                                    {/* ─── Question body (prominent) ─── */}
                                    <Box
                                        sx={{
                                            ml: { xs: 0, sm: 8 },
                                            mb: 2.5,
                                            pl: 2,
                                            borderLeft: `3px solid ${tokens.palette.neutral[200]}`,
                                        }}
                                    >
                                        <Typography
                                            sx={{
                                                fontSize: '1rem',
                                                lineHeight: 1.6,
                                                color: 'text.primary',
                                                fontWeight: 500,
                                                whiteSpace: 'pre-wrap',
                                                wordBreak: 'break-word',
                                            }}
                                        >
                                            {question.question}
                                        </Typography>
                                    </Box>

                                    {/* ─── Answer section ─── */}
                                    {isAnswered ? (
                                        <Box
                                            sx={{
                                                bgcolor: tokens.palette.success[50],
                                                border: `1px solid ${tokens.palette.success[100]}`,
                                                p: 2.25,
                                                borderRadius: 2,
                                                ml: { xs: 0, sm: 8 },
                                            }}
                                        >
                                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                                                <AnsweredIcon
                                                    sx={{
                                                        fontSize: 18,
                                                        color: tokens.palette.success[600],
                                                    }}
                                                />
                                                <Typography
                                                    sx={{
                                                        fontSize: '0.75rem',
                                                        color: tokens.palette.success[700],
                                                        fontWeight: 700,
                                                        letterSpacing: '0.06em',
                                                        textTransform: 'uppercase',
                                                    }}
                                                >
                                                    Your answer
                                                </Typography>
                                            </Box>
                                            <Typography
                                                sx={{
                                                    fontSize: '0.9375rem',
                                                    lineHeight: 1.6,
                                                    color: 'text.primary',
                                                    whiteSpace: 'pre-wrap',
                                                    wordBreak: 'break-word',
                                                }}
                                            >
                                                {question.answer}
                                            </Typography>
                                            <Typography
                                                variant="caption"
                                                color="text.secondary"
                                                sx={{ display: 'block', mt: 1.25, fontSize: '0.75rem' }}
                                            >
                                                Answered on {new Date(question.answeredAt).toLocaleString()}
                                            </Typography>
                                        </Box>
                                    ) : (
                                        <Box sx={{ ml: { xs: 0, sm: 8 } }}>
                                            <TextField
                                                fullWidth
                                                placeholder="Type your answer (minimum 10 characters)..."
                                                value={answerValue}
                                                onChange={(e) => {
                                                    handleAnswerChange(question.id, e.target.value);
                                                    if (answerErrors[question.id]) {
                                                        setAnswerErrors({ ...answerErrors, [question.id]: '' });
                                                    }
                                                }}
                                                multiline
                                                minRows={3}
                                                maxRows={8}
                                                error={!!answerErrors[question.id]}
                                                helperText={answerErrors[question.id] || ' '}
                                                inputProps={{ maxLength: 1000 }}
                                                sx={{
                                                    '& .MuiInputBase-input': {
                                                        fontSize: '0.9375rem',
                                                        lineHeight: 1.55,
                                                    },
                                                }}
                                            />
                                            <Box
                                                sx={{
                                                    display: 'flex',
                                                    justifyContent: 'space-between',
                                                    alignItems: 'center',
                                                    gap: 1.5,
                                                    flexWrap: { xs: 'wrap', sm: 'nowrap' },
                                                    mt: 0.5,
                                                }}
                                            >
                                                <Typography
                                                    variant="caption"
                                                    color="text.secondary"
                                                    sx={{
                                                        fontVariantNumeric: 'tabular-nums',
                                                        fontSize: '0.8125rem',
                                                    }}
                                                >
                                                    {answerLength}/1000 characters
                                                </Typography>
                                                <Box
                                                    sx={{
                                                        display: 'flex',
                                                        gap: 1,
                                                        width: { xs: '100%', sm: 'auto' },
                                                        '& > *': {
                                                            flex: { xs: 1, sm: 'initial' },
                                                            minWidth: { sm: 140 },
                                                            height: 42,
                                                            fontSize: '0.875rem',
                                                            fontWeight: 600,
                                                        },
                                                    }}
                                                >
                                                    <LoadingButton
                                                        variant="outlined"
                                                        color="secondary"
                                                        onClick={() => handleAISuggest(question.id)}
                                                        loading={aiLoading[question.id]}
                                                        startIcon={<AIIcon sx={{ fontSize: 18 }} />}
                                                    >
                                                        AI Suggest
                                                    </LoadingButton>
                                                    <LoadingButton
                                                        variant="contained"
                                                        onClick={() => handleSubmitAnswer(question.id)}
                                                        loading={submittingAnswer[question.id]}
                                                        startIcon={<SendIcon sx={{ fontSize: 18 }} />}
                                                    >
                                                        Send
                                                    </LoadingButton>
                                                </Box>
                                            </Box>
                                        </Box>
                                    )}
                                </CardContent>
                            </Card>
                        );
                    })}
                </Box>
            )}

            <ConfirmDialog
                open={deleteDialogOpen}
                onCancel={handleDeleteCancel}
                onConfirm={handleDeleteConfirm}
                title="Delete Question"
                message={
                    questionToDelete
                        ? `Are you sure you want to delete this question from ${questionToDelete.userName}? "${questionToDelete.question}" — this action cannot be undone.`
                        : 'Are you sure you want to delete this question? This action cannot be undone.'
                }
                confirmText="Delete"
                cancelText="Cancel"
                confirmColor="error"
            />
        </Box>
    );
};

export default OrganiserQuestions;

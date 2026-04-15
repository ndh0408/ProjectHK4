import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Typography,
    Paper,
    Autocomplete,
    Button,
    Chip,
    Card,
    CardContent,
    TextField,
    Avatar,
    Divider,
    IconButton,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogContentText,
    DialogActions,
    Tabs,
    Tab,
    FormControl,
    InputLabel,
    Select,
    MenuItem,
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
import { LoadingSpinner } from '../../components/common';
import { toast } from 'react-toastify';

const OrganiserQuestions = () => {
    const [events, setEvents] = useState([]);
    const [selectedEvent, setSelectedEvent] = useState('all');
    const [questions, setQuestions] = useState([]);
    const [loading, setLoading] = useState(false);
    const [paginationModel, setPaginationModel] = useState({ page: 0, pageSize: 20 });
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

        try {
            await organiserApi.answerQuestion(questionId, answer);
            toast.success('Answer submitted successfully');
            setAnswers({ ...answers, [questionId]: '' });
            setAnswerErrors({ ...answerErrors, [questionId]: '' });
            loadQuestions();
            loadStats();
        } catch (error) {
            toast.error('Failed to submit answer');
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
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                <Typography variant="h5" fontWeight="bold">
                    Questions
                </Typography>
                <Button startIcon={<RefreshIcon />} onClick={handleRefresh}>
                    Refresh
                </Button>
            </Box>

            <Box sx={{ display: 'flex', gap: 2, mb: 3 }}>
                <Paper sx={{ p: 2, flex: 1, textAlign: 'center' }}>
                    <Typography variant="h4" fontWeight="bold" color="primary">
                        {stats.total}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                        Total Questions
                    </Typography>
                </Paper>
                <Paper sx={{ p: 2, flex: 1, textAlign: 'center' }}>
                    <Typography variant="h4" fontWeight="bold" color="warning.main">
                        {stats.unanswered}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                        Unanswered
                    </Typography>
                </Paper>
                <Paper sx={{ p: 2, flex: 1, textAlign: 'center' }}>
                    <Typography variant="h4" fontWeight="bold" color="success.main">
                        {stats.answered}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                        Answered
                    </Typography>
                </Paper>
            </Box>

            <Paper sx={{ mb: 2 }}>
                <Box sx={{ borderBottom: 1, borderColor: 'divider' }}>
                    <Tabs value={activeTab} onChange={handleTabChange}>
                        <Tab
                            icon={<QuestionIcon />}
                            iconPosition="start"
                            label={`All (${stats.total})`}
                        />
                        <Tab
                            icon={<UnansweredIcon />}
                            iconPosition="start"
                            label={`Unanswered (${stats.unanswered})`}
                            sx={{ color: stats.unanswered > 0 ? 'warning.main' : 'inherit' }}
                        />
                        <Tab
                            icon={<AnsweredIcon />}
                            iconPosition="start"
                            label={`Answered (${stats.answered})`}
                        />
                    </Tabs>
                </Box>
                <Box sx={{ p: 2, display: 'flex', gap: 2, alignItems: 'center' }}>
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
                    <FormControl size="small" sx={{ minWidth: 150 }}>
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
            </Paper>

            {loading ? (
                <LoadingSpinner message="Loading questions..." />
            ) : questions.length === 0 ? (
                <Paper sx={{ p: 4, textAlign: 'center' }}>
                    <QuestionIcon sx={{ fontSize: 60, color: 'text.secondary', mb: 2 }} />
                    <Typography color="text.secondary">
                        {activeTab === 1 ? 'No unanswered questions' :
                         activeTab === 2 ? 'No answered questions yet' :
                         'No questions yet'}
                    </Typography>
                </Paper>
            ) : (
                <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                    {questions.map((question) => (
                        <Card key={question.id}>
                            <CardContent>
                                <Box sx={{ display: 'flex', gap: 2, mb: 2 }}>
                                    <Avatar src={question.userAvatarUrl}>
                                        {question.userName?.charAt(0)}
                                    </Avatar>
                                    <Box sx={{ flex: 1 }}>
                                        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                                <Typography fontWeight="bold">
                                                    {question.userName}
                                                </Typography>
                                                {question.answer ? (
                                                    <Chip size="small" label="Answered" color="success" />
                                                ) : (
                                                    <Chip size="small" label="Pending" color="warning" />
                                                )}
                                            </Box>
                                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                                <Typography variant="caption" color="text.secondary">
                                                    {new Date(question.createdAt).toLocaleString()}
                                                </Typography>
                                                <IconButton
                                                    size="small"
                                                    color="error"
                                                    onClick={() => handleDeleteClick(question)}
                                                    title="Delete question"
                                                >
                                                    <DeleteIcon fontSize="small" />
                                                </IconButton>
                                            </Box>
                                        </Box>
                                        {selectedEvent === 'all' && question.eventTitle && (
                                            <Typography variant="caption" color="primary" sx={{ display: 'block', mb: 0.5 }}>
                                                Event: {question.eventTitle}
                                            </Typography>
                                        )}
                                        <Typography sx={{ mt: 1 }}>
                                            {question.question}
                                        </Typography>
                                    </Box>
                                </Box>

                                {question.answer ? (
                                    <>
                                        <Divider sx={{ my: 2 }} />
                                        <Box sx={{ bgcolor: 'grey.50', p: 2, borderRadius: 1 }}>
                                            <Typography variant="caption" color="text.secondary">
                                                Your answer:
                                            </Typography>
                                            <Typography sx={{ mt: 0.5 }}>
                                                {question.answer}
                                            </Typography>
                                            <Typography variant="caption" color="text.secondary">
                                                Answered on {new Date(question.answeredAt).toLocaleString()}
                                            </Typography>
                                        </Box>
                                    </>
                                ) : (
                                    <>
                                        <Divider sx={{ my: 2 }} />
                                        <Box sx={{ display: 'flex', gap: 1, flexDirection: 'column' }}>
                                            <Box sx={{ display: 'flex', gap: 1, alignItems: 'flex-start' }}>
                                                <TextField
                                                    fullWidth
                                                    placeholder="Type your answer (min 10 characters)..."
                                                    value={answers[question.id] || ''}
                                                    onChange={(e) => {
                                                        handleAnswerChange(question.id, e.target.value);
                                                        if (answerErrors[question.id]) {
                                                            setAnswerErrors({ ...answerErrors, [question.id]: '' });
                                                        }
                                                    }}
                                                    size="small"
                                                    multiline
                                                    rows={2}
                                                    error={!!answerErrors[question.id]}
                                                />
                                                <Button
                                                    variant="outlined"
                                                    color="secondary"
                                                    onClick={() => handleAISuggest(question.id)}
                                                    disabled={aiLoading[question.id]}
                                                    sx={{ minWidth: 120 }}
                                                    startIcon={<AIIcon />}
                                                >
                                                    {aiLoading[question.id] ? 'Loading...' : 'AI Suggest'}
                                                </Button>
                                                <Button
                                                    variant="contained"
                                                    onClick={() => handleSubmitAnswer(question.id)}
                                                    sx={{ minWidth: 100 }}
                                                >
                                                    <SendIcon />
                                                </Button>
                                            </Box>
                                            {answerErrors[question.id] && (
                                                <Typography variant="caption" color="error">
                                                    {answerErrors[question.id]}
                                                </Typography>
                                            )}
                                            <Typography variant="caption" color="text.secondary">
                                                {(answers[question.id] || '').length}/1000 characters
                                            </Typography>
                                        </Box>
                                    </>
                                )}
                            </CardContent>
                        </Card>
                    ))}
                </Box>
            )}

            <Dialog open={deleteDialogOpen} onClose={handleDeleteCancel}>
                <DialogTitle>Delete Question</DialogTitle>
                <DialogContent>
                    <DialogContentText>
                        Are you sure you want to delete this question? This action cannot be undone.
                    </DialogContentText>
                    {questionToDelete && (
                        <Box sx={{ mt: 2, p: 2, bgcolor: 'grey.100', borderRadius: 1 }}>
                            <Typography variant="body2" color="text.secondary">
                                Question from {questionToDelete.userName}:
                            </Typography>
                            <Typography variant="body1" sx={{ mt: 1 }}>
                                "{questionToDelete.question}"
                            </Typography>
                        </Box>
                    )}
                </DialogContent>
                <DialogActions>
                    <Button onClick={handleDeleteCancel}>Cancel</Button>
                    <Button onClick={handleDeleteConfirm} color="error" variant="contained">
                        Delete
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default OrganiserQuestions;

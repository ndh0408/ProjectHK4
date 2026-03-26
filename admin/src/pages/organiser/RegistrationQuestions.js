import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Typography,
    Paper,
    Autocomplete,
    FormControl,
    InputLabel,
    Select,
    MenuItem,
    Button,
    IconButton,
    TextField,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    List,
    ListItem,
    ListItemText,
    ListItemSecondaryAction,
    Chip,
    Switch,
    FormControlLabel,
    Alert,
    Tooltip,
    Slider,
} from '@mui/material';
import {
    Add as AddIcon,
    Edit as EditIcon,
    Delete as DeleteIcon,
    DragIndicator as DragIcon,
    AutoAwesome as AIIcon,
} from '@mui/icons-material';
import { DragDropContext, Droppable, Draggable } from '@hello-pangea/dnd';
import { organiserApi } from '../../api';
import { ConfirmDialog } from '../../components/common';
import { toast } from 'react-toastify';

const questionTypes = [
    { value: 'TEXT', label: 'Short Text', description: 'Single line text input' },
    { value: 'TEXTAREA', label: 'Long Text', description: 'Multi-line text input' },
    { value: 'SINGLE_CHOICE', label: 'Single Choice', description: 'Radio buttons - select one' },
    { value: 'MULTIPLE_CHOICE', label: 'Multiple Choice', description: 'Checkboxes - select multiple' },
];

const RegistrationQuestions = () => {
    const [events, setEvents] = useState([]);
    const [selectedEvent, setSelectedEvent] = useState('');
    const [questions, setQuestions] = useState([]);
    const [loading, setLoading] = useState(false);
    const [dialogOpen, setDialogOpen] = useState(false);
    const [editingQuestion, setEditingQuestion] = useState(null);
    const [confirmDialog, setConfirmDialog] = useState({ open: false, title: '', message: '', action: null });

    const [aiDialogOpen, setAiDialogOpen] = useState(false);
    const [aiLoading, setAiLoading] = useState(false);
    const [numberOfQuestions, setNumberOfQuestions] = useState(3);
    const [suggestedQuestions, setSuggestedQuestions] = useState([]);
    const [selectedSuggestions, setSelectedSuggestions] = useState([]);

    const [formData, setFormData] = useState({
        questionText: '',
        questionType: 'TEXT',
        options: [''],
        required: true,
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

    const loadQuestions = useCallback(async () => {
        if (!selectedEvent) return;

        setLoading(true);
        try {
            const response = await organiserApi.getRegistrationQuestions(selectedEvent);
            setQuestions(response.data.data || []);
        } catch (error) {
            toast.error('Failed to load questions');
        } finally {
            setLoading(false);
        }
    }, [selectedEvent]);

    useEffect(() => {
        loadQuestions();
    }, [loadQuestions]);

    const saveAllQuestions = async (updatedQuestions) => {
        if (!selectedEvent) return;

        setLoading(true);
        try {
            const questionsWithOrder = updatedQuestions.map((q, index) => ({
                questionText: q.questionText,
                questionType: q.questionType,
                options: q.options || null,
                required: q.required,
                displayOrder: index,
            }));
            await organiserApi.saveRegistrationQuestions(selectedEvent, questionsWithOrder);
            toast.success('Questions saved successfully');
            loadQuestions();
        } catch (error) {
            toast.error('Failed to save questions');
            loadQuestions(); // Reload to revert local state on failure
        } finally {
            setLoading(false);
        }
    };

    const handleAddQuestion = () => {
        setEditingQuestion(null);
        setFormData({
            questionText: '',
            questionType: 'TEXT',
            options: [''],
            required: true,
        });
        setDialogOpen(true);
    };

    const handleEditQuestion = (question, index) => {
        setEditingQuestion(index);
        setFormData({
            questionText: question.questionText,
            questionType: question.questionType,
            options: question.options?.length > 0 ? question.options : [''],
            required: question.required,
        });
        setDialogOpen(true);
    };

    const handleDeleteQuestion = (index) => {
        setConfirmDialog({
            open: true,
            title: 'Delete Question',
            message: 'Are you sure you want to delete this question?',
            confirmColor: 'error',
            action: () => {
                const newQuestions = [...questions];
                newQuestions.splice(index, 1);
                setQuestions(newQuestions);
                saveAllQuestions(newQuestions);
            },
        });
    };

    const handleSaveQuestion = () => {
        if (!formData.questionText.trim()) {
            toast.error('Question text is required');
            return;
        }

        if ((formData.questionType === 'SINGLE_CHOICE' || formData.questionType === 'MULTIPLE_CHOICE') &&
            formData.options.filter(o => o.trim()).length < 2) {
            toast.error('Please add at least 2 options for choice questions');
            return;
        }

        const questionData = {
            questionText: formData.questionText,
            questionType: formData.questionType,
            options: formData.questionType === 'SINGLE_CHOICE' || formData.questionType === 'MULTIPLE_CHOICE'
                ? formData.options.filter(o => o.trim())
                : null,
            required: formData.required,
        };

        let updatedQuestions;
        if (editingQuestion !== null) {
            updatedQuestions = [...questions];
            updatedQuestions[editingQuestion] = { ...updatedQuestions[editingQuestion], ...questionData };
        } else {
            updatedQuestions = [...questions, questionData];
        }

        setQuestions(updatedQuestions);
        setDialogOpen(false);
        saveAllQuestions(updatedQuestions);
    };

    const handleDragEnd = (result) => {
        if (!result.destination) return;

        const items = Array.from(questions);
        const [reorderedItem] = items.splice(result.source.index, 1);
        items.splice(result.destination.index, 0, reorderedItem);

        setQuestions(items);
        saveAllQuestions(items);
    };

    const handleOptionChange = (index, value) => {
        const newOptions = [...formData.options];
        newOptions[index] = value;
        setFormData({ ...formData, options: newOptions });
    };

    const handleAddOption = () => {
        setFormData({ ...formData, options: [...formData.options, ''] });
    };

    const handleRemoveOption = (index) => {
        const newOptions = formData.options.filter((_, i) => i !== index);
        setFormData({ ...formData, options: newOptions });
    };

    const handleOpenAiDialog = () => {
        setSuggestedQuestions([]);
        setSelectedSuggestions([]);
        setNumberOfQuestions(3);
        setAiDialogOpen(true);
    };

    const handleGenerateAiQuestions = async () => {
        const eventData = events.find(e => e.id === selectedEvent);
        if (!eventData) {
            toast.error('Event not found');
            return;
        }

        setAiLoading(true);
        try {
            const response = await organiserApi.suggestRegistrationQuestions({
                eventTitle: eventData.title,
                eventCategory: eventData.categoryName || '',
                eventDescription: eventData.description || '',
                numberOfQuestions: numberOfQuestions,
            });
            const questions = response.data.data.questions || [];
            setSuggestedQuestions(questions);
            setSelectedSuggestions(questions.map((_, index) => index)); // Select all by default
            toast.success(`${questions.length} questions suggested!`);
        } catch (error) {
            toast.error(error.response?.data?.message || 'Failed to generate questions');
        } finally {
            setAiLoading(false);
        }
    };

    const handleToggleSuggestion = (index) => {
        setSelectedSuggestions(prev => {
            if (prev.includes(index)) {
                return prev.filter(i => i !== index);
            } else {
                return [...prev, index];
            }
        });
    };

    const handleAddSuggestedQuestions = () => {
        if (selectedSuggestions.length === 0) {
            toast.error('Please select at least one question');
            return;
        }

        const newQuestions = selectedSuggestions.map(index => suggestedQuestions[index]);
        const updatedQuestions = [...questions, ...newQuestions];
        setQuestions(updatedQuestions);
        saveAllQuestions(updatedQuestions);
        setAiDialogOpen(false);
        toast.success(`${newQuestions.length} questions added!`);
    };

    return (
        <Box>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                <Typography variant="h5" fontWeight="bold">
                    Registration Questions
                </Typography>
                <Box sx={{ display: 'flex', gap: 1 }} />
            </Box>

            <Alert severity="info" sx={{ mb: 2 }}>
                Create registration questions that attendees must answer when registering for your event.
                If no questions are added, attendees can register directly with a simple confirmation.
            </Alert>

            <Paper sx={{ p: 2, mb: 2 }}>
                <Autocomplete
                    options={events}
                    getOptionLabel={(option) => option.title || ''}
                    value={events.find(e => e.id === selectedEvent) || null}
                    onChange={(_, newValue) => setSelectedEvent(newValue?.id || '')}
                    renderInput={(params) => (
                        <TextField {...params} label="Search Event" placeholder="Type to search events..." />
                    )}
                    renderOption={(props, option) => (
                        <li {...props} key={option.id}>
                            <Box sx={{ width: '100%' }}>
                                <Typography variant="body1" noWrap>{option.title}</Typography>
                                <Typography variant="caption" color="text.secondary">
                                    {option.startTime ? new Date(option.startTime).toLocaleDateString() : ''}
                                </Typography>
                            </Box>
                        </li>
                    )}
                    isOptionEqualToValue={(option, value) => option.id === value.id}
                    sx={{ minWidth: 400 }}
                    noOptionsText="No events found"
                />
            </Paper>

            {selectedEvent ? (
                <Paper sx={{ p: 2 }}>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
                        <Typography variant="h6">
                            Questions ({questions.length})
                        </Typography>
                        <Box sx={{ display: 'flex', gap: 1 }}>
                            <Tooltip title="AI will suggest questions based on your event">
                                <Button
                                    variant="outlined"
                                    color="secondary"
                                    startIcon={<AIIcon />}
                                    onClick={handleOpenAiDialog}
                                >
                                    AI Suggest
                                </Button>
                            </Tooltip>
                            <Button
                                variant="contained"
                                startIcon={<AddIcon />}
                                onClick={handleAddQuestion}
                            >
                                Add Question
                            </Button>
                        </Box>
                    </Box>

                    {questions.length === 0 ? (
                        <Box sx={{ textAlign: 'center', py: 4 }}>
                            <Typography color="text.secondary">
                                No registration questions yet. Attendees will register with a simple confirmation.
                            </Typography>
                            <Box sx={{ mt: 2, display: 'flex', gap: 2, justifyContent: 'center' }}>
                                <Button
                                    variant="outlined"
                                    color="secondary"
                                    startIcon={<AIIcon />}
                                    onClick={handleOpenAiDialog}
                                >
                                    AI Suggest Questions
                                </Button>
                                <Button
                                    variant="outlined"
                                    startIcon={<AddIcon />}
                                    onClick={handleAddQuestion}
                                >
                                    Add Manually
                                </Button>
                            </Box>
                        </Box>
                    ) : (
                        <DragDropContext onDragEnd={handleDragEnd}>
                            <Droppable droppableId="questions">
                                {(provided) => (
                                    <List {...provided.droppableProps} ref={provided.innerRef}>
                                        {questions.map((question, index) => (
                                            <Draggable key={index} draggableId={`question-${index}`} index={index}>
                                                {(provided, snapshot) => (
                                                    <ListItem
                                                        ref={provided.innerRef}
                                                        {...provided.draggableProps}
                                                        sx={{
                                                            bgcolor: snapshot.isDragging ? 'action.hover' : 'background.paper',
                                                            mb: 1,
                                                            border: '1px solid',
                                                            borderColor: 'divider',
                                                            borderRadius: 1,
                                                        }}
                                                    >
                                                        <Box {...provided.dragHandleProps} sx={{ mr: 2, cursor: 'grab' }}>
                                                            <DragIcon color="action" />
                                                        </Box>
                                                        <ListItemText
                                                            primary={
                                                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                                                    <Typography fontWeight="medium">
                                                                        {question.questionText}
                                                                    </Typography>
                                                                    {question.required && (
                                                                        <Chip label="Required" size="small" color="error" />
                                                                    )}
                                                                </Box>
                                                            }
                                                            secondary={
                                                                <Box>
                                                                    <Chip
                                                                        label={questionTypes.find(t => t.value === question.questionType)?.label || question.questionType}
                                                                        size="small"
                                                                        sx={{ mr: 1 }}
                                                                    />
                                                                    {question.options?.length > 0 && (
                                                                        <Typography variant="caption" color="text.secondary">
                                                                            Options: {question.options.join(', ')}
                                                                        </Typography>
                                                                    )}
                                                                </Box>
                                                            }
                                                        />
                                                        <ListItemSecondaryAction>
                                                            <IconButton onClick={() => handleEditQuestion(question, index)}>
                                                                <EditIcon />
                                                            </IconButton>
                                                            <IconButton onClick={() => handleDeleteQuestion(index)} color="error">
                                                                <DeleteIcon />
                                                            </IconButton>
                                                        </ListItemSecondaryAction>
                                                    </ListItem>
                                                )}
                                            </Draggable>
                                        ))}
                                        {provided.placeholder}
                                    </List>
                                )}
                            </Droppable>
                        </DragDropContext>
                    )}
                </Paper>
            ) : (
                <Paper sx={{ p: 4, textAlign: 'center' }}>
                    <Typography color="text.secondary">
                        Please select an event to manage registration questions
                    </Typography>
                </Paper>
            )}

            <Dialog open={dialogOpen} onClose={() => setDialogOpen(false)} maxWidth="sm" fullWidth>
                <DialogTitle>
                    {editingQuestion !== null ? 'Edit Question' : 'Add Question'}
                </DialogTitle>
                <DialogContent>
                    <Box sx={{ pt: 1, display: 'flex', flexDirection: 'column', gap: 2 }}>
                        <TextField
                            label="Question Text"
                            value={formData.questionText}
                            onChange={(e) => setFormData({ ...formData, questionText: e.target.value })}
                            fullWidth
                            required
                            multiline
                            rows={2}
                        />

                        <FormControl fullWidth>
                            <InputLabel>Question Type</InputLabel>
                            <Select
                                value={formData.questionType}
                                onChange={(e) => setFormData({ ...formData, questionType: e.target.value })}
                                label="Question Type"
                            >
                                {questionTypes.map((type) => (
                                    <MenuItem key={type.value} value={type.value}>
                                        <Box>
                                            <Typography>{type.label}</Typography>
                                            <Typography variant="caption" color="text.secondary">
                                                {type.description}
                                            </Typography>
                                        </Box>
                                    </MenuItem>
                                ))}
                            </Select>
                        </FormControl>

                        {(formData.questionType === 'SINGLE_CHOICE' || formData.questionType === 'MULTIPLE_CHOICE') && (
                            <Box>
                                <Typography variant="subtitle2" gutterBottom>
                                    Options
                                </Typography>
                                {formData.options.map((option, index) => (
                                    <Box key={index} sx={{ display: 'flex', gap: 1, mb: 1 }}>
                                        <TextField
                                            value={option}
                                            onChange={(e) => handleOptionChange(index, e.target.value)}
                                            placeholder={`Option ${index + 1}`}
                                            size="small"
                                            fullWidth
                                        />
                                        <IconButton
                                            onClick={() => handleRemoveOption(index)}
                                            disabled={formData.options.length <= 1}
                                            color="error"
                                        >
                                            <DeleteIcon />
                                        </IconButton>
                                    </Box>
                                ))}
                                <Button
                                    startIcon={<AddIcon />}
                                    onClick={handleAddOption}
                                    size="small"
                                >
                                    Add Option
                                </Button>
                            </Box>
                        )}

                        <FormControlLabel
                            control={
                                <Switch
                                    checked={formData.required}
                                    onChange={(e) => setFormData({ ...formData, required: e.target.checked })}
                                />
                            }
                            label="Required question"
                        />
                    </Box>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setDialogOpen(false)}>Cancel</Button>
                    <Button onClick={handleSaveQuestion} variant="contained">
                        {editingQuestion !== null ? 'Update' : 'Add'}
                    </Button>
                </DialogActions>
            </Dialog>

            <Dialog open={aiDialogOpen} onClose={() => setAiDialogOpen(false)} maxWidth="md" fullWidth>
                <DialogTitle>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <AIIcon color="secondary" />
                        AI Suggest Questions
                    </Box>
                </DialogTitle>
                <DialogContent>
                    <Box sx={{ pt: 1 }}>
                        {suggestedQuestions.length === 0 ? (
                            <Box>
                                <Typography variant="body2" color="text.secondary" gutterBottom>
                                    AI will suggest registration questions based on your event details.
                                </Typography>
                                <Box sx={{ mt: 3 }}>
                                    <Typography variant="subtitle2" gutterBottom>
                                        Number of questions: {numberOfQuestions}
                                    </Typography>
                                    <Slider
                                        value={numberOfQuestions}
                                        onChange={(_, value) => setNumberOfQuestions(value)}
                                        min={1}
                                        max={10}
                                        marks
                                        valueLabelDisplay="auto"
                                        sx={{ maxWidth: 300 }}
                                    />
                                </Box>
                                <Box sx={{ mt: 3, textAlign: 'center' }}>
                                    <Button
                                        variant="contained"
                                        color="secondary"
                                        startIcon={<AIIcon />}
                                        onClick={handleGenerateAiQuestions}
                                        disabled={aiLoading}
                                        size="large"
                                    >
                                        {aiLoading ? 'Generating...' : 'Generate Questions'}
                                    </Button>
                                </Box>
                            </Box>
                        ) : (
                            <Box>
                                <Typography variant="body2" color="text.secondary" gutterBottom>
                                    Select the questions you want to add:
                                </Typography>
                                <List>
                                    {suggestedQuestions.map((question, index) => (
                                        <ListItem
                                            key={index}
                                            sx={{
                                                border: '1px solid',
                                                borderColor: selectedSuggestions.includes(index) ? 'primary.main' : 'divider',
                                                borderRadius: 1,
                                                mb: 1,
                                                cursor: 'pointer',
                                                bgcolor: selectedSuggestions.includes(index) ? 'action.selected' : 'background.paper',
                                            }}
                                            onClick={() => handleToggleSuggestion(index)}
                                        >
                                            <ListItemText
                                                primary={
                                                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                                        <Typography fontWeight="medium">
                                                            {question.questionText}
                                                        </Typography>
                                                        {question.required && (
                                                            <Chip label="Required" size="small" color="error" />
                                                        )}
                                                    </Box>
                                                }
                                                secondary={
                                                    <Box sx={{ mt: 0.5 }}>
                                                        <Chip
                                                            label={questionTypes.find(t => t.value === question.questionType)?.label || question.questionType}
                                                            size="small"
                                                            sx={{ mr: 1 }}
                                                        />
                                                        {question.options?.length > 0 && (
                                                            <Typography variant="caption" color="text.secondary">
                                                                Options: {question.options.join(', ')}
                                                            </Typography>
                                                        )}
                                                    </Box>
                                                }
                                            />
                                            <Switch
                                                checked={selectedSuggestions.includes(index)}
                                                onChange={() => handleToggleSuggestion(index)}
                                            />
                                        </ListItem>
                                    ))}
                                </List>
                                <Box sx={{ mt: 2, display: 'flex', gap: 2, justifyContent: 'center' }}>
                                    <Button
                                        variant="outlined"
                                        onClick={handleGenerateAiQuestions}
                                        disabled={aiLoading}
                                    >
                                        {aiLoading ? 'Generating...' : 'Regenerate'}
                                    </Button>
                                </Box>
                            </Box>
                        )}
                    </Box>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setAiDialogOpen(false)}>Cancel</Button>
                    {suggestedQuestions.length > 0 && (
                        <Button
                            onClick={handleAddSuggestedQuestions}
                            variant="contained"
                            disabled={selectedSuggestions.length === 0}
                        >
                            Add {selectedSuggestions.length} Question{selectedSuggestions.length !== 1 ? 's' : ''}
                        </Button>
                    )}
                </DialogActions>
            </Dialog>

            <ConfirmDialog
                open={confirmDialog.open}
                title={confirmDialog.title}
                message={confirmDialog.message}
                confirmColor={confirmDialog.confirmColor}
                onConfirm={() => {
                    confirmDialog.action?.();
                    setConfirmDialog({ ...confirmDialog, open: false });
                }}
                onCancel={() => setConfirmDialog({ ...confirmDialog, open: false })}
            />
        </Box>
    );
};

export default RegistrationQuestions;

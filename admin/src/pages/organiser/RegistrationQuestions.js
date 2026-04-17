import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Typography,
    Autocomplete,
    FormControl,
    InputLabel,
    Select,
    MenuItem,
    Button,
    IconButton,
    TextField,
    List,
    ListItem,
    Chip,
    Switch,
    FormControlLabel,
    Alert,
    Tooltip,
    Slider,
    Stack,
    Avatar,
} from '@mui/material';
import {
    Add as AddIcon,
    Edit as EditIcon,
    Delete as DeleteIcon,
    DragIndicator as DragIcon,
    AutoAwesome as AIIcon,
    QuestionAnswer as QuestionIcon,
    HelpOutline as HelpIcon,
} from '@mui/icons-material';
import { DragDropContext, Droppable, Draggable } from '@hello-pangea/dnd';
import { organiserApi } from '../../api';
import { ConfirmDialog } from '../../components/common';
import {
    PageHeader,
    SectionCard,
    FormDialog,
    FormSection,
    EmptyState,
    StatusChip,
    LoadingButton,
} from '../../components/ui';
import { tokens } from '../../theme';
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
            loadQuestions();
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
            setSelectedSuggestions(questions.map((_, index) => index));
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

    const isChoiceType = formData.questionType === 'SINGLE_CHOICE' || formData.questionType === 'MULTIPLE_CHOICE';

    return (
        <Box>
            <PageHeader
                title="Registration Questions"
                subtitle="Build custom registration forms for your events"
                icon={<QuestionIcon />}
            />

            <Alert severity="info" sx={{ mb: 3, borderRadius: `${tokens.radius.md}px` }}>
                Create registration questions that attendees must answer when registering for your event.
                If no questions are added, attendees can register directly with a simple confirmation.
            </Alert>

            <SectionCard
                title="Select Event"
                subtitle="Choose an event to manage its registration questions"
                sx={{ mb: 3 }}
            >
                <Autocomplete
                    options={events}
                    getOptionLabel={(option) => option.title || ''}
                    value={events.find(e => e.id === selectedEvent) || null}
                    onChange={(_, newValue) => setSelectedEvent(newValue?.id || '')}
                    renderInput={(params) => (
                        <TextField {...params} label="Search Event" placeholder="Type to search events..." />
                    )}
                    renderOption={(props, option) => (
                        <Box component="li" {...props} key={option.id} sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                            <Avatar src={option.imageUrl} variant="rounded" sx={{ width: 32, height: 32 }} />
                            <Box sx={{ minWidth: 0 }}>
                                <Typography variant="body2" fontWeight="medium" noWrap>{option.title}</Typography>
                                <Typography variant="caption" color="text.secondary">
                                    {option.startTime ? new Date(option.startTime).toLocaleDateString() : ''}
                                </Typography>
                            </Box>
                        </Box>
                    )}
                    isOptionEqualToValue={(option, value) => option.id === value.id}
                    noOptionsText="No events found"
                />
            </SectionCard>

            {selectedEvent ? (
                <SectionCard
                    title={`Questions (${questions.length})`}
                    subtitle="Drag to reorder, click edit to modify"
                    action={
                        <Stack direction="row" spacing={1}>
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
                        </Stack>
                    }
                >
                    {questions.length === 0 ? (
                        <EmptyState
                            icon={<HelpIcon sx={{ fontSize: 32 }} />}
                            title="No registration questions yet"
                            description="Attendees will register with a simple confirmation. Add questions to collect more information."
                            action={
                                <Stack direction="row" spacing={2}>
                                    <Button
                                        variant="outlined"
                                        color="secondary"
                                        startIcon={<AIIcon />}
                                        onClick={handleOpenAiDialog}
                                    >
                                        AI Suggest Questions
                                    </Button>
                                    <Button
                                        variant="contained"
                                        startIcon={<AddIcon />}
                                        onClick={handleAddQuestion}
                                    >
                                        Add Manually
                                    </Button>
                                </Stack>
                            }
                        />
                    ) : (
                        <DragDropContext onDragEnd={handleDragEnd}>
                            <Droppable droppableId="questions">
                                {(provided) => (
                                    <List
                                        {...provided.droppableProps}
                                        ref={provided.innerRef}
                                        disablePadding
                                    >
                                        {questions.map((question, index) => (
                                            <Draggable key={index} draggableId={`question-${index}`} index={index}>
                                                {(provided, snapshot) => (
                                                    <ListItem
                                                        ref={provided.innerRef}
                                                        {...provided.draggableProps}
                                                        sx={{
                                                            bgcolor: snapshot.isDragging
                                                                ? tokens.palette.primary[50]
                                                                : tokens.surfaces.card,
                                                            mb: 1.5,
                                                            border: '1px solid',
                                                            borderColor: snapshot.isDragging
                                                                ? tokens.palette.primary[300]
                                                                : tokens.borders.subtle,
                                                            borderRadius: `${tokens.radius.md}px`,
                                                            boxShadow: snapshot.isDragging ? tokens.shadow.md : 'none',
                                                            transition: tokens.motion.fast,
                                                            p: 2,
                                                            alignItems: 'flex-start',
                                                        }}
                                                        secondaryAction={
                                                            <Stack direction="row" spacing={0.5}>
                                                                <Tooltip title="Edit">
                                                                    <IconButton
                                                                        size="small"
                                                                        onClick={() => handleEditQuestion(question, index)}
                                                                    >
                                                                        <EditIcon fontSize="small" />
                                                                    </IconButton>
                                                                </Tooltip>
                                                                <Tooltip title="Delete">
                                                                    <IconButton
                                                                        size="small"
                                                                        onClick={() => handleDeleteQuestion(index)}
                                                                        sx={{ color: tokens.palette.danger[600] }}
                                                                    >
                                                                        <DeleteIcon fontSize="small" />
                                                                    </IconButton>
                                                                </Tooltip>
                                                            </Stack>
                                                        }
                                                    >
                                                        <Box
                                                            {...provided.dragHandleProps}
                                                            sx={{
                                                                mr: 1.5,
                                                                mt: 0.25,
                                                                cursor: 'grab',
                                                                color: tokens.text.muted,
                                                                display: 'flex',
                                                                '&:active': { cursor: 'grabbing' },
                                                            }}
                                                        >
                                                            <DragIcon />
                                                        </Box>
                                                        <Box
                                                            sx={{
                                                                width: 28,
                                                                height: 28,
                                                                borderRadius: `${tokens.radius.sm}px`,
                                                                bgcolor: tokens.palette.primary[50],
                                                                color: tokens.palette.primary[700],
                                                                display: 'flex',
                                                                alignItems: 'center',
                                                                justifyContent: 'center',
                                                                fontSize: '0.75rem',
                                                                fontWeight: 700,
                                                                mr: 1.5,
                                                                flexShrink: 0,
                                                            }}
                                                        >
                                                            {index + 1}
                                                        </Box>
                                                        <Box sx={{ flex: 1, minWidth: 0, pr: 8 }}>
                                                            <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 0.5 }}>
                                                                <Typography variant="body1" fontWeight={600}>
                                                                    {question.questionText}
                                                                </Typography>
                                                                {question.required && (
                                                                    <StatusChip label="Required" status="danger" />
                                                                )}
                                                            </Stack>
                                                            <Stack direction="row" alignItems="center" spacing={1} flexWrap="wrap">
                                                                <Chip
                                                                    label={questionTypes.find(t => t.value === question.questionType)?.label || question.questionType}
                                                                    size="small"
                                                                    sx={{
                                                                        bgcolor: tokens.palette.neutral[100],
                                                                        color: tokens.text.secondary,
                                                                        fontWeight: 600,
                                                                        fontSize: '0.6875rem',
                                                                    }}
                                                                />
                                                                {question.options?.length > 0 && (
                                                                    <Typography variant="caption" color="text.secondary">
                                                                        Options: {question.options.join(', ')}
                                                                    </Typography>
                                                                )}
                                                            </Stack>
                                                        </Box>
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
                </SectionCard>
            ) : (
                <SectionCard>
                    <EmptyState
                        icon={<QuestionIcon sx={{ fontSize: 32 }} />}
                        title="No event selected"
                        description="Please select an event above to manage its registration questions"
                    />
                </SectionCard>
            )}

            <FormDialog
                open={dialogOpen}
                onClose={() => setDialogOpen(false)}
                maxWidth="sm"
                icon={<QuestionIcon />}
                title={editingQuestion !== null ? 'Edit Question' : 'Add Question'}
                subtitle={editingQuestion !== null ? 'Modify the question details' : 'Create a new registration question'}
                actions={
                    <>
                        <Button onClick={() => setDialogOpen(false)}>Cancel</Button>
                        <LoadingButton onClick={handleSaveQuestion} variant="contained" loading={loading}>
                            {editingQuestion !== null ? 'Update' : 'Add'}
                        </LoadingButton>
                    </>
                }
            >
                <FormSection title="Question Details">
                    <Stack spacing={2.5}>
                        <TextField
                            label="Question Text"
                            value={formData.questionText}
                            onChange={(e) => setFormData({ ...formData, questionText: e.target.value })}
                            fullWidth
                            required
                            multiline
                            rows={2}
                            placeholder="e.g. What is your dietary preference?"
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

                        <FormControlLabel
                            control={
                                <Switch
                                    checked={formData.required}
                                    onChange={(e) => setFormData({ ...formData, required: e.target.checked })}
                                />
                            }
                            label="Required question"
                        />
                    </Stack>
                </FormSection>

                {isChoiceType && (
                    <FormSection
                        title="Options"
                        description="Add at least 2 options for this question"
                        topDivider
                    >
                        <Stack spacing={1.25}>
                            {formData.options.map((option, index) => (
                                <Stack key={index} direction="row" spacing={1} alignItems="center">
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
                                        size="small"
                                        sx={{ color: tokens.palette.danger[600] }}
                                    >
                                        <DeleteIcon fontSize="small" />
                                    </IconButton>
                                </Stack>
                            ))}
                            <Box>
                                <Button
                                    startIcon={<AddIcon />}
                                    onClick={handleAddOption}
                                    size="small"
                                >
                                    Add Option
                                </Button>
                            </Box>
                        </Stack>
                    </FormSection>
                )}
            </FormDialog>

            <FormDialog
                open={aiDialogOpen}
                onClose={() => setAiDialogOpen(false)}
                maxWidth="md"
                icon={<AIIcon />}
                title="AI Suggest Questions"
                subtitle="Let AI generate registration questions based on your event details"
                actions={
                    <>
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
                    </>
                }
            >
                {suggestedQuestions.length === 0 ? (
                    <FormSection title="Configure Generation" description="AI will analyze your event title, category, and description">
                        <Box sx={{ mt: 1 }}>
                            <Typography variant="body2" fontWeight={600} sx={{ mb: 1 }}>
                                Number of questions: {numberOfQuestions}
                            </Typography>
                            <Slider
                                value={numberOfQuestions}
                                onChange={(_, value) => setNumberOfQuestions(value)}
                                min={1}
                                max={10}
                                marks
                                valueLabelDisplay="auto"
                                sx={{ maxWidth: 360 }}
                            />
                        </Box>
                        <Box sx={{ mt: 3, textAlign: 'center' }}>
                            <LoadingButton
                                variant="contained"
                                color="secondary"
                                startIcon={<AIIcon />}
                                onClick={handleGenerateAiQuestions}
                                loading={aiLoading}
                                size="large"
                            >
                                {aiLoading ? 'Generating...' : 'Generate Questions'}
                            </LoadingButton>
                        </Box>
                    </FormSection>
                ) : (
                    <Box>
                        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                            Select the questions you want to add:
                        </Typography>
                        <List disablePadding>
                            {suggestedQuestions.map((question, index) => {
                                const isSelected = selectedSuggestions.includes(index);
                                return (
                                    <ListItem
                                        key={index}
                                        onClick={() => handleToggleSuggestion(index)}
                                        sx={{
                                            border: '1px solid',
                                            borderColor: isSelected ? tokens.palette.primary[500] : tokens.borders.subtle,
                                            borderRadius: `${tokens.radius.md}px`,
                                            mb: 1.25,
                                            cursor: 'pointer',
                                            bgcolor: isSelected ? tokens.palette.primary[50] : tokens.surfaces.card,
                                            transition: tokens.motion.fast,
                                            '&:hover': {
                                                borderColor: tokens.palette.primary[400],
                                            },
                                        }}
                                        secondaryAction={
                                            <Switch
                                                checked={isSelected}
                                                onChange={() => handleToggleSuggestion(index)}
                                            />
                                        }
                                    >
                                        <Box sx={{ flex: 1, pr: 6 }}>
                                            <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 0.5 }}>
                                                <Typography variant="body1" fontWeight={600}>
                                                    {question.questionText}
                                                </Typography>
                                                {question.required && (
                                                    <StatusChip label="Required" status="danger" />
                                                )}
                                            </Stack>
                                            <Stack direction="row" alignItems="center" spacing={1} flexWrap="wrap">
                                                <Chip
                                                    label={questionTypes.find(t => t.value === question.questionType)?.label || question.questionType}
                                                    size="small"
                                                    sx={{
                                                        bgcolor: tokens.palette.neutral[100],
                                                        color: tokens.text.secondary,
                                                        fontWeight: 600,
                                                        fontSize: '0.6875rem',
                                                    }}
                                                />
                                                {question.options?.length > 0 && (
                                                    <Typography variant="caption" color="text.secondary">
                                                        Options: {question.options.join(', ')}
                                                    </Typography>
                                                )}
                                            </Stack>
                                        </Box>
                                    </ListItem>
                                );
                            })}
                        </List>
                        <Box sx={{ mt: 2, display: 'flex', justifyContent: 'center' }}>
                            <LoadingButton
                                variant="outlined"
                                onClick={handleGenerateAiQuestions}
                                loading={aiLoading}
                                startIcon={<AIIcon />}
                            >
                                Regenerate
                            </LoadingButton>
                        </Box>
                    </Box>
                )}
            </FormDialog>

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

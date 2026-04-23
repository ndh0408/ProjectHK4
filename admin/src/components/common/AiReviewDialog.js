import React from 'react';
import {
    Alert,
    Box,
    Chip,
    CircularProgress,
    Dialog,
    DialogActions,
    DialogContent,
    DialogTitle,
    Divider,
    IconButton,
    Stack,
    Typography,
    Button,
} from '@mui/material';
import {
    Close as CloseIcon,
    Psychology as PsychologyIcon,
} from '@mui/icons-material';

const TRUST_COLOR = {
    HIGH: 'success',
    MEDIUM: 'warning',
    LOW: 'error',
};

const RISK_COLOR = {
    LOW: 'success',
    MEDIUM: 'warning',
    HIGH: 'error',
};

const DECISION_COLOR = {
    APPROVE: 'success',
    REVIEW: 'warning',
    REJECT: 'error',
};

const ACTION_COLOR = {
    KEEP: 'success',
    WARN: 'warning',
    LOCK: 'error',
};

const BulletList = ({ items, emptyText }) => {
    if (!items || items.length === 0) {
        return (
            <Typography variant="body2" color="text.secondary">
                {emptyText}
            </Typography>
        );
    }
    return (
        <Stack spacing={0.5}>
            {items.map((item, i) => (
                <Typography key={`${item}-${i}`} variant="body2" color="text.primary">
                    {item}
                </Typography>
            ))}
        </Stack>
    );
};

const Section = ({ title, children }) => (
    <Box sx={{ mt: 2 }}>
        <Typography variant="subtitle2" sx={{ mb: 0.75 }}>{title}</Typography>
        {children}
    </Box>
);

const AiReviewDialog = ({
    open,
    onClose,
    title,
    subtitle,
    subjectName,
    subjectEmail,
    loading,
    error,
    data,
    mode = 'organiser',
}) => {
    const isOrganiser = mode === 'organiser';

    const primaryLevel = isOrganiser ? data?.trust : data?.risk;
    const primaryLevelColor = isOrganiser
        ? (TRUST_COLOR[primaryLevel] || 'default')
        : (RISK_COLOR[primaryLevel] || 'default');
    const primaryLevelLabel = isOrganiser ? `Trust: ${primaryLevel || '—'}` : `Risk: ${primaryLevel || '—'}`;

    const decisionOrAction = isOrganiser ? data?.decision : data?.action;
    const decisionColor = isOrganiser
        ? (DECISION_COLOR[decisionOrAction] || 'default')
        : (ACTION_COLOR[decisionOrAction] || 'default');
    const decisionLabel = isOrganiser ? `Decision: ${decisionOrAction || '—'}` : `Action: ${decisionOrAction || '—'}`;

    return (
        <Dialog open={open} onClose={onClose} fullWidth maxWidth="sm">
            <DialogTitle>
                <Stack direction="row" alignItems="center" justifyContent="space-between">
                    <Stack direction="row" alignItems="center" spacing={1}>
                        <PsychologyIcon color="primary" />
                        <Typography variant="h6" fontWeight={600}>
                            {title}
                        </Typography>
                    </Stack>
                    <IconButton size="small" onClick={onClose}>
                        <CloseIcon fontSize="small" />
                    </IconButton>
                </Stack>
            </DialogTitle>
            <Divider />
            <DialogContent>
                {subtitle && (
                    <Alert severity="info" variant="outlined" sx={{ mb: 2 }}>
                        {subtitle}
                    </Alert>
                )}

                <Box sx={{ mb: 1 }}>
                    <Typography variant="body1" fontWeight={600}>
                        {subjectName || '—'}
                    </Typography>
                    {subjectEmail && (
                        <Typography variant="body2" color="text.secondary">
                            {subjectEmail}
                        </Typography>
                    )}
                </Box>

                {loading && (
                    <Stack alignItems="center" spacing={1.5} sx={{ py: 4 }}>
                        <CircularProgress size={32} />
                        <Typography variant="body2" color="text.secondary">
                            AI is analysing…
                        </Typography>
                    </Stack>
                )}

                {!loading && error && (
                    <Alert severity="error" sx={{ mt: 2 }}>
                        {error}
                    </Alert>
                )}

                {!loading && !error && data && (
                    <>
                        <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap sx={{ mb: 2 }}>
                            <Chip
                                size="small"
                                label={primaryLevelLabel}
                                color={primaryLevelColor}
                            />
                            {isOrganiser && data?.trustworthy != null && (
                                <Chip
                                    size="small"
                                    variant="outlined"
                                    label={`Trustworthy: ${data.trustworthy ? 'Yes' : 'No'}`}
                                    color={data.trustworthy ? 'success' : 'error'}
                                />
                            )}
                            <Chip size="small" variant="outlined" label={decisionLabel} color={decisionColor} />
                            {data?.confidence != null && (
                                <Chip
                                    size="small"
                                    variant="outlined"
                                    label={`Confidence: ${data.confidence}%`}
                                />
                            )}
                        </Stack>

                        <Section title={isOrganiser ? 'Summary' : 'Behavior summary'}>
                            <Typography variant="body2" color="text.primary">
                                {(isOrganiser ? data.summary : data.behaviorSummary) || 'No summary returned.'}
                            </Typography>
                        </Section>

                        {isOrganiser ? (
                            <>
                                <Section title="Strengths">
                                    <BulletList items={data.strengths} emptyText="No strengths listed." />
                                </Section>
                                <Section title="Missing information">
                                    <BulletList items={data.missingInfo} emptyText="No missing information returned." />
                                </Section>
                                <Section title="Risk signals">
                                    <BulletList items={data.riskSignals} emptyText="No risk signal returned." />
                                </Section>
                            </>
                        ) : (
                            <Section title="Reasons">
                                <BulletList items={data.reasons} emptyText="No reasons returned." />
                            </Section>
                        )}

                        {data.recommendation && (
                            <Alert severity="warning" variant="outlined" sx={{ mt: 2 }} icon={false}>
                                {data.recommendation}
                            </Alert>
                        )}
                    </>
                )}
            </DialogContent>
            <DialogActions>
                <Button onClick={onClose}>Close</Button>
            </DialogActions>
        </Dialog>
    );
};

export default AiReviewDialog;

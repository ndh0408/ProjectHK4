import React from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    Button,
    Typography,
    Box,
    Chip,
} from '@mui/material';
import {
    Warning as WarningIcon,
    Upgrade as UpgradeIcon,
} from '@mui/icons-material';

const UpgradeDialog = ({ open, onClose, title, message, feature }) => {
    const navigate = useNavigate();

    const handleUpgrade = () => {
        onClose();
        navigate('/organiser/subscription');
    };

    return (
        <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth>
            <DialogTitle sx={{ display: 'flex', alignItems: 'center', gap: 1, bgcolor: 'warning.light', color: 'warning.contrastText' }}>
                <WarningIcon />
                {title || 'Upgrade Required'}
            </DialogTitle>
            <DialogContent sx={{ mt: 2 }}>
                <Box sx={{ textAlign: 'center', py: 2 }}>
                    {feature && (
                        <Chip
                            label={feature}
                            color="primary"
                            sx={{ mb: 2 }}
                        />
                    )}
                    <Typography variant="body1" sx={{ mb: 2 }}>
                        {message}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                        Upgrade your subscription to unlock more features and higher limits.
                    </Typography>
                </Box>
            </DialogContent>
            <DialogActions sx={{ p: 2, gap: 1 }}>
                <Button onClick={onClose} color="inherit">
                    Maybe Later
                </Button>
                <Button
                    variant="contained"
                    color="warning"
                    startIcon={<UpgradeIcon />}
                    onClick={handleUpgrade}
                >
                    View Plans & Upgrade
                </Button>
            </DialogActions>
        </Dialog>
    );
};

export default UpgradeDialog;

import React from 'react';
import {
    Dialog,
    DialogTitle,
    DialogContent,
    DialogContentText,
    DialogActions,
    Button,
    Box,
    Typography,
} from '@mui/material';

const ConfirmDialog = ({
    open,
    title,
    message,
    entityName,
    confirmText = 'Confirm',
    cancelText = 'Cancel',
    onConfirm,
    onCancel,
    confirmColor = 'primary',
}) => {
    return (
        <Dialog open={open} onClose={onCancel} fullWidth maxWidth="xs">
            <DialogTitle>{title}</DialogTitle>
            <DialogContent>
                <DialogContentText component="div">
                    {message}
                    {entityName && (
                        <Box
                            sx={{
                                mt: 1.5,
                                px: 1.5,
                                py: 1,
                                borderRadius: 1,
                                bgcolor: 'action.hover',
                                borderLeft: 3,
                                borderColor: `${confirmColor}.main`,
                            }}
                        >
                            <Typography variant="body2" sx={{ fontWeight: 600, wordBreak: 'break-word' }}>
                                {entityName}
                            </Typography>
                        </Box>
                    )}
                </DialogContentText>
            </DialogContent>
            <DialogActions>
                <Button onClick={onCancel}>{cancelText}</Button>
                <Button onClick={onConfirm} color={confirmColor} variant="contained">
                    {confirmText}
                </Button>
            </DialogActions>
        </Dialog>
    );
};

export default ConfirmDialog;

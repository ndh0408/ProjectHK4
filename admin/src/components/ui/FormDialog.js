import React from 'react';
import {
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    IconButton,
    Box,
    Typography,
    Divider,
} from '@mui/material';
import CloseIcon from '@mui/icons-material/Close';

/**
 * Consistent create/edit dialog shell. Use `actions` for CTA buttons and
 * pass form content as children.
 */
const FormDialog = ({
    open,
    onClose,
    title,
    subtitle,
    icon,
    actions,
    children,
    maxWidth = 'sm',
    fullWidth = true,
    disableBackdropClose = false,
    dividers = true,
    contentSx,
    ...rest
}) => {
    const handleClose = (event, reason) => {
        if (disableBackdropClose && (reason === 'backdropClick' || reason === 'escapeKeyDown')) {
            return;
        }
        onClose?.(event, reason);
    };

    return (
        <Dialog
            open={open}
            onClose={handleClose}
            maxWidth={maxWidth}
            fullWidth={fullWidth}
            {...rest}
        >
            <DialogTitle sx={{ display: 'flex', alignItems: 'flex-start', gap: 1.5, pb: 1.5 }}>
                {icon && (
                    <Box
                        sx={{
                            width: 40,
                            height: 40,
                            borderRadius: 2,
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            bgcolor: 'primary.50',
                            color: 'primary.600',
                            flexShrink: 0,
                        }}
                    >
                        {icon}
                    </Box>
                )}
                <Box sx={{ flex: 1, minWidth: 0 }}>
                    <Typography variant="h3" component="div">
                        {title}
                    </Typography>
                    {subtitle && (
                        <Typography variant="body2" color="text.secondary" sx={{ mt: 0.25 }}>
                            {subtitle}
                        </Typography>
                    )}
                </Box>
                <IconButton
                    size="small"
                    onClick={onClose}
                    aria-label="close"
                    sx={{ ml: 1 }}
                >
                    <CloseIcon fontSize="small" />
                </IconButton>
            </DialogTitle>
            {dividers && <Divider />}
            <DialogContent sx={{ pt: 2.5, ...contentSx }}>{children}</DialogContent>
            {actions && (
                <>
                    {dividers && <Divider />}
                    <DialogActions>{actions}</DialogActions>
                </>
            )}
        </Dialog>
    );
};

export default FormDialog;

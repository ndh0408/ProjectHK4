import React from 'react';
import { Box, Typography, Divider } from '@mui/material';

/**
 * Group related form fields with a label + description + optional divider.
 * Use inside SectionCard or FormDialog to organise long forms.
 */
const FormSection = ({ title, description, children, topDivider = false, sx }) => (
    <Box sx={{ mb: 3, ...sx }}>
        {topDivider && <Divider sx={{ mb: 2.5 }} />}
        {(title || description) && (
            <Box sx={{ mb: 2 }}>
                {title && (
                    <Typography variant="h4" sx={{ mb: 0.5 }}>
                        {title}
                    </Typography>
                )}
                {description && (
                    <Typography variant="body2" color="text.secondary">
                        {description}
                    </Typography>
                )}
            </Box>
        )}
        {children}
    </Box>
);

export default FormSection;

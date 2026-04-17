import React from 'react';
import { Card, CardHeader, CardContent, Divider, Box } from '@mui/material';

/**
 * Card section with optional title, subtitle, actions and footer.
 * Use as a standard content container on detail/form pages.
 */
const SectionCard = ({
    title,
    subtitle,
    action,
    children,
    footer,
    noPadding = false,
    sx,
    contentSx,
    divider = false,
}) => {
    const hasHeader = Boolean(title || subtitle || action);
    return (
        <Card sx={sx}>
            {hasHeader && (
                <CardHeader
                    title={title}
                    subheader={subtitle}
                    action={action}
                    sx={{ pb: subtitle ? 1.5 : 2 }}
                />
            )}
            {hasHeader && divider && <Divider />}
            <CardContent
                sx={{
                    pt: hasHeader ? (divider ? 2.5 : 0.5) : 2.5,
                    px: noPadding ? 0 : undefined,
                    pb: footer ? 1 : undefined,
                    '&:last-child': { pb: noPadding ? 0 : (footer ? 1 : undefined) },
                    ...contentSx,
                }}
            >
                {children}
            </CardContent>
            {footer && (
                <>
                    <Divider />
                    <Box sx={{ p: 2 }}>{footer}</Box>
                </>
            )}
        </Card>
    );
};

export default SectionCard;

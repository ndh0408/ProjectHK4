import React from 'react';
import { Chip } from '@mui/material';
import { tokens } from '../../theme';

const VARIANT_MAP = {
    success: tokens.status.success,
    warning: tokens.status.warning,
    danger: tokens.status.danger,
    error: tokens.status.danger,
    info: tokens.status.info,
    primary: tokens.status.primary,
    neutral: tokens.status.neutral,
    default: tokens.status.neutral,
};

/**
 * Semantic status chip. Renders with subtle bg + border + fg matching the
 * design token status palette. Supports optional leading icon.
 */
const StatusChip = ({ label, status = 'neutral', icon, size = 'small', sx, ...rest }) => {
    const palette = VARIANT_MAP[status] ?? VARIANT_MAP.neutral;
    return (
        <Chip
            label={label}
            size={size}
            icon={icon}
            sx={{
                bgcolor: palette.bg,
                color: palette.fg,
                border: `1px solid ${palette.border}`,
                fontWeight: 600,
                '& .MuiChip-icon': { color: palette.fg, marginLeft: '6px' },
                ...sx,
            }}
            {...rest}
        />
    );
};

export default StatusChip;

import React from 'react';
import { Button, CircularProgress } from '@mui/material';

/**
 * Button that shows a spinner when `loading` is true and is auto-disabled.
 * Drop-in replacement for `<Button>` — passes through all MUI props.
 */
const LoadingButton = React.forwardRef(function LoadingButton(
    { loading = false, disabled, startIcon, children, ...rest },
    ref,
) {
    return (
        <Button
            ref={ref}
            disabled={disabled || loading}
            startIcon={loading ? (
                <CircularProgress size={14} thickness={5} color="inherit" />
            ) : startIcon}
            {...rest}
        >
            {children}
        </Button>
    );
});

export default LoadingButton;

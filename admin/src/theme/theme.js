import { createTheme, alpha } from '@mui/material/styles';
import tokens, {
    palette,
    text,
    borders,
    radius,
    shadow,
    typography,
    surfaces,
    spacing,
    motion,
} from './tokens';

const muiShadows = [
    'none',
    shadow.xs,
    shadow.sm,
    shadow.sm,
    shadow.md,
    shadow.md,
    shadow.md,
    shadow.lg,
    shadow.lg,
    shadow.lg,
    shadow.lg,
    shadow.xl,
    shadow.xl,
    shadow.xl,
    shadow.xl,
    shadow.xl,
    shadow.xl,
    shadow.xl,
    shadow.xl,
    shadow.xl,
    shadow.xl,
    shadow.xl,
    shadow.xl,
    shadow.xl,
    shadow.xl,
];

const buildTheme = () => createTheme({
    palette: {
        mode: 'light',
        primary: {
            main: palette.primary[500],
            light: palette.primary[400],
            dark: palette.primary[600],
            contrastText: '#ffffff',
        },
        secondary: {
            main: palette.secondary[500],
            light: palette.secondary[400],
            dark: palette.secondary[600],
            contrastText: '#ffffff',
        },
        success: {
            main: palette.success[500],
            light: palette.success[300],
            dark: palette.success[600],
            contrastText: '#ffffff',
        },
        warning: {
            main: palette.warning[500],
            light: palette.warning[300],
            dark: palette.warning[600],
            contrastText: '#ffffff',
        },
        error: {
            main: palette.danger[500],
            light: palette.danger[300],
            dark: palette.danger[600],
            contrastText: '#ffffff',
        },
        info: {
            main: palette.info[500],
            light: palette.info[300],
            dark: palette.info[600],
            contrastText: '#ffffff',
        },
        background: {
            default: surfaces.page,
            paper: surfaces.card,
        },
        text: {
            primary: text.strong,
            secondary: text.secondary,
            disabled: text.disabled,
        },
        divider: borders.subtle,
        grey: palette.neutral,
    },
    typography: {
        fontFamily: typography.fontFamily,
        htmlFontSize: 16,
        display: typography.scale.display,
        h1: typography.scale.h1,
        h2: typography.scale.h2,
        h3: typography.scale.h3,
        h4: typography.scale.h4,
        h5: typography.scale.h5,
        h6: typography.scale.h6,
        subtitle1: { ...typography.scale.bodyLg, fontWeight: 500 },
        subtitle2: { ...typography.scale.body, fontWeight: 600 },
        body1: typography.scale.bodyLg,
        body2: typography.scale.body,
        button: { textTransform: 'none', fontWeight: 600, letterSpacing: 0 },
        caption: typography.scale.caption,
        overline: { ...typography.scale.caption, textTransform: 'uppercase', letterSpacing: '0.08em', fontWeight: 600 },
    },
    shape: {
        borderRadius: radius.lg,
    },
    shadows: muiShadows,
    spacing: 4,
    breakpoints: {
        values: { xs: 0, sm: 600, md: 900, lg: 1200, xl: 1536 },
    },
    components: {
        MuiCssBaseline: {
            styleOverrides: {
                'html, body, #root': {
                    height: '100%',
                },
                body: {
                    backgroundColor: surfaces.page,
                    color: text.strong,
                    WebkitFontSmoothing: 'antialiased',
                    MozOsxFontSmoothing: 'grayscale',
                },
                '::selection': {
                    backgroundColor: palette.primary[100],
                    color: palette.primary[900],
                },
                '::-webkit-scrollbar': { width: 10, height: 10 },
                '::-webkit-scrollbar-track': { background: palette.neutral[50] },
                '::-webkit-scrollbar-thumb': {
                    background: palette.neutral[300],
                    borderRadius: radius.pill,
                    border: `2px solid ${palette.neutral[50]}`,
                },
                '::-webkit-scrollbar-thumb:hover': { background: palette.neutral[400] },
                a: { color: text.link, textDecoration: 'none' },
                'a:hover': { textDecoration: 'underline' },
            },
        },

        MuiButton: {
            defaultProps: { disableElevation: true },
            styleOverrides: {
                root: {
                    textTransform: 'none',
                    fontWeight: 600,
                    borderRadius: radius.md,
                    padding: `${spacing[2.5]}px ${spacing[4]}px`,
                    transition: `all ${motion.fast}`,
                    '&.Mui-focusVisible': {
                        boxShadow: shadow.focus,
                    },
                },
                sizeSmall: { padding: `${spacing[1.5]}px ${spacing[3]}px`, fontSize: '0.8125rem' },
                sizeLarge: { padding: `${spacing[3]}px ${spacing[5]}px`, fontSize: '0.9375rem' },
                containedPrimary: {
                    boxShadow: 'none',
                    '&:hover': {
                        boxShadow: shadow.primaryGlow,
                        backgroundColor: palette.primary[600],
                    },
                },
                outlined: {
                    borderColor: borders.default,
                    color: text.primary,
                    backgroundColor: surfaces.card,
                    '&:hover': {
                        borderColor: borders.strong,
                        backgroundColor: palette.neutral[50],
                    },
                },
                outlinedPrimary: {
                    borderColor: palette.primary[300],
                    color: palette.primary[700],
                    '&:hover': {
                        borderColor: palette.primary[500],
                        backgroundColor: palette.primary[50],
                    },
                },
                text: {
                    color: text.primary,
                    '&:hover': { backgroundColor: palette.neutral[100] },
                },
                textPrimary: {
                    color: palette.primary[700],
                    '&:hover': { backgroundColor: palette.primary[50] },
                },
            },
        },

        MuiIconButton: {
            styleOverrides: {
                root: {
                    borderRadius: radius.md,
                    color: text.secondary,
                    transition: `all ${motion.fast}`,
                    '&:hover': { backgroundColor: palette.neutral[100], color: text.primary },
                    '&.Mui-focusVisible': { boxShadow: shadow.focus },
                },
                sizeSmall: { padding: 6 },
            },
        },

        MuiCard: {
            defaultProps: { elevation: 0 },
            styleOverrides: {
                root: {
                    borderRadius: radius.xl,
                    backgroundColor: surfaces.card,
                    border: `1px solid ${borders.subtle}`,
                    boxShadow: shadow.xs,
                    transition: `box-shadow ${motion.base}, transform ${motion.base}`,
                },
            },
        },
        MuiCardHeader: {
            styleOverrides: {
                root: { padding: `${spacing[5]}px ${spacing[6]}px ${spacing[3]}px` },
                title: { ...typography.scale.h3, color: text.strong },
                subheader: { ...typography.scale.body, color: text.secondary, marginTop: 4 },
            },
        },
        MuiCardContent: {
            styleOverrides: {
                root: {
                    padding: `${spacing[5]}px ${spacing[6]}px`,
                    '&:last-child': { paddingBottom: spacing[6] },
                },
            },
        },

        MuiPaper: {
            defaultProps: { elevation: 0 },
            styleOverrides: {
                root: { borderRadius: radius.xl, backgroundImage: 'none' },
                outlined: { borderColor: borders.subtle },
            },
        },

        MuiAppBar: {
            defaultProps: { elevation: 0, color: 'default' },
            styleOverrides: {
                root: {
                    backgroundColor: surfaces.card,
                    color: text.primary,
                    borderBottom: `1px solid ${borders.subtle}`,
                    boxShadow: 'none',
                },
            },
        },

        MuiDrawer: {
            styleOverrides: {
                paper: { border: 'none', backgroundColor: surfaces.card },
            },
        },

        MuiTextField: {
            defaultProps: { variant: 'outlined', size: 'small' },
        },
        MuiOutlinedInput: {
            styleOverrides: {
                root: {
                    borderRadius: radius.md,
                    backgroundColor: surfaces.card,
                    transition: `box-shadow ${motion.fast}, border-color ${motion.fast}`,
                    '& fieldset': { borderColor: borders.subtle },
                    '&:hover fieldset': { borderColor: borders.default },
                    '&.Mui-focused': {
                        boxShadow: shadow.focus,
                    },
                    '&.Mui-focused fieldset': { borderColor: palette.primary[500], borderWidth: 1 },
                    '&.Mui-error': { boxShadow: 'none' },
                    '&.Mui-error.Mui-focused': { boxShadow: shadow.focusDanger },
                    '&.Mui-disabled': { backgroundColor: palette.neutral[50] },
                },
                input: { padding: `${spacing[2.5]}px 14px` },
            },
        },
        MuiInputLabel: {
            styleOverrides: {
                root: { color: text.secondary, fontWeight: 500, fontSize: '0.875rem' },
            },
        },
        MuiFormHelperText: {
            styleOverrides: {
                root: { marginLeft: 0, marginTop: 6, fontSize: '0.75rem' },
            },
        },
        MuiInputAdornment: {
            styleOverrides: {
                root: { color: text.muted },
            },
        },

        MuiSelect: {
            defaultProps: { size: 'small' },
            styleOverrides: {
                select: { paddingTop: spacing[2.5], paddingBottom: spacing[2.5] },
            },
        },
        MuiMenu: {
            styleOverrides: {
                paper: {
                    borderRadius: radius.lg,
                    border: `1px solid ${borders.subtle}`,
                    boxShadow: shadow.lg,
                    marginTop: 6,
                },
                list: { padding: `${spacing[1]}px` },
            },
        },
        MuiMenuItem: {
            styleOverrides: {
                root: {
                    borderRadius: radius.sm,
                    fontSize: '0.875rem',
                    minHeight: 'auto',
                    padding: `${spacing[2]}px ${spacing[3]}px`,
                    '&:hover': { backgroundColor: palette.neutral[100] },
                    '&.Mui-selected': {
                        backgroundColor: palette.primary[50],
                        color: palette.primary[700],
                        '&:hover': { backgroundColor: palette.primary[100] },
                    },
                },
            },
        },

        MuiChip: {
            styleOverrides: {
                root: {
                    borderRadius: radius.pill,
                    fontWeight: 500,
                    fontSize: '0.75rem',
                    height: 26,
                },
                sizeSmall: { height: 22, fontSize: '0.6875rem' },
                filledDefault: {
                    backgroundColor: palette.neutral[100],
                    color: text.primary,
                },
                outlined: { borderColor: borders.subtle },
            },
        },

        MuiTooltip: {
            styleOverrides: {
                tooltip: {
                    backgroundColor: palette.neutral[900],
                    color: '#fff',
                    fontSize: '0.75rem',
                    padding: '6px 10px',
                    borderRadius: radius.sm,
                    fontWeight: 500,
                },
                arrow: { color: palette.neutral[900] },
            },
        },

        MuiDialog: {
            styleOverrides: {
                paper: {
                    borderRadius: radius.xl,
                    boxShadow: shadow.xl,
                    backgroundImage: 'none',
                },
            },
        },
        MuiDialogTitle: {
            styleOverrides: {
                root: {
                    padding: `${spacing[6]}px ${spacing[6]}px ${spacing[2]}px`,
                    fontSize: '1.125rem',
                    fontWeight: 600,
                },
            },
        },
        MuiDialogContent: {
            styleOverrides: {
                root: { padding: `${spacing[3]}px ${spacing[6]}px` },
            },
        },
        MuiDialogActions: {
            styleOverrides: {
                root: { padding: `${spacing[3]}px ${spacing[6]}px ${spacing[6]}px`, gap: 8 },
            },
        },

        MuiTable: {
            styleOverrides: {
                root: { borderCollapse: 'separate', borderSpacing: 0 },
            },
        },
        MuiTableHead: {
            styleOverrides: {
                root: {
                    '& .MuiTableCell-head': {
                        fontWeight: 600,
                        fontSize: '0.75rem',
                        textTransform: 'uppercase',
                        letterSpacing: '0.04em',
                        color: text.muted,
                        backgroundColor: palette.neutral[50],
                        borderBottom: `1px solid ${borders.subtle}`,
                    },
                },
            },
        },
        MuiTableCell: {
            styleOverrides: {
                root: {
                    borderBottom: `1px solid ${borders.subtle}`,
                    padding: `${spacing[3]}px ${spacing[4]}px`,
                    fontSize: '0.875rem',
                },
            },
        },
        MuiTableRow: {
            styleOverrides: {
                root: {
                    '&:hover': { backgroundColor: palette.neutral[50] },
                    '&:last-child .MuiTableCell-root': { borderBottom: 'none' },
                },
            },
        },

        MuiDataGrid: {
            styleOverrides: {
                root: {
                    border: `1px solid ${borders.subtle}`,
                    borderRadius: radius.xl,
                    backgroundColor: surfaces.card,
                    '--DataGrid-rowBorderColor': borders.subtle,
                    '--DataGrid-containerBackground': palette.neutral[50],
                    fontSize: '0.875rem',
                    '& .MuiDataGrid-columnHeaders': {
                        backgroundColor: palette.neutral[50],
                        borderBottom: `1px solid ${borders.subtle}`,
                    },
                    '& .MuiDataGrid-columnHeaderTitle': {
                        fontWeight: 600,
                        fontSize: '0.75rem',
                        textTransform: 'uppercase',
                        letterSpacing: '0.04em',
                        color: text.muted,
                    },
                    '& .MuiDataGrid-cell': { borderBottom: `1px solid ${borders.subtle}` },
                    '& .MuiDataGrid-row:hover': { backgroundColor: palette.neutral[50] },
                    '& .MuiDataGrid-footerContainer': { borderTop: `1px solid ${borders.subtle}` },
                    '& .MuiDataGrid-overlay': { backgroundColor: alpha(surfaces.card, 0.7) },
                },
            },
        },

        MuiTabs: {
            styleOverrides: {
                root: {
                    minHeight: 42,
                    borderBottom: `1px solid ${borders.subtle}`,
                },
                indicator: { height: 2, borderRadius: 2 },
            },
        },
        MuiTab: {
            styleOverrides: {
                root: {
                    textTransform: 'none',
                    fontWeight: 600,
                    fontSize: '0.875rem',
                    minHeight: 42,
                    padding: `${spacing[2]}px ${spacing[3]}px`,
                    color: text.secondary,
                    '&.Mui-selected': { color: palette.primary[700] },
                },
            },
        },

        MuiAlert: {
            styleOverrides: {
                root: {
                    borderRadius: radius.lg,
                    border: `1px solid transparent`,
                    padding: `${spacing[3]}px ${spacing[4]}px`,
                    alignItems: 'center',
                },
                standardSuccess: { backgroundColor: palette.success[50], color: palette.success[700], borderColor: palette.success[100] },
                standardInfo: { backgroundColor: palette.info[50], color: palette.info[700], borderColor: palette.info[100] },
                standardWarning: { backgroundColor: palette.warning[50], color: palette.warning[700], borderColor: palette.warning[100] },
                standardError: { backgroundColor: palette.danger[50], color: palette.danger[700], borderColor: palette.danger[100] },
            },
        },

        MuiDivider: {
            styleOverrides: {
                root: { borderColor: borders.subtle },
            },
        },

        MuiSwitch: {
            defaultProps: { disableRipple: false },
            styleOverrides: {
                root: {
                    width: 44,
                    height: 24,
                    padding: 0,
                    display: 'inline-flex',
                    overflow: 'visible',
                    alignItems: 'center',
                },
                switchBase: {
                    padding: 2,
                    color: '#ffffff',
                    transition: `transform ${motion.base}`,
                    '&:hover': { backgroundColor: 'transparent' },
                    '&.Mui-checked': {
                        transform: 'translateX(20px)',
                        color: '#ffffff',
                        '& + .MuiSwitch-track': {
                            opacity: 1,
                            backgroundColor: palette.primary[500],
                        },
                        '&:hover + .MuiSwitch-track': {
                            backgroundColor: palette.primary[600],
                        },
                    },
                    '&.Mui-focusVisible .MuiSwitch-thumb': {
                        boxShadow: shadow.focus,
                    },
                    '&.Mui-disabled .MuiSwitch-thumb': {
                        color: palette.neutral[100],
                    },
                    '&.Mui-disabled + .MuiSwitch-track': {
                        opacity: 0.5,
                    },
                },
                thumb: {
                    width: 20,
                    height: 20,
                    boxShadow: '0 2px 4px rgba(15, 23, 42, 0.2)',
                    backgroundColor: '#ffffff',
                    transition: `all ${motion.fast}`,
                },
                track: {
                    borderRadius: 12,
                    backgroundColor: palette.neutral[300],
                    opacity: 1,
                    transition: `background-color ${motion.base}`,
                    boxSizing: 'border-box',
                },
                sizeSmall: {
                    width: 36,
                    height: 20,
                    '& .MuiSwitch-switchBase': {
                        padding: 2,
                        '&.Mui-checked': {
                            transform: 'translateX(16px)',
                        },
                    },
                    '& .MuiSwitch-thumb': {
                        width: 16,
                        height: 16,
                    },
                    '& .MuiSwitch-track': {
                        borderRadius: 10,
                    },
                },
                colorSuccess: {
                    '&.Mui-checked + .MuiSwitch-track': { backgroundColor: palette.success[500] },
                    '&.Mui-checked:hover + .MuiSwitch-track': { backgroundColor: palette.success[600] },
                },
                colorWarning: {
                    '&.Mui-checked + .MuiSwitch-track': { backgroundColor: palette.warning[500] },
                    '&.Mui-checked:hover + .MuiSwitch-track': { backgroundColor: palette.warning[600] },
                },
                colorError: {
                    '&.Mui-checked + .MuiSwitch-track': { backgroundColor: palette.danger[500] },
                    '&.Mui-checked:hover + .MuiSwitch-track': { backgroundColor: palette.danger[600] },
                },
            },
        },

        MuiCheckbox: {
            styleOverrides: {
                root: { borderRadius: radius.sm, '&.Mui-checked': { color: palette.primary[500] } },
            },
        },

        MuiLinearProgress: {
            styleOverrides: {
                root: { borderRadius: radius.pill, backgroundColor: palette.neutral[100], height: 6 },
                bar: { borderRadius: radius.pill },
            },
        },

        MuiBreadcrumbs: {
            styleOverrides: {
                root: { fontSize: '0.8125rem', color: text.muted },
                separator: { marginLeft: 8, marginRight: 8 },
            },
        },

        MuiAvatar: {
            styleOverrides: {
                root: { fontSize: '0.875rem', fontWeight: 600 },
            },
        },

        MuiBadge: {
            styleOverrides: {
                badge: { fontWeight: 600, fontSize: '0.6875rem' },
            },
        },

        MuiListItemButton: {
            styleOverrides: {
                root: {
                    borderRadius: radius.md,
                    '&.Mui-selected': {
                        backgroundColor: palette.primary[50],
                        color: palette.primary[700],
                        '&:hover': { backgroundColor: palette.primary[100] },
                    },
                },
            },
        },

        MuiSkeleton: {
            styleOverrides: {
                root: { backgroundColor: palette.neutral[100] },
            },
        },
    },
});

const theme = buildTheme();
theme.tokens = tokens;

export default theme;
export { tokens };

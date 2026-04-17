// Design tokens for the Luma Admin portal.
// Single source of truth for colors, spacing, radius, shadow and typography.
// Mobile app uses a mirrored token set in lib/core/design_tokens/.

export const palette = {
    primary: {
        50: '#eef2ff',
        100: '#e0e7ff',
        200: '#c7d2fe',
        300: '#a5b4fc',
        400: '#818cf8',
        500: '#6366f1',
        600: '#4f46e5',
        700: '#4338ca',
        800: '#3730a3',
        900: '#312e81',
    },
    secondary: {
        50: '#fdf2f8',
        100: '#fce7f3',
        200: '#fbcfe8',
        300: '#f9a8d4',
        400: '#f472b6',
        500: '#ec4899',
        600: '#db2777',
        700: '#be185d',
        800: '#9d174d',
        900: '#831843',
    },
    success: {
        50: '#ecfdf5',
        100: '#d1fae5',
        300: '#6ee7b7',
        500: '#10b981',
        600: '#059669',
        700: '#047857',
    },
    warning: {
        50: '#fffbeb',
        100: '#fef3c7',
        300: '#fcd34d',
        500: '#f59e0b',
        600: '#d97706',
        700: '#b45309',
    },
    danger: {
        50: '#fef2f2',
        100: '#fee2e2',
        300: '#fca5a5',
        500: '#ef4444',
        600: '#dc2626',
        700: '#b91c1c',
    },
    info: {
        50: '#eff6ff',
        100: '#dbeafe',
        300: '#93c5fd',
        500: '#3b82f6',
        600: '#2563eb',
        700: '#1d4ed8',
    },
    neutral: {
        0: '#ffffff',
        50: '#f8fafc',
        100: '#f1f5f9',
        200: '#e2e8f0',
        300: '#cbd5e1',
        400: '#94a3b8',
        500: '#64748b',
        600: '#475569',
        700: '#334155',
        800: '#1e293b',
        900: '#0f172a',
    },
};

// Semantic surfaces
export const surfaces = {
    page: palette.neutral[50],
    canvas: palette.neutral[100],
    card: palette.neutral[0],
    raised: palette.neutral[0],
    sunken: palette.neutral[100],
    overlay: 'rgba(15, 23, 42, 0.55)',
    inverse: palette.neutral[900],
};

export const text = {
    strong: palette.neutral[900],
    primary: palette.neutral[800],
    secondary: palette.neutral[600],
    muted: palette.neutral[500],
    disabled: palette.neutral[400],
    inverse: palette.neutral[0],
    link: palette.primary[600],
};

export const borders = {
    subtle: palette.neutral[200],
    default: palette.neutral[300],
    strong: palette.neutral[400],
    focus: palette.primary[500],
    danger: palette.danger[500],
};

// 4-based spacing scale. Use via spacing[n] or theme.spacing(n / 4).
export const spacing = {
    0: 0,
    0.5: 2,
    1: 4,
    1.5: 6,
    2: 8,
    2.5: 10,
    3: 12,
    4: 16,
    5: 20,
    6: 24,
    7: 28,
    8: 32,
    10: 40,
    12: 48,
    14: 56,
    16: 64,
    20: 80,
    24: 96,
};

export const radius = {
    xs: 4,
    sm: 8,
    md: 10,
    lg: 12,
    xl: 16,
    '2xl': 20,
    pill: 9999,
};

export const shadow = {
    none: 'none',
    xs: '0 1px 2px 0 rgba(15, 23, 42, 0.04)',
    sm: '0 1px 2px 0 rgba(15, 23, 42, 0.05), 0 1px 3px 0 rgba(15, 23, 42, 0.06)',
    md: '0 4px 6px -1px rgba(15, 23, 42, 0.07), 0 2px 4px -2px rgba(15, 23, 42, 0.05)',
    lg: '0 10px 15px -3px rgba(15, 23, 42, 0.08), 0 4px 6px -4px rgba(15, 23, 42, 0.06)',
    xl: '0 20px 25px -5px rgba(15, 23, 42, 0.10), 0 8px 10px -6px rgba(15, 23, 42, 0.04)',
    focus: `0 0 0 4px ${palette.primary[100]}`,
    focusDanger: `0 0 0 4px ${palette.danger[100]}`,
    primaryGlow: '0 8px 24px -8px rgba(99, 102, 241, 0.45)',
};

export const gradient = {
    primary: `linear-gradient(135deg, ${palette.primary[500]} 0%, ${palette.secondary[500]} 100%)`,
    primarySoft: `linear-gradient(135deg, ${palette.primary[100]} 0%, ${palette.secondary[100]} 100%)`,
    success: `linear-gradient(135deg, ${palette.success[500]} 0%, ${palette.success[300]} 100%)`,
    danger: `linear-gradient(135deg, ${palette.danger[500]} 0%, ${palette.danger[300]} 100%)`,
    warning: `linear-gradient(135deg, ${palette.warning[500]} 0%, ${palette.warning[300]} 100%)`,
    info: `linear-gradient(135deg, ${palette.info[500]} 0%, ${palette.info[300]} 100%)`,
    sidebar: `linear-gradient(180deg, ${palette.neutral[900]} 0%, ${palette.neutral[800]} 100%)`,
};

export const typography = {
    fontFamily: '"Inter", "Roboto", "Helvetica", "Arial", sans-serif',
    fontFamilyMono: '"JetBrains Mono", "Menlo", "Monaco", monospace',
    scale: {
        display: { fontSize: '2rem', lineHeight: 1.25, fontWeight: 700, letterSpacing: '-0.02em' },
        h1: { fontSize: '1.5rem', lineHeight: 1.3, fontWeight: 700, letterSpacing: '-0.01em' },
        h2: { fontSize: '1.25rem', lineHeight: 1.35, fontWeight: 600, letterSpacing: '-0.01em' },
        h3: { fontSize: '1.125rem', lineHeight: 1.4, fontWeight: 600 },
        h4: { fontSize: '1rem', lineHeight: 1.45, fontWeight: 600 },
        h5: { fontSize: '0.9375rem', lineHeight: 1.45, fontWeight: 600 },
        h6: { fontSize: '0.875rem', lineHeight: 1.45, fontWeight: 600 },
        bodyLg: { fontSize: '1rem', lineHeight: 1.5, fontWeight: 400 },
        body: { fontSize: '0.875rem', lineHeight: 1.5, fontWeight: 400 },
        label: { fontSize: '0.8125rem', lineHeight: 1.4, fontWeight: 500 },
        caption: { fontSize: '0.75rem', lineHeight: 1.4, fontWeight: 400 },
    },
};

// Status color mapping for chips/badges/alerts
export const status = {
    success: { bg: palette.success[50], fg: palette.success[700], border: palette.success[300] },
    warning: { bg: palette.warning[50], fg: palette.warning[700], border: palette.warning[300] },
    danger: { bg: palette.danger[50], fg: palette.danger[700], border: palette.danger[300] },
    info: { bg: palette.info[50], fg: palette.info[700], border: palette.info[300] },
    primary: { bg: palette.primary[50], fg: palette.primary[700], border: palette.primary[300] },
    neutral: { bg: palette.neutral[100], fg: palette.neutral[700], border: palette.neutral[300] },
};

export const layout = {
    sidebarWidth: 260,
    sidebarCollapsedWidth: 72,
    headerHeight: 64,
    pageMaxWidth: 1440,
    contentPaddingY: spacing[6],
    contentPaddingX: { xs: spacing[4], sm: spacing[5], md: spacing[6], lg: spacing[8] },
};

export const motion = {
    fast: '150ms cubic-bezier(0.4, 0, 0.2, 1)',
    base: '200ms cubic-bezier(0.4, 0, 0.2, 1)',
    slow: '300ms cubic-bezier(0.4, 0, 0.2, 1)',
};

export const zIndex = {
    base: 0,
    dropdown: 1000,
    sticky: 1100,
    overlay: 1200,
    modal: 1300,
    popover: 1400,
    toast: 1500,
    tooltip: 1600,
};

const tokens = {
    palette,
    surfaces,
    text,
    borders,
    spacing,
    radius,
    shadow,
    gradient,
    typography,
    status,
    layout,
    motion,
    zIndex,
};

export default tokens;

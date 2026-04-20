import React from 'react';

/**
 * LUMA Aurora Mark — rounded-square aurora gradient + stylised "L" + sparkles.
 * Renders as a crisp SVG so it scales to any size.
 */
export default function LumaLogo({ size = 44, title = 'LUMA', style }) {
    const id = React.useId();
    return (
        <svg
            width={size}
            height={size}
            viewBox="0 0 512 512"
            role="img"
            aria-label={title}
            style={{ display: 'block', flexShrink: 0, ...style }}
        >
            <defs>
                <linearGradient id={`${id}-bg`} x1="0" y1="0" x2="1" y2="1">
                    <stop offset="0%" stopColor="#6366F1" />
                    <stop offset="55%" stopColor="#8B5CF6" />
                    <stop offset="100%" stopColor="#EC4899" />
                </linearGradient>
                <radialGradient id={`${id}-glow`} cx="0.72" cy="0.22" r="0.55">
                    <stop offset="0%" stopColor="#FFFFFF" stopOpacity="0.32" />
                    <stop offset="70%" stopColor="#FFFFFF" stopOpacity="0" />
                </radialGradient>
            </defs>
            <rect x="16" y="16" width="480" height="480" rx="120" ry="120" fill={`url(#${id}-bg)`} />
            <rect x="16" y="16" width="480" height="480" rx="120" ry="120" fill={`url(#${id}-glow)`} />
            {/* Stylised "L" — two capsule strokes. */}
            <rect x="144" y="96" width="64" height="308" rx="32" fill="#FFFFFF" />
            <rect x="144" y="340" width="248" height="64" rx="32" fill="#FFFFFF" />
            {/* Main sparkle. */}
            <g transform="translate(372 148)">
                <path d="M0 -50 L13 -13 L50 0 L13 13 L0 50 L-13 13 L-50 0 L-13 -13 Z" fill="#FFFFFF" />
                <circle r="9" fill="#FFFFFF" />
            </g>
            {/* Small accent sparkle. */}
            <g transform="translate(312 88)">
                <path d="M0 -20 L5 -5 L20 0 L5 5 L0 20 L-5 5 L-20 0 L-5 -5 Z" fill="#FFFFFF" />
            </g>
        </svg>
    );
}

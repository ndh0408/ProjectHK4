import React from 'react';
import { Box, Skeleton, Stack } from '@mui/material';

const SkeletonTable = ({ rows = 6, cols = 5 }) => (
    <Stack spacing={1.25}>
        <Skeleton variant="rounded" height={36} sx={{ bgcolor: 'grey.100' }} />
        {Array.from({ length: rows }).map((_, rowIdx) => (
            <Box
                key={rowIdx}
                sx={{
                    display: 'grid',
                    gridTemplateColumns: `repeat(${cols}, 1fr)`,
                    gap: 1.5,
                    alignItems: 'center',
                }}
            >
                {Array.from({ length: cols }).map((__, colIdx) => (
                    <Skeleton
                        key={colIdx}
                        variant="rounded"
                        height={22}
                        width={colIdx === 0 ? '70%' : '90%'}
                    />
                ))}
            </Box>
        ))}
    </Stack>
);

export default SkeletonTable;

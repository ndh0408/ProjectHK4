import React from 'react';
import { Card, CardContent, Skeleton, Stack } from '@mui/material';

const SkeletonCard = ({ lines = 3, height = 140, showMedia = false }) => (
    <Card>
        {showMedia && (
            <Skeleton variant="rectangular" height={height} sx={{ bgcolor: 'grey.100' }} />
        )}
        <CardContent>
            <Stack spacing={1.25}>
                <Skeleton variant="text" width="40%" height={22} />
                {Array.from({ length: lines }).map((_, i) => (
                    <Skeleton key={i} variant="text" width={i === lines - 1 ? '55%' : '100%'} />
                ))}
            </Stack>
        </CardContent>
    </Card>
);

export default SkeletonCard;

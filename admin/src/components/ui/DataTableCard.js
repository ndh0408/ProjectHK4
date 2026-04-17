import React from 'react';
import { Card, CardContent, Box } from '@mui/material';
import { DataGrid } from '@mui/x-data-grid';
import EmptyState from './EmptyState';
import SkeletonTable from './SkeletonTable';

/**
 * DataGrid wrapper with built-in skeleton while loading, empty state placeholder,
 * and consistent card framing. Accepts all DataGrid props via `dataGridProps`.
 */
const DataTableCard = ({
    rows = [],
    columns = [],
    loading = false,
    emptyTitle = 'No records yet',
    emptyDescription,
    emptyIcon,
    emptyAction,
    minHeight = 440,
    toolbar,
    footer,
    dataGridProps = {},
    cardSx,
}) => {
    const isInitialLoad = loading && rows.length === 0;
    const isEmpty = !loading && rows.length === 0;

    return (
        <Card sx={{ overflow: 'hidden', ...cardSx }}>
            {toolbar && (
                <Box sx={{ px: 2.5, pt: 2.5 }}>{toolbar}</Box>
            )}
            {isInitialLoad ? (
                <CardContent sx={{ minHeight }}>
                    <SkeletonTable rows={6} cols={Math.min(columns.length || 5, 6)} />
                </CardContent>
            ) : isEmpty ? (
                <Box sx={{ minHeight }}>
                    <EmptyState
                        title={emptyTitle}
                        description={emptyDescription}
                        icon={emptyIcon}
                        action={emptyAction}
                    />
                </Box>
            ) : (
                <Box sx={{ width: '100%' }}>
                    <DataGrid
                        autoHeight
                        disableRowSelectionOnClick
                        rowHeight={54}
                        columnHeaderHeight={48}
                        pageSizeOptions={[10, 25, 50]}
                        rows={rows}
                        columns={columns}
                        loading={loading}
                        {...dataGridProps}
                        sx={{
                            border: 'none',
                            borderRadius: 0,
                            '& .MuiDataGrid-columnSeparator': { display: 'none' },
                            ...(dataGridProps.sx || {}),
                        }}
                    />
                </Box>
            )}
            {footer && <Box sx={{ p: 2, borderTop: '1px solid', borderColor: 'divider' }}>{footer}</Box>}
        </Card>
    );
};

export default DataTableCard;

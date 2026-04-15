-- Fix NULL values in polls table boolean columns
-- Run this before restarting the application after the entity changes

-- Update polls with NULL values to FALSE (0)
UPDATE polls
SET auto_open_event_start = 0
WHERE auto_open_event_start IS NULL;

UPDATE polls
SET auto_close_event_end = 0
WHERE auto_close_event_end IS NULL;

UPDATE polls
SET auto_close_ten_days_after_event_end = 0
WHERE auto_close_ten_days_after_event_end IS NULL;

UPDATE polls
SET hide_results_until_closed = 0
WHERE hide_results_until_closed IS NULL;

-- Verify no NULL values remain
SELECT COUNT(*) as remaining_null_polls
FROM polls
WHERE auto_open_event_start IS NULL
   OR auto_close_event_end IS NULL
   OR auto_close_ten_days_after_event_end IS NULL
   OR hide_results_until_closed IS NULL;

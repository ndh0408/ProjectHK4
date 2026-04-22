USE luma_db;
GO

-- Preview duplicates
SELECT 'Duplicates found:' AS step, event_id, COUNT(*) AS active_count
FROM event_boosts
WHERE status='ACTIVE'
GROUP BY event_id
HAVING COUNT(*) > 1;

-- Expire duplicates — keep the highest tier, tie-break by earliest created_at
WITH ranked AS (
    SELECT id, event_id, boost_package, created_at,
           ROW_NUMBER() OVER (
               PARTITION BY event_id
               ORDER BY
                   CASE boost_package
                       WHEN 'VIP' THEN 0
                       WHEN 'PREMIUM' THEN 1
                       WHEN 'STANDARD' THEN 2
                       WHEN 'BASIC' THEN 3
                       ELSE 4
                   END,
                   created_at ASC
           ) AS rn
    FROM event_boosts
    WHERE status='ACTIVE'
)
UPDATE eb
SET eb.status = 'EXPIRED',
    eb.end_time = SYSUTCDATETIME()
FROM event_boosts eb
JOIN ranked r ON r.id = eb.id
WHERE r.rn > 1;

-- Safety net: filtered unique index so the DB itself rejects any second ACTIVE boost
-- on the same event. Even if two webhooks race in parallel transactions, one will
-- fail with a unique-violation and the bug becomes impossible at data-layer level.
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name='UQ_event_boosts_one_active_per_event' AND object_id=OBJECT_ID('dbo.event_boosts')
)
BEGIN
    CREATE UNIQUE INDEX UQ_event_boosts_one_active_per_event
        ON dbo.event_boosts(event_id)
        WHERE status='ACTIVE';
    PRINT 'Created UQ_event_boosts_one_active_per_event';
END
ELSE
    PRINT 'Unique index already exists';
GO

-- Report
SELECT e.title, eb.boost_package, eb.status
FROM event_boosts eb
JOIN events e ON e.id = eb.event_id
WHERE eb.status='ACTIVE'
ORDER BY e.title;
GO

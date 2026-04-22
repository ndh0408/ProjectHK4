USE luma_db;
GO

-- Preview: events with more than 1 ACTIVE boost
SELECT event_id, COUNT(*) AS active_count
FROM event_boosts
WHERE status='ACTIVE'
GROUP BY event_id
HAVING COUNT(*) > 1;

-- For each event with duplicate ACTIVE boosts, keep the one with the highest boost_package,
-- then earliest created_at as tie-breaker. Expire the others.
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

-- Report
SELECT 'After cleanup - active boosts per event' AS step;
SELECT e.title, COUNT(*) AS active_count
FROM event_boosts eb
JOIN events e ON e.id = eb.event_id
WHERE eb.status='ACTIVE'
GROUP BY e.title
ORDER BY active_count DESC, e.title;
GO

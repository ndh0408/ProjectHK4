USE luma_db;
GO

-- Preview first
SELECT 'Before - active boosts' AS step, COUNT(*) AS cnt FROM event_boosts WHERE status='ACTIVE' AND end_time > GETDATE();

DECLARE @now DATETIME2 = SYSUTCDATETIME();
DECLARE @vipEnd DATETIME2 = DATEADD(DAY, 30, @now);
DECLARE @premiumEnd DATETIME2 = DATEADD(DAY, 30, @now);
DECLARE @standardEnd DATETIME2 = DATEADD(DAY, 14, @now);
DECLARE @basicEnd DATETIME2 = DATEADD(DAY, 7, @now);

-- Seed 4 active boosts across the top upcoming events (one per package tier)
-- VIP → shows in VIP banner carousel + Boosted
-- PREMIUM/STANDARD/BASIC → show in Boosted section
INSERT INTO event_boosts (
    id, event_id, organiser_id, boost_package, amount, status,
    start_time, end_time, paid_at,
    clicks_before_boost, clicks_during_boost,
    registrations_before_boost, registrations_during_boost,
    views_before_boost, views_during_boost,
    created_at, updated_at
)
SELECT NEWID(), e.id, e.organiser_id,
       CASE rn
           WHEN 1 THEN 'VIP'
           WHEN 2 THEN 'PREMIUM'
           WHEN 3 THEN 'STANDARD'
           WHEN 4 THEN 'BASIC'
       END,
       CASE rn
           WHEN 1 THEN 99.99
           WHEN 2 THEN 49.99
           WHEN 3 THEN 24.99
           WHEN 4 THEN 9.99
       END,
       'ACTIVE',
       @now,
       CASE rn
           WHEN 1 THEN @vipEnd
           WHEN 2 THEN @premiumEnd
           WHEN 3 THEN @standardEnd
           WHEN 4 THEN @basicEnd
       END,
       @now,
       0, 0, 0, 0, 0, 0,
       @now, @now
FROM (
    SELECT TOP 4 id, organiser_id,
           ROW_NUMBER() OVER (ORDER BY start_time ASC) AS rn
    FROM events
    WHERE status='PUBLISHED' AND start_time > GETDATE() AND deleted=0
      AND id NOT IN (SELECT event_id FROM event_boosts WHERE status='ACTIVE' AND end_time > GETDATE())
) e;

SELECT 'After - active boosts' AS step, COUNT(*) AS cnt FROM event_boosts WHERE status='ACTIVE' AND end_time > GETDATE();
SELECT eb.boost_package, e.title, eb.end_time
  FROM event_boosts eb JOIN events e ON e.id = eb.event_id
 WHERE eb.status='ACTIVE' AND eb.end_time > GETDATE();
GO

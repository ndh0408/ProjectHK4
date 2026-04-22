USE luma_db;
GO

-- 1) Add missing cities (15, 16, 17) that were in backup but not in fresh seed
SET IDENTITY_INSERT cities ON;

INSERT INTO cities (id, name, continent, country, active)
SELECT o.id, o.name, o.continent, o.country, ISNULL(o.active, 1)
FROM luma_db_old.dbo.cities o
WHERE o.id NOT IN (SELECT id FROM cities);

SET IDENTITY_INSERT cities OFF;
GO

-- 2) Restore event.city_id from old backup for events that still exist
UPDATE e
SET e.city_id = o.city_id
FROM luma_db.dbo.events e
INNER JOIN luma_db_old.dbo.events o ON e.id = o.id
WHERE o.city_id IS NOT NULL
  AND e.city_id IS NULL;
GO

-- 3) Report
SELECT 'cities_total' AS metric, COUNT(*) AS val FROM cities
UNION ALL SELECT 'events_with_city', COUNT(*) FROM events WHERE city_id IS NOT NULL
UNION ALL SELECT 'events_without_city', COUNT(*) FROM events WHERE city_id IS NULL
UNION ALL SELECT 'orphan_events', COUNT(*) FROM events e WHERE e.city_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM cities c WHERE c.id = e.city_id);
GO

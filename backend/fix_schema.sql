USE luma_db;
GO

-- Fix 1: Drop old unique index(es) on users.phone that block ALTER COLUMN
DECLARE @idxName NVARCHAR(256);
DECLARE idx_cursor CURSOR FOR
    SELECT DISTINCT i.name
    FROM sys.indexes i
    JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
    WHERE i.object_id = OBJECT_ID('dbo.users')
      AND c.name = 'phone'
      AND i.is_unique = 1
      AND i.is_primary_key = 0;

OPEN idx_cursor;
FETCH NEXT FROM idx_cursor INTO @idxName;
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @sql NVARCHAR(512) = 'DROP INDEX [' + @idxName + '] ON dbo.users';
    PRINT 'Dropping index: ' + @idxName;
    EXEC sp_executesql @sql;
    FETCH NEXT FROM idx_cursor INTO @idxName;
END
CLOSE idx_cursor;
DEALLOCATE idx_cursor;
GO

-- Fix 2: Clear orphan city_id in events (rows that point to non-existent cities)
DECLARE @orphanCount INT;
SELECT @orphanCount = COUNT(*) FROM events
 WHERE city_id IS NOT NULL AND city_id NOT IN (SELECT id FROM cities);
PRINT 'Orphan events with invalid city_id: ' + CAST(@orphanCount AS NVARCHAR(10));

UPDATE events SET city_id = NULL
WHERE city_id IS NOT NULL
  AND city_id NOT IN (SELECT id FROM cities);
GO

PRINT 'Schema fix completed.';
GO

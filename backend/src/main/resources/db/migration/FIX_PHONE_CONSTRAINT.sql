-- Script to drop unique constraint on phone column
-- Run this manually in SQL Server Management Studio or Azure Data Studio

DECLARE @constraint_name NVARCHAR(256);
DECLARE @sql NVARCHAR(500);

-- Find the unique constraint name for phone column
SELECT @constraint_name = ic.name
FROM sys.index_columns ic
JOIN sys.indexes i ON ic.object_id = i.object_id AND ic.index_id = i.index_id
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
JOIN sys.tables t ON ic.object_id = t.object_id
WHERE t.name = 'users'
  AND c.name = 'phone'
  AND i.is_unique = 1;

-- Drop the constraint if it exists
IF @constraint_name IS NOT NULL
BEGIN
    SET @sql = 'ALTER TABLE users DROP CONSTRAINT ' + @constraint_name;
    PRINT 'Executing: ' + @sql;
    EXEC sp_executesql @sql;
    PRINT 'Successfully dropped constraint: ' + @constraint_name;
END
ELSE
BEGIN
    PRINT 'No unique constraint found on phone column in users table';
END

-- Verify the constraint was dropped
SELECT
    CONSTRAINT_NAME,
    CONSTRAINT_TYPE
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE TABLE_NAME = 'users'
  AND CONSTRAINT_TYPE = 'UNIQUE';

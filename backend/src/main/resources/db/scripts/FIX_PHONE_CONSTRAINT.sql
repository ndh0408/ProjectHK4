-- =============================================
-- Fix: Drop unique constraint on phone column
-- =============================================
-- Run this script in SQL Server Management Studio or Azure Data Studio
-- against the luma_db database.

USE luma_db;
GO

DECLARE @constraint_name NVARCHAR(256) = NULL;
DECLARE @sql NVARCHAR(500);

-- Find unique constraint on phone column in users table
SELECT @constraint_name = name
FROM sys.unique_constraints
WHERE parent_object_id = OBJECT_ID('dbo.users', 'U');

-- Alternative: search via indexes
IF @constraint_name IS NULL
BEGIN
    SELECT @constraint_name = i.name
    FROM sys.indexes i
    JOIN sys.tables t ON i.object_id = t.object_id
    JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
    WHERE t.name = 'users'
      AND c.name = 'phone'
      AND i.is_unique = 1;
END

-- Drop the constraint if found
IF @constraint_name IS NOT NULL
BEGIN
    SET @sql = 'ALTER TABLE users DROP CONSTRAINT ' + @constraint_name;
    PRINT 'Dropping constraint: ' + @constraint_name;
    EXEC sp_executesql @sql;
    PRINT 'SUCCESS: Dropped constraint ' + @constraint_name;
END
ELSE
BEGIN
    PRINT 'INFO: No unique constraint found on phone column';
END
GO

-- Verify: list remaining constraints on users table
PRINT 'Remaining constraints on users table:';
SELECT
    CONSTRAINT_NAME,
    CONSTRAINT_TYPE,
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE TABLE_NAME = 'users';
GO

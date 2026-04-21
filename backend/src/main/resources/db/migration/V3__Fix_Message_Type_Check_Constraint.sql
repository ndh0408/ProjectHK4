-- Fix: CHECK constraint on messages.type was created before POLL was
-- added to the MessageType enum, so posting a poll message hits
-- CK__messages__type__XXXXXXXX. Same pattern as V2 for polls.status.
-- Safe to re-run.

DECLARE @constraint_name sysname;
SELECT @constraint_name = cc.name
FROM sys.check_constraints cc
INNER JOIN sys.columns c
    ON c.object_id = cc.parent_object_id
    AND c.column_id = cc.parent_column_id
WHERE cc.parent_object_id = OBJECT_ID('dbo.messages')
  AND c.name = 'type';

IF @constraint_name IS NOT NULL
BEGIN
    DECLARE @sql nvarchar(max) = N'ALTER TABLE dbo.messages DROP CONSTRAINT ' + QUOTENAME(@constraint_name);
    EXEC sp_executesql @sql;
END

IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = 'CK_messages_type' AND parent_object_id = OBJECT_ID('dbo.messages')
)
BEGIN
    ALTER TABLE dbo.messages
    ADD CONSTRAINT CK_messages_type
    CHECK (type IN ('TEXT', 'IMAGE', 'FILE', 'SYSTEM', 'POLL'));
END

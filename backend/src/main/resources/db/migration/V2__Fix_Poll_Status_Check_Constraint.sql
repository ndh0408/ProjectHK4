-- Fix: old auto-generated CHECK constraint on polls.status only whitelists
-- the original enum values (DRAFT, ACTIVE, CLOSED). The enum has since
-- grown to include SCHEDULED and CANCELLED, but Hibernate's ddl-auto=update
-- does NOT rewrite existing CHECK constraints — so INSERTs with status =
-- 'SCHEDULED' fail with CK__polls__status__XXXXXXXX violation.
--
-- Run this ONCE against the luma_db database (SQL Server syntax). Safe to
-- re-run: drop is conditional, re-add uses a stable name we control.

-- 1) Drop the legacy auto-named CHECK constraint on polls.status (if any).
DECLARE @constraint_name sysname;
SELECT @constraint_name = cc.name
FROM sys.check_constraints cc
INNER JOIN sys.columns c
    ON c.object_id = cc.parent_object_id
    AND c.column_id = cc.parent_column_id
WHERE cc.parent_object_id = OBJECT_ID('dbo.polls')
  AND c.name = 'status';

IF @constraint_name IS NOT NULL
BEGIN
    DECLARE @sql nvarchar(max) = N'ALTER TABLE dbo.polls DROP CONSTRAINT ' + QUOTENAME(@constraint_name);
    EXEC sp_executesql @sql;
END

-- 2) Re-add a named CHECK constraint with the full current enum.
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = 'CK_polls_status' AND parent_object_id = OBJECT_ID('dbo.polls')
)
BEGIN
    ALTER TABLE dbo.polls
    ADD CONSTRAINT CK_polls_status
    CHECK (status IN ('DRAFT', 'SCHEDULED', 'ACTIVE', 'CLOSED', 'CANCELLED'));
END

-- Fix CHECK constraint to allow 'GROUP' type for custom group chats
-- Run this script on your SQL Server database (luma_db)

-- Step 1: Drop the existing CHECK constraint
ALTER TABLE conversations DROP CONSTRAINT CK__conversati__type__2B0A656D;

-- Step 2: Add new CHECK constraint that includes 'GROUP'
ALTER TABLE conversations
ADD CONSTRAINT CK_conversations_type
CHECK (type IN ('EVENT_GROUP', 'DIRECT', 'GROUP'));

-- Verify the constraint
SELECT name, definition
FROM sys.check_constraints
WHERE parent_object_id = OBJECT_ID('conversations');

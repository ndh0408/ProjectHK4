-- Chat moderation additions:
--   • conversations.pinned_message_id / pinned_at / pinned_by_user_id —
--     backs the "announcement pinned to top" feature. Only organisers can
--     pin in EVENT_GROUP chats; null = no announcement.
--   • conversation_participants.banned_at / muted_until — moderation knobs
--     for organisers to silence or remove a disruptive attendee from an
--     event group chat without deleting them from the event itself.
--
-- Idempotent: checks column existence before adding. Safe to re-run.

-- Conversations: pin support
IF COL_LENGTH('dbo.conversations', 'pinned_message_id') IS NULL
BEGIN
    ALTER TABLE dbo.conversations ADD pinned_message_id UNIQUEIDENTIFIER NULL;
END

IF COL_LENGTH('dbo.conversations', 'pinned_at') IS NULL
BEGIN
    ALTER TABLE dbo.conversations ADD pinned_at DATETIME2 NULL;
END

IF COL_LENGTH('dbo.conversations', 'pinned_by_user_id') IS NULL
BEGIN
    ALTER TABLE dbo.conversations ADD pinned_by_user_id UNIQUEIDENTIFIER NULL;
END

-- FKs for pinned_message_id / pinned_by_user_id. Use NO ACTION so pinning a
-- message that later gets deleted just leaves a dangling pin (pick up
-- by scheduled cleanup or next pin action) rather than cascading deletes
-- that could orphan the conversation.
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_conversations_pinned_message'
)
BEGIN
    ALTER TABLE dbo.conversations
    ADD CONSTRAINT FK_conversations_pinned_message
    FOREIGN KEY (pinned_message_id) REFERENCES dbo.messages(id);
END

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_conversations_pinned_by_user'
)
BEGIN
    ALTER TABLE dbo.conversations
    ADD CONSTRAINT FK_conversations_pinned_by_user
    FOREIGN KEY (pinned_by_user_id) REFERENCES dbo.users(id);
END

-- Participants: ban + mute support
IF COL_LENGTH('dbo.conversation_participants', 'banned_at') IS NULL
BEGIN
    ALTER TABLE dbo.conversation_participants ADD banned_at DATETIME2 NULL;
END

IF COL_LENGTH('dbo.conversation_participants', 'muted_until') IS NULL
BEGIN
    ALTER TABLE dbo.conversation_participants ADD muted_until DATETIME2 NULL;
END

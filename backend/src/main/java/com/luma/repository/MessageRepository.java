package com.luma.repository;

import com.luma.entity.Conversation;
import com.luma.entity.Message;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface MessageRepository extends JpaRepository<Message, UUID> {

    @Query("SELECT m FROM Message m WHERE m.conversation = :conversation ORDER BY m.createdAt DESC")
    Page<Message> findByConversation(@Param("conversation") Conversation conversation, Pageable pageable);

    @Query("SELECT m FROM Message m WHERE m.conversation = :conversation ORDER BY m.createdAt DESC")
    Page<Message> findLatestMessage(@Param("conversation") Conversation conversation, Pageable pageable);

    /// Full-text-ish search over chat history. Matches on lower-cased
    /// message content against a lower-cased query fragment; skips deleted
    /// and non-text system/image/poll messages (they have no readable body
    /// worth searching). Sort newest first so the UI shows recent matches.
    @Query("SELECT m FROM Message m " +
           "WHERE m.conversation = :conversation " +
           "AND m.deleted = false " +
           "AND m.content IS NOT NULL " +
           "AND LOWER(m.content) LIKE CONCAT('%', :query, '%') " +
           "ORDER BY m.createdAt DESC")
    Page<Message> searchByConversation(
            @Param("conversation") Conversation conversation,
            @Param("query") String query,
            Pageable pageable);

    long countByConversationAndDeletedFalse(Conversation conversation);

    void deleteByConversation(Conversation conversation);
}

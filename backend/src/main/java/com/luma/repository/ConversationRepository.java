package com.luma.repository;

import com.luma.entity.Conversation;
import com.luma.entity.Event;
import com.luma.entity.User;
import com.luma.entity.enums.ConversationType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface ConversationRepository extends JpaRepository<Conversation, UUID> {

    Optional<Conversation> findByEventAndType(Event event, ConversationType type);

    @Query("SELECT c FROM Conversation c " +
           "JOIN c.participants p " +
           "WHERE p.user = :user AND p.archived = false " +
           "ORDER BY p.pinned DESC, c.lastMessageAt DESC NULLS LAST")
    Page<Conversation> findByUser(@Param("user") User user, Pageable pageable);

    @Query("SELECT c FROM Conversation c " +
           "JOIN c.participants p " +
           "WHERE p.user = :user AND p.archived = true " +
           "ORDER BY c.lastMessageAt DESC NULLS LAST")
    Page<Conversation> findArchivedByUser(@Param("user") User user, Pageable pageable);

    @Query("SELECT c FROM Conversation c " +
           "WHERE c.type = 'DIRECT' " +
           "AND EXISTS (SELECT p1 FROM ConversationParticipant p1 WHERE p1.conversation = c AND p1.user = :user1) " +
           "AND EXISTS (SELECT p2 FROM ConversationParticipant p2 WHERE p2.conversation = c AND p2.user = :user2)")
    Optional<Conversation> findDirectConversation(@Param("user1") User user1, @Param("user2") User user2);

    @Query("SELECT COUNT(DISTINCT c) FROM Conversation c " +
           "JOIN c.participants p " +
           "WHERE p.user = :user AND p.unreadCount > 0")
    long countUnreadConversations(@Param("user") User user);

    @Query("SELECT c FROM Conversation c " +
           "JOIN c.participants p " +
           "WHERE p.user = :user AND c.type = :type " +
           "ORDER BY c.lastMessageAt DESC NULLS LAST")
    Page<Conversation> findByUserAndType(@Param("user") User user, @Param("type") ConversationType type, Pageable pageable);

    @Query("SELECT c FROM Conversation c " +
           "WHERE c.type = 'EVENT_GROUP' " +
           "AND c.closedAt IS NULL " +
           "AND c.event.endTime < :cutoff")
    java.util.List<Conversation> findEventGroupsToClose(@Param("cutoff") java.time.LocalDateTime cutoff);
}

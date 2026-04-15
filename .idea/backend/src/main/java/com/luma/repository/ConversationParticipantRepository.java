package com.luma.repository;

import com.luma.entity.Conversation;
import com.luma.entity.ConversationParticipant;
import com.luma.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ConversationParticipantRepository extends JpaRepository<ConversationParticipant, UUID> {

    Optional<ConversationParticipant> findByConversationAndUser(Conversation conversation, User user);

    List<ConversationParticipant> findByConversation(Conversation conversation);

    boolean existsByConversationAndUser(Conversation conversation, User user);

    @Modifying
    @Query("UPDATE ConversationParticipant p SET p.unreadCount = p.unreadCount + 1 " +
           "WHERE p.conversation = :conversation AND p.user != :sender")
    void incrementUnreadCountExceptSender(@Param("conversation") Conversation conversation, @Param("sender") User sender);

    @Modifying
    @Query("UPDATE ConversationParticipant p SET p.unreadCount = 0, p.lastReadAt = :now " +
           "WHERE p.conversation = :conversation AND p.user = :user")
    void markAsRead(@Param("conversation") Conversation conversation, @Param("user") User user, @Param("now") LocalDateTime now);

    @Query("SELECT COALESCE(SUM(p.unreadCount), 0) FROM ConversationParticipant p WHERE p.user = :user")
    long getTotalUnreadCount(@Param("user") User user);

    long countByConversation(Conversation conversation);
}

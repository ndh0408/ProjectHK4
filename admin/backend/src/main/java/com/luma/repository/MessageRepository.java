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

    long countByConversationAndDeletedFalse(Conversation conversation);

    void deleteByConversation(Conversation conversation);
}

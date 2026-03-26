package com.luma.service;

import com.luma.dto.response.MessageResponse;
import com.luma.dto.websocket.ChatMessageEvent;
import com.luma.entity.Conversation;
import com.luma.entity.ConversationParticipant;
import com.luma.repository.ConversationParticipantRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class ChatWebSocketService {

    private final SimpMessagingTemplate messagingTemplate;
    private final ConversationParticipantRepository participantRepository;

    public void broadcastNewMessage(Conversation conversation, MessageResponse message) {
        ChatMessageEvent event = ChatMessageEvent.builder()
                .type(ChatMessageEvent.EventType.NEW_MESSAGE)
                .conversationId(conversation.getId())
                .message(message)
                .build();

        messagingTemplate.convertAndSend(
                "/topic/conversation." + conversation.getId(),
                event
        );

        List<ConversationParticipant> participants = participantRepository.findByConversation(conversation);
        for (ConversationParticipant participant : participants) {
            if (!participant.getUser().getId().equals(message.getSender().getId())) {
                messagingTemplate.convertAndSendToUser(
                        participant.getUser().getEmail(),
                        "/queue/messages",
                        event
                );
            }
        }

        log.debug("Broadcasted new message to conversation: {}", conversation.getId());
    }

    public void broadcastMessageDeleted(UUID conversationId, UUID messageId) {
        ChatMessageEvent event = ChatMessageEvent.builder()
                .type(ChatMessageEvent.EventType.MESSAGE_DELETED)
                .conversationId(conversationId)
                .message(MessageResponse.builder().id(messageId).build())
                .build();

        messagingTemplate.convertAndSend(
                "/topic/conversation." + conversationId,
                event
        );

        log.debug("Broadcasted message deleted: {} in conversation: {}", messageId, conversationId);
    }

    public void broadcastTyping(UUID conversationId, UUID userId, String userName) {
        ChatMessageEvent event = ChatMessageEvent.builder()
                .type(ChatMessageEvent.EventType.TYPING)
                .conversationId(conversationId)
                .userId(userId)
                .userName(userName)
                .build();

        messagingTemplate.convertAndSend(
                "/topic/conversation." + conversationId,
                event
        );
    }

    public void broadcastRead(UUID conversationId, UUID userId) {
        ChatMessageEvent event = ChatMessageEvent.builder()
                .type(ChatMessageEvent.EventType.READ)
                .conversationId(conversationId)
                .userId(userId)
                .build();

        messagingTemplate.convertAndSend(
                "/topic/conversation." + conversationId,
                event
        );
    }
}

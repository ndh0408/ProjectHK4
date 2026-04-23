package com.luma.dto.websocket;

import com.luma.dto.response.MessageResponse;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ChatMessageEvent {

    public enum EventType {
        NEW_MESSAGE,
        MESSAGE_DELETED,
        PINNED_MESSAGE_UPDATED,
        TYPING,
        READ,
        ONLINE,
        OFFLINE
    }

    private EventType type;
    private UUID conversationId;
    private MessageResponse message;
    private UUID userId;
    private String userName;
    private Boolean isOnline;
    private java.time.Instant lastSeen;
}

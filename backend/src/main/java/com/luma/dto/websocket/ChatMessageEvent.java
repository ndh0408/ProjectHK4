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
        TYPING,
        READ
    }

    private EventType type;
    private UUID conversationId;
    private MessageResponse message;
    private UUID userId; // For typing indicator
    private String userName; // For typing indicator
}

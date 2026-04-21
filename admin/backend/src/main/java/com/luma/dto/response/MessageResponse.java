package com.luma.dto.response;

import com.luma.entity.Message;
import com.luma.entity.enums.MessageType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MessageResponse {

    private UUID id;
    private UUID conversationId;
    private MessageType type;
    private String content;
    private String mediaUrl;
    private SenderResponse sender;
    private ReplyResponse replyTo;
    private LocalDateTime createdAt;
    private LocalDateTime editedAt;
    private boolean deleted;
    private String deletedByName;
    private LocalDateTime deletedAt;
    private String senderRole;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SenderResponse {
        private UUID id;
        private String fullName;
        private String avatarUrl;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ReplyResponse {
        private UUID id;
        private String content;
        private String senderName;
    }

    public static MessageResponse fromEntity(Message message) {
        MessageResponseBuilder builder = MessageResponse.builder()
                .id(message.getId())
                .conversationId(message.getConversation().getId())
                .type(message.getType())
                .content(message.getContent())
                .mediaUrl(message.getMediaUrl())
                .createdAt(message.getCreatedAt())
                .editedAt(message.getEditedAt())
                .deleted(message.isDeleted())
                .deletedByName(message.getDeletedBy() != null ? message.getDeletedBy().getFullName() : null)
                .deletedAt(message.getDeletedAt())
                .senderRole(resolveSenderRole(message));

        if (message.getSender() != null) {
            builder.sender(SenderResponse.builder()
                    .id(message.getSender().getId())
                    .fullName(message.getSender().getFullName())
                    .avatarUrl(message.getSender().getAvatarUrl())
                    .build());
        }

        if (message.getReplyTo() != null) {
            builder.replyTo(ReplyResponse.builder()
                    .id(message.getReplyTo().getId())
                    .content(message.getReplyTo().getContent())
                    .senderName(message.getReplyTo().getSender().getFullName())
                    .build());
        }

        return builder.build();
    }

    private static String resolveSenderRole(Message message) {
        if (message.getSender() == null || message.getConversation() == null) {
            return "ATTENDEE";
        }
        var conversation = message.getConversation();
        if (conversation.getEvent() == null || conversation.getEvent().getOrganiser() == null) {
            return "ATTENDEE";
        }
        UUID organiserId = conversation.getEvent().getOrganiser().getId();
        return organiserId.equals(message.getSender().getId()) ? "ORGANISER" : "ATTENDEE";
    }
}

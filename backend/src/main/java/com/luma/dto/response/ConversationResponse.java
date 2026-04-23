package com.luma.dto.response;

import com.luma.entity.Conversation;
import com.luma.entity.ConversationParticipant;
import com.luma.entity.enums.ConversationType;
import com.luma.util.UserImageResolver;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ConversationResponse {

    private UUID id;
    private ConversationType type;
    private String name;
    private String imageUrl;
    private UUID eventId;
    private String eventTitle;
    private String lastMessageContent;
    private LocalDateTime lastMessageAt;
    private int unreadCount;
    private boolean muted;
    private boolean pinned;
    private boolean archived;
    private List<ParticipantResponse> participants;
    private int participantCount;
    private LocalDateTime closedAt;
    private LocalDateTime createdAt;

    // Pinned announcement (organiser only). Null when nothing is pinned.
    private PinnedMessageResponse pinnedMessage;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class PinnedMessageResponse {
        private UUID id;
        private String content;
        private String senderName;
        private LocalDateTime createdAt;
        private LocalDateTime pinnedAt;
        private UUID pinnedByUserId;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ParticipantResponse {
        private UUID userId;
        private String fullName;
        private String avatarUrl;
        // When this participant last marked the conversation as read. Mobile
        // uses it to render sent/read checkmarks on own messages (✓ vs ✓✓).
        private LocalDateTime lastReadAt;
    }

    public static ConversationResponse fromEntity(Conversation conversation, ConversationParticipant currentUserParticipant) {
        ConversationResponseBuilder builder = ConversationResponse.builder()
                .id(conversation.getId())
                .type(conversation.getType())
                .name(conversation.getName())
                .imageUrl(conversation.getImageUrl())
                .lastMessageContent(conversation.getLastMessageContent())
                .lastMessageAt(conversation.getLastMessageAt())
                .closedAt(conversation.getClosedAt())
                .createdAt(conversation.getCreatedAt());

        if (conversation.getEvent() != null) {
            builder.eventId(conversation.getEvent().getId())
                   .eventTitle(conversation.getEvent().getTitle());
        }

        if (conversation.getPinnedMessage() != null
                && !conversation.getPinnedMessage().isDeleted()) {
            var pinned = conversation.getPinnedMessage();
            builder.pinnedMessage(PinnedMessageResponse.builder()
                    .id(pinned.getId())
                    .content(pinned.getContent())
                    .senderName(pinned.getSender() != null
                            ? pinned.getSender().getFullName()
                            : null)
                    .createdAt(pinned.getCreatedAt())
                    .pinnedAt(conversation.getPinnedAt())
                    .pinnedByUserId(conversation.getPinnedBy() != null
                            ? conversation.getPinnedBy().getId()
                            : null)
                    .build());
        }

        if (currentUserParticipant != null) {
            builder.unreadCount(currentUserParticipant.getUnreadCount())
                   .muted(currentUserParticipant.isMuted())
                   .pinned(currentUserParticipant.isPinned())
                   .archived(currentUserParticipant.isArchived());
        }

        if (conversation.getParticipants() != null && !conversation.getParticipants().isEmpty()) {
            builder.participantCount(conversation.getParticipants().size());

            List<ParticipantResponse> participants = conversation.getParticipants().stream()
                    .map(p -> ParticipantResponse.builder()
                            .userId(p.getUser().getId())
                            .fullName(p.getUser().getFullName())
                            .avatarUrl(UserImageResolver.resolve(p.getUser()))
                            .lastReadAt(p.getLastReadAt())
                            .build())
                    .toList();
            builder.participants(participants);

            if (conversation.getType() == ConversationType.DIRECT && currentUserParticipant != null) {
                conversation.getParticipants().stream()
                        .filter(p -> !p.getUser().getId().equals(currentUserParticipant.getUser().getId()))
                        .findFirst()
                        .ifPresent(otherParticipant -> {
                            builder.name(otherParticipant.getUser().getFullName());
                            builder.imageUrl(UserImageResolver.resolve(otherParticipant.getUser()));
                        });
            }
        }

        return builder.build();
    }
}

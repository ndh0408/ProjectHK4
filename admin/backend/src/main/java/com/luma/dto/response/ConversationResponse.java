package com.luma.dto.response;

import com.luma.entity.Conversation;
import com.luma.entity.ConversationParticipant;
import com.luma.entity.enums.ConversationType;
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
    private LocalDateTime createdAt;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ParticipantResponse {
        private UUID userId;
        private String fullName;
        private String avatarUrl;
    }

    public static ConversationResponse fromEntity(Conversation conversation, ConversationParticipant currentUserParticipant) {
        ConversationResponseBuilder builder = ConversationResponse.builder()
                .id(conversation.getId())
                .type(conversation.getType())
                .name(conversation.getName())
                .imageUrl(conversation.getImageUrl())
                .lastMessageContent(conversation.getLastMessageContent())
                .lastMessageAt(conversation.getLastMessageAt())
                .createdAt(conversation.getCreatedAt());

        if (conversation.getEvent() != null) {
            builder.eventId(conversation.getEvent().getId())
                   .eventTitle(conversation.getEvent().getTitle());
        }

        if (currentUserParticipant != null) {
            builder.unreadCount(currentUserParticipant.getUnreadCount())
                   .muted(currentUserParticipant.isMuted())
                   .pinned(currentUserParticipant.isPinned())
                   .archived(currentUserParticipant.isArchived());
        }

        if (conversation.getParticipants() != null && !conversation.getParticipants().isEmpty()) {
            builder.participantCount(conversation.getParticipants().size());

            if (conversation.getType() == ConversationType.DIRECT ||
                conversation.getType() == ConversationType.GROUP) {
                List<ParticipantResponse> participants = conversation.getParticipants().stream()
                        .map(p -> ParticipantResponse.builder()
                                .userId(p.getUser().getId())
                                .fullName(p.getUser().getFullName())
                                .avatarUrl(p.getUser().getAvatarUrl())
                                .build())
                        .toList();
                builder.participants(participants);

                if (conversation.getType() == ConversationType.DIRECT && currentUserParticipant != null) {
                    conversation.getParticipants().stream()
                            .filter(p -> !p.getUser().getId().equals(currentUserParticipant.getUser().getId()))
                            .findFirst()
                            .ifPresent(otherParticipant -> {
                                builder.name(otherParticipant.getUser().getFullName());
                                builder.imageUrl(otherParticipant.getUser().getAvatarUrl());
                            });
                }
            }
        }

        return builder.build();
    }
}

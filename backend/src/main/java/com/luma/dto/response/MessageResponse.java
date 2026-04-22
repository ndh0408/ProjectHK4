package com.luma.dto.response;

import com.luma.entity.Message;
import com.luma.entity.User;
import com.luma.entity.enums.MessageType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.function.Function;
import java.util.function.Predicate;

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
    private PollResponse poll;
    /// Role of the sender inside THIS conversation. "ORGANISER" when the
    /// sender is the event's organiser in an EVENT_GROUP chat; everyone else
    /// ("ATTENDEE") is the default. Drives the "Organiser" badge on chat
    /// bubbles so attendees can spot official announcements at a glance.
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
        return fromEntity(message, null);
    }

    public static MessageResponse fromEntity(Message message, Predicate<UUID> hasVotedResolver) {
        return fromEntity(message, hasVotedResolver, null);
    }

    /**
     * Build a MessageResponse and embed a PollResponse snapshot when the
     * message is a POLL. The {@code hasVotedResolver} reports whether the
     * viewing user has voted on that poll — pass {@code null} for anonymous
     * or broadcast views (receivers compute it client-side).
     *
     * {@code votedOptionsResolver} returns the option IDs the viewer voted
     * for on a given poll (single-choice: 1 entry, multi-choice: N entries,
     * rating polls: ignored). Passing {@code null} omits the field so older
     * callers still work.
     */
    public static MessageResponse fromEntity(Message message,
                                             Predicate<UUID> hasVotedResolver,
                                             Function<UUID, java.util.List<UUID>> votedOptionsResolver) {
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
                    .avatarUrl(resolveUserImageUrl(message.getSender()))
                    .build());
        }

        if (message.getReplyTo() != null) {
            builder.replyTo(ReplyResponse.builder()
                    .id(message.getReplyTo().getId())
                    .content(message.getReplyTo().getContent())
                    .senderName(message.getReplyTo().getSender().getFullName())
                    .build());
        }

        if (message.getType() == MessageType.POLL && message.getPoll() != null) {
            UUID pollId = message.getPoll().getId();
            boolean hasVoted = hasVotedResolver != null && hasVotedResolver.test(pollId);
            boolean hideResults = message.getPoll().isHideResultsUntilClosed()
                    && message.getPoll().getStatus() != com.luma.entity.enums.PollStatus.CLOSED;
            List<UUID> votedOptionIds = (hasVoted && votedOptionsResolver != null)
                    ? votedOptionsResolver.apply(pollId) : null;
            builder.poll(PollResponse.fromEntity(message.getPoll(), hasVoted, hideResults,
                    votedOptionIds, null));
        }

        return builder.build();
    }

    /// Returns "ORGANISER" when the sender owns the event this conversation
    /// is tied to, otherwise "ATTENDEE". Only meaningful for EVENT_GROUP
    /// conversations — DMs and user-created groups always resolve to
    /// "ATTENDEE" because there is no organiser concept there.
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

    private static String resolveUserImageUrl(User user) {
        if (user == null) {
            return null;
        }

        if (user.getOrganiserProfile() != null
                && user.getOrganiserProfile().getLogoUrl() != null
                && !user.getOrganiserProfile().getLogoUrl().isBlank()) {
            return user.getOrganiserProfile().getLogoUrl();
        }

        if (user.getAvatarUrl() != null && !user.getAvatarUrl().isBlank()) {
            return user.getAvatarUrl();
        }

        return null;
    }
}

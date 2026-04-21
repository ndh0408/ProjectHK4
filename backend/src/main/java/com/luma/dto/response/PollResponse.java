package com.luma.dto.response;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.luma.entity.Poll;
import com.luma.entity.enums.PollStatus;
import com.luma.entity.enums.PollType;

import static com.luma.entity.enums.PollStatus.CLOSED;
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
public class PollResponse {

    private UUID id;
    private UUID eventId;
    private String eventTitle;
    private String createdByName;
    private String question;
    private PollType type;
    private PollStatus status;
    /// Keep the JSON key as "isActive" — Jackson's default strips the "is"
    /// prefix from boolean getters, which breaks the mobile PollSnapshot
    /// parser that expects "isActive".
    @JsonProperty("isActive")
    private boolean isActive;
    private int totalVotes;
    private Integer maxRating;
    private Integer closeAtVoteCount;
    private LocalDateTime closesAt;
    private LocalDateTime closedAt;
    private LocalDateTime scheduledOpenAt;
    private LocalDateTime openedAt;
    private LocalDateTime createdAt;
    private List<PollOptionResponse> options;
    private boolean hasVoted;
    /// Option IDs the current viewer has voted on (single-choice has 1
    /// entry, multi-choice can have several, rating polls leave this null).
    /// Null when the response is broadcast to non-specific audience.
    private List<UUID> votedOptionIds;
    private Integer votedRating;
    private boolean hideResultsUntilClosed;
    private boolean resultsHidden;  // true nếu đang ẩn kết quả
    private boolean autoOpenEventStart;
    private boolean autoCloseEventEnd;
    private boolean autoCloseTenDaysAfterEventEnd;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class PollOptionResponse {
        private UUID id;
        private String text;
        private int voteCount;
        private double percentage;
        private int displayOrder;
    }

    public static PollResponse fromEntity(Poll poll, boolean hasVoted) {
        return fromEntity(poll, hasVoted, false, null, null);
    }

    public static PollResponse fromEntity(Poll poll, boolean hasVoted, boolean hideResults) {
        return fromEntity(poll, hasVoted, hideResults, null, null);
    }

    public static PollResponse fromEntity(Poll poll, boolean hasVoted, boolean hideResults,
                                          List<UUID> votedOptionIds, Integer votedRating) {
        int totalVotes = poll.getTotalVotes();
        boolean resultsHidden = hideResults && poll.isHideResultsUntilClosed() && poll.getStatus() != PollStatus.CLOSED;

        List<PollOptionResponse> optionResponses;
        if (poll.getOptions() == null || poll.getOptions().isEmpty()) {
            optionResponses = List.of();
        } else if (resultsHidden) {
            // Ẩn kết quả: chỉ trả về text, không có vote count
            optionResponses = poll.getOptions().stream()
                    .map(o -> PollOptionResponse.builder()
                            .id(o.getId())
                            .text(o.getText())
                            .voteCount(0)
                            .percentage(0)
                            .displayOrder(o.getDisplayOrder())
                            .build())
                    .toList();
        } else {
            // Hiển thị kết quả đầy đủ
            optionResponses = poll.getOptions().stream()
                    .map(o -> PollOptionResponse.builder()
                            .id(o.getId())
                            .text(o.getText())
                            .voteCount(o.getVoteCount())
                            .percentage(totalVotes > 0 ? (double) o.getVoteCount() / totalVotes * 100 : 0)
                            .displayOrder(o.getDisplayOrder())
                            .build())
                    .toList();
        }

        return PollResponse.builder()
                .id(poll.getId())
                .eventId(poll.getEvent().getId())
                .eventTitle(poll.getEvent().getTitle())
                .createdByName(poll.getCreatedBy().getFullName())
                .question(poll.getQuestion())
                .type(poll.getType())
                .status(poll.getStatus())
                .isActive(poll.isActive())
                .totalVotes(resultsHidden ? 0 : totalVotes)
                .maxRating(poll.getMaxRating())
                .closeAtVoteCount(poll.getCloseAtVoteCount())
                .closesAt(poll.getClosesAt())
                .closedAt(poll.getClosedAt())
                .scheduledOpenAt(poll.getScheduledOpenAt())
                .openedAt(poll.getOpenedAt())
                .createdAt(poll.getCreatedAt())
                .options(optionResponses)
                .hasVoted(hasVoted)
                .votedOptionIds(votedOptionIds)
                .votedRating(votedRating)
                .hideResultsUntilClosed(poll.isHideResultsUntilClosed())
                .resultsHidden(resultsHidden)
                .autoOpenEventStart(poll.isAutoOpenEventStart())
                .autoCloseEventEnd(poll.isAutoCloseEventEnd())
                .autoCloseTenDaysAfterEventEnd(poll.isAutoCloseTenDaysAfterEventEnd())
                .build();
    }
}

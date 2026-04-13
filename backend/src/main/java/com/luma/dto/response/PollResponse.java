package com.luma.dto.response;

import com.luma.entity.Poll;
import com.luma.entity.enums.PollStatus;
import com.luma.entity.enums.PollType;
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
    private boolean isActive;
    private int totalVotes;
    private Integer maxRating;
    private LocalDateTime closesAt;
    private LocalDateTime createdAt;
    private List<PollOptionResponse> options;
    private boolean hasVoted;

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
        int totalVotes = poll.getTotalVotes();

        List<PollOptionResponse> optionResponses = poll.getOptions().stream()
                .map(o -> PollOptionResponse.builder()
                        .id(o.getId())
                        .text(o.getText())
                        .voteCount(o.getVoteCount())
                        .percentage(totalVotes > 0 ? (double) o.getVoteCount() / totalVotes * 100 : 0)
                        .displayOrder(o.getDisplayOrder())
                        .build())
                .toList();

        return PollResponse.builder()
                .id(poll.getId())
                .eventId(poll.getEvent().getId())
                .eventTitle(poll.getEvent().getTitle())
                .createdByName(poll.getCreatedBy().getFullName())
                .question(poll.getQuestion())
                .type(poll.getType())
                .status(poll.getStatus())
                .isActive(poll.isActive())
                .totalVotes(totalVotes)
                .maxRating(poll.getMaxRating())
                .closesAt(poll.getClosesAt())
                .createdAt(poll.getCreatedAt())
                .options(optionResponses)
                .hasVoted(hasVoted)
                .build();
    }
}

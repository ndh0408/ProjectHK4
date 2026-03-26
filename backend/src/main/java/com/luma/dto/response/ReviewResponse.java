package com.luma.dto.response;

import com.luma.entity.Review;
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
public class ReviewResponse {

    private UUID id;
    private int rating;
    private String comment;

    // User info
    private UUID userId;
    private String userName;
    private String userAvatarUrl;

    // Event info
    private UUID eventId;
    private String eventTitle;

    private LocalDateTime createdAt;

    // AI Moderation info (for organiser view)
    private Integer toxicityScore;
    private String moderationCategories;
    private String moderationReason;
    private Boolean flagged;

    public static ReviewResponse fromEntity(Review review) {
        return ReviewResponse.builder()
                .id(review.getId())
                .rating(review.getRating())
                .comment(review.getComment())
                .userId(review.getUser().getId())
                .userName(review.getUser().getFullName())
                .userAvatarUrl(review.getUser().getAvatarUrl())
                .eventId(review.getEvent().getId())
                .eventTitle(review.getEvent().getTitle())
                .createdAt(review.getCreatedAt())
                .toxicityScore(review.getToxicityScore())
                .moderationCategories(review.getModerationCategories())
                .moderationReason(review.getModerationReason())
                .flagged(review.isFlagged())
                .build();
    }
}

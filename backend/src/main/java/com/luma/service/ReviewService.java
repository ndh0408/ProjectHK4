package com.luma.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.luma.dto.request.ReviewRequest;
import com.luma.dto.response.PageResponse;
import com.luma.dto.response.ReviewResponse;
import com.luma.entity.Event;
import com.luma.entity.Registration;
import com.luma.entity.Review;
import com.luma.entity.User;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.EventRepository;
import com.luma.repository.RegistrationRepository;
import com.luma.repository.ReviewRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;
import java.util.stream.Collectors;
import java.util.stream.StreamSupport;

@Service
@RequiredArgsConstructor
@Slf4j
public class ReviewService {

    private final ReviewRepository reviewRepository;
    private final EventRepository eventRepository;
    private final RegistrationRepository registrationRepository;
    private final AIService aiService;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Transactional
    public ReviewResponse createReview(User user, UUID eventId, ReviewRequest request) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        validateCanReview(user, event);

        if (reviewRepository.existsByEventAndUser(event, user)) {
            throw new BadRequestException("You have already reviewed this event");
        }

        Review review = Review.builder()
                .user(user)
                .event(event)
                .rating(request.getRating())
                .comment(request.getComment())
                .build();

        try {
            moderateReviewContent(review, event.getTitle());
        } catch (Exception e) {
            log.warn("AI moderation failed, saving review without moderation: {}", e.getMessage());
        }

        boolean hasHarmfulCategory = review.getModerationCategories() != null
                && (review.getModerationCategories().contains("TOXIC")
                        || review.getModerationCategories().contains("HARASSMENT")
                        || review.getModerationCategories().contains("PROFANITY"));
        if (review.getToxicityScore() != null && review.getToxicityScore() >= 90 && hasHarmfulCategory) {
            throw new BadRequestException("Your review contains inappropriate content. Please revise and try again. Reason: " + review.getModerationReason());
        }

        review = reviewRepository.save(review);
        log.info("Review created by user {} for event {} (toxicity: {}, flagged: {})",
                user.getId(), eventId, review.getToxicityScore(), review.isFlagged());

        return ReviewResponse.fromEntity(review);
    }

    private void moderateReviewContent(Review review, String eventTitle) {
        String result = aiService.moderateReviewContent(
                review.getComment(),
                review.getRating(),
                eventTitle
        );

        try {
            JsonNode json = objectMapper.readTree(result);

            boolean isAppropriate = json.has("isAppropriate") && json.get("isAppropriate").asBoolean(true);
            int toxicityScore = json.has("toxicityScore") ? json.get("toxicityScore").asInt(0) : 0;

            review.setToxicityScore(toxicityScore);
            review.setFlagged(!isAppropriate || toxicityScore >= 60);

            if (json.has("categories") && json.get("categories").isArray()) {
                String categories = StreamSupport.stream(json.get("categories").spliterator(), false)
                        .map(JsonNode::asText)
                        .collect(Collectors.joining(","));
                review.setModerationCategories(categories.isEmpty() ? null : categories);
            }

            if (json.has("reason") && !json.get("reason").isNull()) {
                review.setModerationReason(json.get("reason").asText());
            }

            log.info("Review moderated: toxicity={}, flagged={}, categories={}",
                    toxicityScore, review.isFlagged(), review.getModerationCategories());
        } catch (Exception e) {
            log.error("Error parsing AI moderation response: {}", e.getMessage());
        }
    }

    @Transactional(readOnly = true)
    public PageResponse<ReviewResponse> getEventReviews(UUID eventId, Pageable pageable) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        Page<Review> reviews = reviewRepository.findByEventOrderByCreatedAtDesc(event, pageable);

        return PageResponse.<ReviewResponse>builder()
                .content(reviews.map(ReviewResponse::fromEntity).getContent())
                .page(reviews.getNumber())
                .size(reviews.getSize())
                .totalElements(reviews.getTotalElements())
                .totalPages(reviews.getTotalPages())
                .last(reviews.isLast())
                .build();
    }

    @Transactional(readOnly = true)
    public PageResponse<ReviewResponse> getUserReviews(User user, Pageable pageable) {
        Page<Review> reviews = reviewRepository.findByUserOrderByCreatedAtDesc(user, pageable);

        return PageResponse.<ReviewResponse>builder()
                .content(reviews.map(ReviewResponse::fromEntity).getContent())
                .page(reviews.getNumber())
                .size(reviews.getSize())
                .totalElements(reviews.getTotalElements())
                .totalPages(reviews.getTotalPages())
                .last(reviews.isLast())
                .build();
    }

    @Transactional(readOnly = true)
    public boolean canReview(User user, UUID eventId) {
        Event event = eventRepository.findById(eventId).orElse(null);
        if (event == null) return false;

        try {
            validateCanReview(user, event);
            return !reviewRepository.existsByEventAndUser(event, user);
        } catch (BadRequestException e) {
            return false;
        }
    }

    @Transactional(readOnly = true)
    public Double getAverageRating(UUID eventId) {
        return reviewRepository.getAverageRatingByEventId(eventId);
    }

    @Transactional(readOnly = true)
    public long getReviewCount(UUID eventId) {
        return reviewRepository.countByEventId(eventId);
    }

    private void validateCanReview(User user, Event event) {
        Registration registration = registrationRepository.findByUserAndEvent(user, event)
                .orElseThrow(() -> new BadRequestException("You must register for this event to review it"));

        if (registration.getStatus() != RegistrationStatus.APPROVED) {
            throw new BadRequestException("Your registration must be approved to review this event");
        }

        if (registration.getCheckedInAt() == null) {
            throw new BadRequestException("You must check in to the event to write a review");
        }

        if (event.getEndTime() == null || event.getEndTime().isAfter(LocalDateTime.now())) {
            throw new BadRequestException("Event has not ended yet");
        }
    }
}

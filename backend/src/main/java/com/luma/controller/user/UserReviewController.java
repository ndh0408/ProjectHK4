package com.luma.controller.user;

import com.luma.dto.request.ReportReviewRequest;
import com.luma.dto.request.ReviewRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.PageResponse;
import com.luma.dto.response.ReviewReportResponse;
import com.luma.dto.response.ReviewResponse;
import com.luma.entity.User;
import com.luma.service.ReviewReportService;
import com.luma.service.ReviewService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/user")
@RequiredArgsConstructor
@Tag(name = "User Reviews", description = "APIs for event reviews")
public class UserReviewController {

    private final ReviewService reviewService;
    private final ReviewReportService reportService;
    private final UserService userService;

    @PostMapping("/events/{eventId}/reviews")
    @Operation(summary = "Create a review for an event")
    public ResponseEntity<ApiResponse<ReviewResponse>> createReview(
            @PathVariable UUID eventId,
            @Valid @RequestBody ReviewRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        ReviewResponse response = reviewService.createReview(user, eventId, request);
        return ResponseEntity.ok(ApiResponse.success("Review submitted successfully", response));
    }

    @GetMapping("/events/{eventId}/reviews")
    @Operation(summary = "Get reviews for an event")
    public ResponseEntity<ApiResponse<PageResponse<ReviewResponse>>> getEventReviews(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 10) Pageable pageable) {
        User viewer = userDetails != null
                ? userService.getEntityByEmail(userDetails.getUsername())
                : null;
        return ResponseEntity.ok(ApiResponse.success(reviewService.getEventReviews(eventId, viewer, pageable)));
    }

    @GetMapping("/events/{eventId}/can-review")
    @Operation(summary = "Check if user can review an event")
    public ResponseEntity<ApiResponse<Map<String, Boolean>>> canReview(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        boolean canReview = reviewService.canReview(user, eventId);
        return ResponseEntity.ok(ApiResponse.success(Map.of("canReview", canReview)));
    }

    @GetMapping("/my-reviews")
    @Operation(summary = "Get reviews by current user")
    public ResponseEntity<ApiResponse<PageResponse<ReviewResponse>>> getMyReviews(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 10) Pageable pageable) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(reviewService.getUserReviews(user, pageable)));
    }

    @PostMapping("/reviews/{reviewId}/report")
    @Operation(summary = "Report a review for inappropriate content")
    public ResponseEntity<ApiResponse<ReviewReportResponse>> reportReview(
            @PathVariable UUID reviewId,
            @Valid @RequestBody ReportReviewRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        ReviewReportResponse response = reportService.reportReview(user, reviewId, request);
        return ResponseEntity.ok(ApiResponse.success("Review reported successfully", response));
    }
}

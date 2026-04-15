package com.luma.controller.user;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.EventRecommendationResponse;
import com.luma.dto.response.EventResponse;
import com.luma.entity.User;
import com.luma.service.EventRecommendationService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/user/recommendations")
@RequiredArgsConstructor
@Tag(name = "User Recommendations", description = "AI-powered event recommendations")
public class UserRecommendationController {

    private final EventRecommendationService recommendationService;
    private final UserService userService;

    @GetMapping("/personalized")
    @Operation(summary = "Get personalized event recommendations based on user history")
    public ResponseEntity<ApiResponse<EventRecommendationResponse>> getPersonalizedRecommendations(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "10") int limit) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        EventRecommendationResponse response = recommendationService.getPersonalizedRecommendations(user, limit);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/similar/{eventId}")
    @Operation(summary = "Get events similar to a specific event")
    public ResponseEntity<ApiResponse<List<EventResponse>>> getSimilarEvents(
            @PathVariable UUID eventId,
            @RequestParam(defaultValue = "5") int limit) {
        List<EventResponse> similarEvents = recommendationService.getSimilarEvents(eventId, limit);
        return ResponseEntity.ok(ApiResponse.success(similarEvents));
    }

    @GetMapping("/trending")
    @Operation(summary = "Get trending/hot events")
    public ResponseEntity<ApiResponse<List<EventResponse>>> getTrendingEvents(
            @RequestParam(defaultValue = "10") int limit) {
        List<EventResponse> trendingEvents = recommendationService.getTrendingEvents(limit);
        return ResponseEntity.ok(ApiResponse.success(trendingEvents));
    }
}

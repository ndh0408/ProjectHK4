package com.luma.controller.organiser;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.analytics.FunnelAnalyticsResponse;
import com.luma.entity.User;
import com.luma.service.FunnelAnalyticsService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/organiser/analytics")
@RequiredArgsConstructor
@Tag(name = "Organiser Funnel Analytics", description = "Conversion funnel analytics")
public class OrganiserFunnelController {

    private final FunnelAnalyticsService funnelAnalyticsService;
    private final UserService userService;

    @GetMapping("/funnel")
    @Operation(summary = "Get organiser conversion funnel")
    public ResponseEntity<ApiResponse<FunnelAnalyticsResponse>> getOrganiserFunnel(
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        FunnelAnalyticsResponse response = funnelAnalyticsService.getOrganiserFunnel(user.getId());
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/funnel/event/{eventId}")
    @Operation(summary = "Get funnel for a specific event")
    public ResponseEntity<ApiResponse<FunnelAnalyticsResponse>> getEventFunnel(
            @PathVariable UUID eventId) {
        FunnelAnalyticsResponse response = funnelAnalyticsService.getEventFunnel(eventId);
        return ResponseEntity.ok(ApiResponse.success(response));
    }
}

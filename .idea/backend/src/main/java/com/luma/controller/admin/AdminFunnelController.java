package com.luma.controller.admin;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.analytics.FunnelAnalyticsResponse;
import com.luma.service.FunnelAnalyticsService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/admin/analytics")
@RequiredArgsConstructor
@Tag(name = "Admin Funnel Analytics", description = "Platform-wide funnel analytics")
public class AdminFunnelController {

    private final FunnelAnalyticsService funnelAnalyticsService;

    @GetMapping("/funnel")
    @Operation(summary = "Get platform conversion funnel")
    public ResponseEntity<ApiResponse<FunnelAnalyticsResponse>> getPlatformFunnel() {
        FunnelAnalyticsResponse response = funnelAnalyticsService.getPlatformFunnel();
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/funnel/event/{eventId}")
    @Operation(summary = "Get funnel for a specific event")
    public ResponseEntity<ApiResponse<FunnelAnalyticsResponse>> getEventFunnel(@PathVariable UUID eventId) {
        FunnelAnalyticsResponse response = funnelAnalyticsService.getEventFunnel(eventId);
        return ResponseEntity.ok(ApiResponse.success(response));
    }
}

package com.luma.controller;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.EventResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.Event;
import com.luma.service.EventService;
import com.luma.service.EventBoostService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/events")
@RequiredArgsConstructor
@Tag(name = "Public Events", description = "Public APIs for browsing events (no authentication required)")
public class PublicEventController {

    private final EventService eventService;
    private final EventBoostService eventBoostService;

    @GetMapping("/featured")
    @Operation(summary = "Get featured/published events for showcase (no auth required, no date limit)")
    public ResponseEntity<ApiResponse<PageResponse<EventResponse>>> getFeaturedEvents(
            @PageableDefault(size = 10) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(eventService.getFeaturedEvents(pageable)));
    }

    @GetMapping("/upcoming")
    @Operation(summary = "Get upcoming events with boosted events prioritized (no auth required)")
    public ResponseEntity<ApiResponse<PageResponse<EventResponse>>> getUpcomingEvents(
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(eventService.getUpcomingEvents(pageable)));
    }

    @GetMapping("/{eventId}")
    @Operation(summary = "Get event details (no auth required)")
    public ResponseEntity<ApiResponse<EventResponse>> getEventDetails(@PathVariable UUID eventId) {
        return ResponseEntity.ok(ApiResponse.success(eventService.getEventById(eventId)));
    }

    @GetMapping("/boosted/featured")
    @Operation(summary = "Get PREMIUM and VIP boosted events for featured section (no auth required)")
    public ResponseEntity<ApiResponse<List<EventResponse>>> getBoostedFeaturedEvents() {
        List<Event> featuredEvents = eventBoostService.getFeaturedEvents();
        List<EventResponse> responses = featuredEvents.stream()
                .map(event -> {
                    EventResponse response = EventResponse.fromEntity(event);
                    response.setIsBoosted(true);
                    var pkg = eventBoostService.getEventBoostPackage(event.getId());
                    if (pkg != null) {
                        response.setBoostPackage(pkg.name());
                        response.setBoostBadge(pkg.getBadgeText());
                    }
                    return response;
                })
                .collect(Collectors.toList());
        return ResponseEntity.ok(ApiResponse.success(responses));
    }

    @GetMapping("/boosted/banner")
    @Operation(summary = "Get VIP boosted events for home page banner (no auth required)")
    public ResponseEntity<ApiResponse<List<EventResponse>>> getHomeBannerEvents() {
        List<Event> bannerEvents = eventBoostService.getHomeBannerEvents();
        List<EventResponse> responses = bannerEvents.stream()
                .map(event -> {
                    EventResponse response = EventResponse.fromEntity(event);
                    response.setIsBoosted(true);
                    response.setBoostPackage("VIP");
                    response.setBoostBadge("VIP");
                    return response;
                })
                .collect(Collectors.toList());
        return ResponseEntity.ok(ApiResponse.success(responses));
    }
}

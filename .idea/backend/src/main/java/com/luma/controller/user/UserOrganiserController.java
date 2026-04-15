package com.luma.controller.user;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.EventResponse;
import com.luma.dto.response.OrganiserResponse;
import com.luma.dto.response.PageResponse;
import com.luma.service.EventService;
import com.luma.service.OrganiserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/user/organisers")
@RequiredArgsConstructor
@Tag(name = "User Organisers", description = "APIs for viewing organiser profiles and events")
public class UserOrganiserController {

    private final OrganiserService organiserService;
    private final EventService eventService;

    @GetMapping("/{organiserId}")
    @Operation(summary = "Get organiser profile")
    public ResponseEntity<ApiResponse<OrganiserResponse>> getOrganiserProfile(@PathVariable UUID organiserId) {
        return ResponseEntity.ok(ApiResponse.success(organiserService.getOrganiserProfile(organiserId)));
    }

    @GetMapping("/{organiserId}/events/upcoming")
    @Operation(summary = "Get upcoming events by organiser (next month)")
    public ResponseEntity<ApiResponse<PageResponse<EventResponse>>> getUpcomingEvents(
            @PathVariable UUID organiserId,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(eventService.getUpcomingEventsByOrganiserId(organiserId, pageable)));
    }

    @GetMapping("/{organiserId}/events/past")
    @Operation(summary = "Get past events by organiser")
    public ResponseEntity<ApiResponse<PageResponse<EventResponse>>> getPastEvents(
            @PathVariable UUID organiserId,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(eventService.getPastEventsByOrganiserId(organiserId, pageable)));
    }

    @GetMapping("/{organiserId}/events")
    @Operation(summary = "Get all events by organiser (upcoming and past)")
    public ResponseEntity<ApiResponse<PageResponse<EventResponse>>> getAllEvents(
            @PathVariable UUID organiserId,
            @RequestParam(defaultValue = "upcoming") String filter,
            @PageableDefault(size = 20) Pageable pageable) {
        if ("past".equalsIgnoreCase(filter)) {
            return ResponseEntity.ok(ApiResponse.success(eventService.getPastEventsByOrganiserId(organiserId, pageable)));
        }
        return ResponseEntity.ok(ApiResponse.success(eventService.getUpcomingEventsByOrganiserId(organiserId, pageable)));
    }
}

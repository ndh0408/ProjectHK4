package com.luma.controller.admin;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.EventResponse;
import com.luma.dto.response.PageResponse;
import com.luma.service.EventService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin/events")
@RequiredArgsConstructor
@Tag(name = "Admin Events", description = "APIs for admin event management")
public class AdminEventController {

    private final EventService eventService;

    @GetMapping
    @Operation(summary = "Get all events")
    public ResponseEntity<ApiResponse<PageResponse<EventResponse>>> getAllEvents(
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String status,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(eventService.getAllEventsForAdmin(search, status, pageable)));
    }

    @GetMapping("/pending")
    @Operation(summary = "Get pending events for approval")
    public ResponseEntity<ApiResponse<PageResponse<EventResponse>>> getPendingEvents(
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(eventService.getPendingEventsForAdmin(pageable)));
    }

    @GetMapping("/{eventId}")
    @Operation(summary = "Get event details")
    public ResponseEntity<ApiResponse<EventResponse>> getEventById(@PathVariable UUID eventId) {
        return ResponseEntity.ok(ApiResponse.success(eventService.getEventById(eventId)));
    }

    @PostMapping("/{eventId}/approve")
    @Operation(summary = "Approve an event")
    public ResponseEntity<ApiResponse<EventResponse>> approveEvent(@PathVariable UUID eventId) {
        return ResponseEntity.ok(ApiResponse.success("Event approved successfully", eventService.approveEvent(eventId)));
    }

    @PostMapping("/{eventId}/reject")
    @Operation(summary = "Reject an event")
    public ResponseEntity<ApiResponse<EventResponse>> rejectEvent(
            @PathVariable UUID eventId,
            @RequestBody(required = false) Map<String, Object> body) {
        String reason = null;
        if (body != null && body.containsKey("reason")) {
            Object reasonObj = body.get("reason");
            if (reasonObj != null) {
                reason = reasonObj.toString();
            }
        }
        return ResponseEntity.ok(ApiResponse.success("Event rejected", eventService.rejectEvent(eventId, reason)));
    }

    @PatchMapping("/{eventId}/hide")
    @Operation(summary = "Hide an event")
    public ResponseEntity<ApiResponse<EventResponse>> hideEvent(@PathVariable UUID eventId) {
        return ResponseEntity.ok(ApiResponse.success("Event hidden successfully", eventService.hideEvent(eventId)));
    }

    @PatchMapping("/{eventId}/unhide")
    @Operation(summary = "Unhide an event")
    public ResponseEntity<ApiResponse<EventResponse>> unhideEvent(@PathVariable UUID eventId) {
        return ResponseEntity.ok(ApiResponse.success("Event visible again", eventService.unhideEvent(eventId)));
    }

    @DeleteMapping("/{eventId}")
    @Operation(summary = "Delete an event permanently")
    public ResponseEntity<ApiResponse<Void>> deleteEvent(
            @PathVariable UUID eventId,
            @RequestParam(required = false, defaultValue = "false") boolean deleteSeries) {
        eventService.deleteEvent(eventId, deleteSeries);
        return ResponseEntity.ok(ApiResponse.success("Event deleted successfully", null));
    }
}

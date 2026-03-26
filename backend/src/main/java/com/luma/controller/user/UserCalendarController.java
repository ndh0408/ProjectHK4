package com.luma.controller.user;

import com.luma.dto.request.CalendarSyncRequest;
import com.luma.dto.request.GoogleCalendarAuthRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.CalendarSyncResponse;
import com.luma.dto.response.GoogleCalendarStatusResponse;
import com.luma.entity.User;
import com.luma.service.GoogleCalendarService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/user/calendar")
@RequiredArgsConstructor
@Tag(name = "User - Google Calendar", description = "Google Calendar sync operations")
public class UserCalendarController {

    private final GoogleCalendarService googleCalendarService;
    private final UserService userService;

    @GetMapping("/auth-url")
    @Operation(summary = "Get Google OAuth authorization URL")
    public ResponseEntity<ApiResponse<Map<String, String>>> getAuthorizationUrl(
            @RequestParam(required = false) String redirectUri) {
        String url = googleCalendarService.getAuthorizationUrl(redirectUri);
        return ResponseEntity.ok(ApiResponse.success(Map.of("authUrl", url)));
    }

    @PostMapping("/connect")
    @Operation(summary = "Connect Google Calendar with authorization code")
    public ResponseEntity<ApiResponse<String>> connectGoogleCalendar(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody GoogleCalendarAuthRequest request) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        googleCalendarService.connectGoogleCalendar(user, request);
        return ResponseEntity.ok(ApiResponse.success("Google Calendar connected successfully"));
    }

    @DeleteMapping("/disconnect")
    @Operation(summary = "Disconnect Google Calendar")
    public ResponseEntity<ApiResponse<String>> disconnectGoogleCalendar(
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        googleCalendarService.disconnectGoogleCalendar(user);
        return ResponseEntity.ok(ApiResponse.success("Google Calendar disconnected successfully"));
    }

    @GetMapping("/status")
    @Operation(summary = "Get Google Calendar connection status")
    public ResponseEntity<ApiResponse<GoogleCalendarStatusResponse>> getConnectionStatus(
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        GoogleCalendarStatusResponse status = googleCalendarService.getConnectionStatus(user);
        return ResponseEntity.ok(ApiResponse.success(status));
    }

    @PostMapping("/sync")
    @Operation(summary = "Sync a registered event to Google Calendar")
    public ResponseEntity<ApiResponse<CalendarSyncResponse>> syncEvent(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody CalendarSyncRequest request) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        CalendarSyncResponse response = googleCalendarService.syncEventToCalendar(user, request);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @DeleteMapping("/sync/{registrationId}")
    @Operation(summary = "Remove event from Google Calendar")
    public ResponseEntity<ApiResponse<String>> unsyncEvent(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID registrationId) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        googleCalendarService.unsyncEventFromCalendar(user, registrationId);
        return ResponseEntity.ok(ApiResponse.success("Event removed from Google Calendar"));
    }

    @GetMapping("/synced-events")
    @Operation(summary = "Get all synced events")
    public ResponseEntity<ApiResponse<List<CalendarSyncResponse>>> getSyncedEvents(
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        List<CalendarSyncResponse> events = googleCalendarService.getSyncedEvents(user);
        return ResponseEntity.ok(ApiResponse.success(events));
    }

    @PostMapping("/sync-all")
    @Operation(summary = "Sync all registered events to Google Calendar")
    public ResponseEntity<ApiResponse<Map<String, Integer>>> syncAllEvents(
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        int syncedCount = googleCalendarService.syncAllEventsToCalendar(user);
        return ResponseEntity.ok(ApiResponse.success(Map.of("syncedCount", syncedCount)));
    }
}

package com.luma.controller.organiser;

import com.luma.dto.response.ApiResponse;
import com.luma.entity.User;
import com.luma.service.ScheduleBuilderService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/organiser/schedule")
@RequiredArgsConstructor
@Tag(name = "Schedule Builder", description = "APIs for event schedule management")
public class OrganiserScheduleController {

    private final ScheduleBuilderService scheduleService;
    private final UserService userService;

    @PostMapping("/event/{eventId}/sessions")
    @Operation(summary = "Create a session")
    public ResponseEntity<ApiResponse<Map<String, Object>>> createSession(
            @PathVariable UUID eventId,
            @RequestBody Map<String, Object> data,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success("Session created", scheduleService.createSession(eventId, data, user)));
    }

    @GetMapping("/event/{eventId}")
    @Operation(summary = "Get event schedule")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getSchedule(@PathVariable UUID eventId) {
        return ResponseEntity.ok(ApiResponse.success(scheduleService.getSchedule(eventId)));
    }

    @DeleteMapping("/sessions/{sessionId}")
    @Operation(summary = "Delete a session")
    public ResponseEntity<ApiResponse<Void>> deleteSession(
            @PathVariable UUID sessionId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        scheduleService.deleteSession(sessionId, user);
        return ResponseEntity.ok(ApiResponse.success("Session deleted", null));
    }
}

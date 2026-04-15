package com.luma.controller.user;

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

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/user/schedule")
@RequiredArgsConstructor
@Tag(name = "User Schedule", description = "APIs for user event schedule")
public class UserScheduleController {

    private final ScheduleBuilderService scheduleService;
    private final UserService userService;

    @GetMapping("/event/{eventId}")
    @Operation(summary = "Get event schedule")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getSchedule(@PathVariable UUID eventId) {
        return ResponseEntity.ok(ApiResponse.success(scheduleService.getSchedule(eventId)));
    }

    @PostMapping("/sessions/{sessionId}/register")
    @Operation(summary = "Register for a session")
    public ResponseEntity<ApiResponse<Map<String, Object>>> registerForSession(
            @PathVariable UUID sessionId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(scheduleService.registerForSession(sessionId, user)));
    }

    @GetMapping("/event/{eventId}/my-schedule")
    @Operation(summary = "Get my selected sessions")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getMySchedule(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(scheduleService.getMySchedule(eventId, user)));
    }
}

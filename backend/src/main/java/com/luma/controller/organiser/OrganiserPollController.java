package com.luma.controller.organiser;

import com.luma.dto.request.CreatePollRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.PollResponse;
import com.luma.entity.User;
import com.luma.service.PollService;
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
import java.util.UUID;

@RestController
@RequestMapping("/api/organiser/polls")
@RequiredArgsConstructor
@Tag(name = "Organiser Polls", description = "APIs for managing event polls")
public class OrganiserPollController {

    private final PollService pollService;
    private final UserService userService;

    @PostMapping("/event/{eventId}")
    @Operation(summary = "Create a poll for an event")
    public ResponseEntity<ApiResponse<PollResponse>> createPoll(
            @PathVariable UUID eventId,
            @Valid @RequestBody CreatePollRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        PollResponse response = pollService.createPoll(eventId, request, user);
        return ResponseEntity.ok(ApiResponse.success("Poll created successfully", response));
    }

    @GetMapping("/event/{eventId}")
    @Operation(summary = "Get all polls for an event")
    public ResponseEntity<ApiResponse<List<PollResponse>>> getEventPolls(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        List<PollResponse> polls = pollService.getEventPolls(eventId, user);
        return ResponseEntity.ok(ApiResponse.success(polls));
    }

    @PostMapping("/{pollId}/close")
    @Operation(summary = "Close a poll")
    public ResponseEntity<ApiResponse<PollResponse>> closePoll(
            @PathVariable UUID pollId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        PollResponse response = pollService.closePoll(pollId, user);
        return ResponseEntity.ok(ApiResponse.success("Poll closed", response));
    }
}

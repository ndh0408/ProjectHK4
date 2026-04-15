package com.luma.controller.user;

import com.luma.dto.request.VotePollRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.PollResponse;
import com.luma.entity.User;
import com.luma.service.PollService;
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
@RequestMapping("/api/user/polls")
@RequiredArgsConstructor
@Tag(name = "User Polls", description = "APIs for voting on event polls")
public class UserPollController {

    private final PollService pollService;
    private final UserService userService;

    @GetMapping("/event/{eventId}")
    @Operation(summary = "Get active polls for an event")
    public ResponseEntity<ApiResponse<List<PollResponse>>> getActivePolls(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        List<PollResponse> polls = pollService.getActiveEventPolls(eventId, user);
        return ResponseEntity.ok(ApiResponse.success(polls));
    }

    @GetMapping("/event/{eventId}/all")
    @Operation(summary = "Get all polls for an event (including closed)")
    public ResponseEntity<ApiResponse<List<PollResponse>>> getAllPolls(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        List<PollResponse> polls = pollService.getEventPolls(eventId, user);
        return ResponseEntity.ok(ApiResponse.success(polls));
    }

    @PostMapping("/{pollId}/vote")
    @Operation(summary = "Vote on a poll")
    public ResponseEntity<ApiResponse<PollResponse>> vote(
            @PathVariable UUID pollId,
            @RequestBody VotePollRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        PollResponse response = pollService.vote(pollId, request, user);
        return ResponseEntity.ok(ApiResponse.success("Vote recorded", response));
    }
}

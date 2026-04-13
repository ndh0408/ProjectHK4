package com.luma.controller.organiser;

import com.luma.dto.request.CreateGroupChatRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.ConversationResponse;
import com.luma.dto.response.EventBuddyResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.User;
import com.luma.service.OrganiserChatService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/organiser/chat")
@RequiredArgsConstructor
@Tag(name = "Organiser Chat", description = "APIs for organiser chat, event buddies and group management")
public class OrganiserChatController {

    private final OrganiserChatService organiserChatService;
    private final UserService userService;

    @GetMapping("/event-buddies")
    @Operation(summary = "Get event buddies - users who registered for the same events")
    public ResponseEntity<ApiResponse<PageResponse<EventBuddyResponse>>> getEventBuddies(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(organiserChatService.getEventBuddies(organiser, pageable)));
    }

    @GetMapping("/event-buddies/event/{eventId}")
    @Operation(summary = "Get event buddies for a specific event")
    public ResponseEntity<ApiResponse<List<EventBuddyResponse>>> getEventBuddiesByEvent(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(organiserChatService.getEventBuddiesByEvent(organiser, eventId)));
    }

    @PostMapping("/groups")
    @Operation(summary = "Create a new group chat")
    public ResponseEntity<ApiResponse<ConversationResponse>> createGroupChat(
            @Valid @RequestBody CreateGroupChatRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        ConversationResponse response = organiserChatService.createGroupChat(organiser, request);
        return ResponseEntity.ok(ApiResponse.success("Group chat created successfully", response));
    }

    @GetMapping("/groups")
    @Operation(summary = "Get all group chats for organiser")
    public ResponseEntity<ApiResponse<PageResponse<ConversationResponse>>> getGroupChats(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(organiserChatService.getGroupChats(organiser, pageable)));
    }

    @PostMapping("/groups/{conversationId}/participants")
    @Operation(summary = "Add participants to a group chat")
    public ResponseEntity<ApiResponse<ConversationResponse>> addParticipants(
            @PathVariable UUID conversationId,
            @RequestBody List<UUID> userIds,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        ConversationResponse response = organiserChatService.addParticipants(organiser, conversationId, userIds);
        return ResponseEntity.ok(ApiResponse.success("Participants added successfully", response));
    }

    @DeleteMapping("/groups/{conversationId}/participants/{userId}")
    @Operation(summary = "Remove a participant from a group chat")
    public ResponseEntity<ApiResponse<Void>> removeParticipant(
            @PathVariable UUID conversationId,
            @PathVariable UUID userId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        organiserChatService.removeParticipant(organiser, conversationId, userId);
        return ResponseEntity.ok(ApiResponse.success("Participant removed successfully", null));
    }

    @GetMapping("/conversations/direct/{userId}")
    @Operation(summary = "Get or create direct chat with an event buddy")
    public ResponseEntity<ApiResponse<ConversationResponse>> getDirectChat(
            @PathVariable UUID userId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(organiserChatService.getOrCreateDirectChat(organiser, userId)));
    }

    @GetMapping("/conversations")
    @Operation(summary = "Get all conversations for organiser")
    public ResponseEntity<ApiResponse<PageResponse<ConversationResponse>>> getConversations(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(organiserChatService.getConversations(organiser, pageable)));
    }
}

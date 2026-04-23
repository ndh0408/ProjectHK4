package com.luma.controller.organiser;

import com.luma.dto.request.CreateGroupChatRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.ConversationResponse;
import com.luma.dto.response.EventBuddyResponse;
import com.luma.dto.response.EventChatSummaryResponse;
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

    @GetMapping("/event-chats")
    @Operation(summary = "Get event group chats only for events created by the organiser")
    public ResponseEntity<ApiResponse<List<EventChatSummaryResponse>>> getEventChats(
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(organiserChatService.getEventChats(organiser)));
    }

    @PostMapping("/conversations/{conversationId}/messages/{messageId}/pin")
    @Operation(summary = "Pin a message in an event group chat")
    public ResponseEntity<ApiResponse<ConversationResponse>> pinMessage(
            @PathVariable UUID conversationId,
            @PathVariable UUID messageId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success("Message pinned", organiserChatService.pinMessage(organiser, conversationId, messageId)));
    }

    @PostMapping("/conversations/{conversationId}/messages/{messageId}/unpin")
    @Operation(summary = "Unpin a message in an event group chat")
    public ResponseEntity<ApiResponse<ConversationResponse>> unpinMessage(
            @PathVariable UUID conversationId,
            @PathVariable UUID messageId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success("Message unpinned", organiserChatService.unpinMessage(organiser, conversationId)));
    }

    @PostMapping("/conversations/{conversationId}/participants/{userId}/mute")
    @Operation(summary = "Mute an attendee in an event group chat")
    public ResponseEntity<ApiResponse<Void>> muteAttendee(
            @PathVariable UUID conversationId,
            @PathVariable UUID userId,
            @RequestParam(defaultValue = "60") int minutes,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        organiserChatService.muteAttendee(organiser, conversationId, userId, minutes);
        return ResponseEntity.ok(ApiResponse.success(minutes <= 0 ? "Attendee unmuted" : "Attendee muted", null));
    }

    @PostMapping("/conversations/{conversationId}/participants/{userId}/ban")
    @Operation(summary = "Ban/Remove an attendee from an event group chat permanently")
    public ResponseEntity<ApiResponse<Void>> banAttendee(
            @PathVariable UUID conversationId,
            @PathVariable UUID userId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        organiserChatService.banAttendee(organiser, conversationId, userId);
        return ResponseEntity.ok(ApiResponse.success("Attendee banned from chat", null));
    }

    @DeleteMapping("/conversations/{conversationId}/participants/{userId}/ban")
    @Operation(summary = "Unban an attendee from an event group chat")
    public ResponseEntity<ApiResponse<Void>> unbanAttendee(
            @PathVariable UUID conversationId,
            @PathVariable UUID userId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        organiserChatService.unbanAttendee(organiser, conversationId, userId);
        return ResponseEntity.ok(ApiResponse.success("Attendee unbanned from chat", null));
    }

    @DeleteMapping("/messages/{messageId}")
    @Operation(summary = "Moderator delete: delete any message in organiser's event chat")
    public ResponseEntity<ApiResponse<Void>> deleteAnyMessage(
            @PathVariable UUID messageId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        organiserChatService.deleteAnyMessage(organiser, messageId);
        return ResponseEntity.ok(ApiResponse.success("Message deleted by moderator", null));
    }
}

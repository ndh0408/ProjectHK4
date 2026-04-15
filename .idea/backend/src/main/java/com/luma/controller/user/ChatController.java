package com.luma.controller.user;

import com.luma.dto.request.CreateGroupChatRequest;
import com.luma.dto.request.SendMessageRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.BlockedUserResponse;
import com.luma.dto.response.ConversationResponse;
import com.luma.dto.response.EventBuddyResponse;
import com.luma.dto.response.MessageResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.User;
import com.luma.service.ChatService;
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
@RequestMapping("/api/user/chat")
@RequiredArgsConstructor
@Tag(name = "Chat", description = "APIs for messaging between event attendees")
public class ChatController {

    private final ChatService chatService;
    private final UserService userService;

    @GetMapping("/conversations")
    @Operation(summary = "Get all conversations for current user")
    public ResponseEntity<ApiResponse<PageResponse<ConversationResponse>>> getConversations(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(chatService.getConversations(user, pageable)));
    }

    @GetMapping("/conversations/event/{eventId}")
    @Operation(summary = "Get or create event group chat")
    public ResponseEntity<ApiResponse<ConversationResponse>> getEventChat(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(chatService.getOrCreateEventChat(user, eventId)));
    }

    @GetMapping("/conversations/direct/{userId}")
    @Operation(summary = "Get or create direct chat with another user")
    public ResponseEntity<ApiResponse<ConversationResponse>> getDirectChat(
            @PathVariable UUID userId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(chatService.getOrCreateDirectChat(user, userId)));
    }

    @GetMapping("/conversations/{conversationId}/messages")
    @Operation(summary = "Get messages in a conversation")
    public ResponseEntity<ApiResponse<PageResponse<MessageResponse>>> getMessages(
            @PathVariable UUID conversationId,
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 50) Pageable pageable) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(chatService.getMessages(user, conversationId, pageable)));
    }

    @PostMapping("/conversations/{conversationId}/messages")
    @Operation(summary = "Send a message")
    public ResponseEntity<ApiResponse<MessageResponse>> sendMessage(
            @PathVariable UUID conversationId,
            @Valid @RequestBody SendMessageRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success("Message sent", chatService.sendMessage(user, conversationId, request)));
    }

    @PostMapping("/conversations/{conversationId}/read")
    @Operation(summary = "Mark conversation as read")
    public ResponseEntity<ApiResponse<Void>> markAsRead(
            @PathVariable UUID conversationId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        chatService.markAsRead(user, conversationId);
        return ResponseEntity.ok(ApiResponse.success("Marked as read", null));
    }

    @PutMapping("/conversations/{conversationId}/mute")
    @Operation(summary = "Mute or unmute a conversation")
    public ResponseEntity<ApiResponse<Void>> muteConversation(
            @PathVariable UUID conversationId,
            @RequestBody java.util.Map<String, Boolean> request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        Boolean muted = request.get("muted");
        chatService.muteConversation(user, conversationId, muted != null && muted);
        return ResponseEntity.ok(ApiResponse.success(muted != null && muted ? "Conversation muted" : "Conversation unmuted", null));
    }

    @PutMapping("/conversations/{conversationId}/pin")
    @Operation(summary = "Pin or unpin a conversation")
    public ResponseEntity<ApiResponse<Void>> pinConversation(
            @PathVariable UUID conversationId,
            @RequestBody java.util.Map<String, Boolean> request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        Boolean pinned = request.get("pinned");
        chatService.pinConversation(user, conversationId, pinned != null && pinned);
        return ResponseEntity.ok(ApiResponse.success(pinned != null && pinned ? "Conversation pinned" : "Conversation unpinned", null));
    }

    @PutMapping("/conversations/{conversationId}/archive")
    @Operation(summary = "Archive or unarchive a conversation")
    public ResponseEntity<ApiResponse<Void>> archiveConversation(
            @PathVariable UUID conversationId,
            @RequestBody java.util.Map<String, Boolean> request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        Boolean archived = request.get("archived");
        chatService.archiveConversation(user, conversationId, archived != null && archived);
        return ResponseEntity.ok(ApiResponse.success(archived != null && archived ? "Conversation archived" : "Conversation unarchived", null));
    }

    @GetMapping("/unread-count")
    @Operation(summary = "Get total unread messages count")
    public ResponseEntity<ApiResponse<Long>> getUnreadCount(
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(chatService.getUnreadCount(user)));
    }

    @GetMapping("/events/{eventId}/attendees")
    @Operation(summary = "Get event attendees that user can chat with")
    public ResponseEntity<ApiResponse<List<ConversationResponse.ParticipantResponse>>> getEventAttendees(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(chatService.getEventAttendees(user, eventId)));
    }

    @DeleteMapping("/messages/{messageId}")
    @Operation(summary = "Delete a message (only sender can delete)")
    public ResponseEntity<ApiResponse<Void>> deleteMessage(
            @PathVariable UUID messageId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        chatService.deleteMessage(user, messageId);
        return ResponseEntity.ok(ApiResponse.success("Message deleted", null));
    }

    @DeleteMapping("/conversations/{conversationId}")
    @Operation(summary = "Leave/delete a conversation")
    public ResponseEntity<ApiResponse<Void>> leaveConversation(
            @PathVariable UUID conversationId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        chatService.leaveConversation(user, conversationId);
        return ResponseEntity.ok(ApiResponse.success("Conversation deleted", null));
    }

    @GetMapping("/buddies")
    @Operation(summary = "Get event buddies - users who registered for the same events as current user")
    public ResponseEntity<ApiResponse<PageResponse<EventBuddyResponse>>> getEventBuddies(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(chatService.getEventBuddies(user, pageable)));
    }

    @GetMapping("/events/{eventId}/buddies")
    @Operation(summary = "Get event buddies for a specific event")
    public ResponseEntity<ApiResponse<List<EventBuddyResponse>>> getEventBuddiesByEvent(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(chatService.getEventBuddiesByEvent(user, eventId)));
    }

    @PostMapping("/conversations/group")
    @Operation(summary = "Create a new group chat")
    public ResponseEntity<ApiResponse<ConversationResponse>> createGroupChat(
            @Valid @RequestBody CreateGroupChatRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        ConversationResponse response = chatService.createGroupChat(user, request);
        return ResponseEntity.ok(ApiResponse.success("Group chat created successfully", response));
    }

    @PostMapping("/conversations/{conversationId}/participants")
    @Operation(summary = "Add participants to a group chat")
    public ResponseEntity<ApiResponse<ConversationResponse>> addParticipants(
            @PathVariable UUID conversationId,
            @RequestBody List<UUID> userIds,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        ConversationResponse response = chatService.addGroupParticipants(user, conversationId, userIds);
        return ResponseEntity.ok(ApiResponse.success("Participants added successfully", response));
    }

    @DeleteMapping("/conversations/{conversationId}/participants/{userId}")
    @Operation(summary = "Remove a participant from a group chat")
    public ResponseEntity<ApiResponse<Void>> removeParticipant(
            @PathVariable UUID conversationId,
            @PathVariable UUID userId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        chatService.removeGroupParticipant(user, conversationId, userId);
        return ResponseEntity.ok(ApiResponse.success("Participant removed successfully", null));
    }

    @PostMapping("/block/{userId}")
    @Operation(summary = "Block a user")
    public ResponseEntity<ApiResponse<Void>> blockUser(
            @PathVariable UUID userId,
            @RequestBody(required = false) java.util.Map<String, String> request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        String reason = request != null ? request.get("reason") : null;
        chatService.blockUser(user, userId, reason);
        return ResponseEntity.ok(ApiResponse.success("User blocked successfully", null));
    }

    @DeleteMapping("/block/{userId}")
    @Operation(summary = "Unblock a user")
    public ResponseEntity<ApiResponse<Void>> unblockUser(
            @PathVariable UUID userId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        chatService.unblockUser(user, userId);
        return ResponseEntity.ok(ApiResponse.success("User unblocked successfully", null));
    }

    @GetMapping("/blocked")
    @Operation(summary = "Get list of blocked users")
    public ResponseEntity<ApiResponse<List<BlockedUserResponse>>> getBlockedUsers(
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(chatService.getBlockedUsers(user)));
    }

    @GetMapping("/block/{userId}/status")
    @Operation(summary = "Check if a user is blocked")
    public ResponseEntity<ApiResponse<Boolean>> isUserBlocked(
            @PathVariable UUID userId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(chatService.isUserBlocked(user, userId)));
    }
}

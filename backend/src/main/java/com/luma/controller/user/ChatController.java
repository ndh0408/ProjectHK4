package com.luma.controller.user;

import com.luma.dto.request.CreateGroupChatRequest;
import com.luma.dto.request.SendMessageRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.BlockedUserResponse;
import com.luma.dto.response.ConversationResponse;
import com.luma.dto.response.EventBuddyResponse;
import com.luma.dto.response.EventChatSummaryResponse;
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

    @GetMapping("/conversations/{conversationId}")
    @Operation(summary = "Get a conversation by id")
    public ResponseEntity<ApiResponse<ConversationResponse>> getConversation(
            @PathVariable UUID conversationId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(chatService.getConversation(user, conversationId)));
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
    @Operation(summary = "Delete a message (sender can always delete; event organiser can delete any message in their EVENT_GROUP chat)")
    public ResponseEntity<ApiResponse<Void>> deleteMessage(
            @PathVariable UUID messageId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        chatService.deleteMessage(user, messageId);
        return ResponseEntity.ok(ApiResponse.success("Message deleted", null));
    }

    @PostMapping("/conversations/{conversationId}/pin/{messageId}")
    @Operation(summary = "Pin a message as the conversation announcement (organiser only for EVENT_GROUP)")
    public ResponseEntity<ApiResponse<ConversationResponse>> pinMessage(
            @PathVariable UUID conversationId,
            @PathVariable UUID messageId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        ConversationResponse response = chatService.pinMessage(user, conversationId, messageId);
        return ResponseEntity.ok(ApiResponse.success("Message pinned", response));
    }

    @DeleteMapping("/conversations/{conversationId}/pin")
    @Operation(summary = "Unpin the currently pinned announcement (organiser only)")
    public ResponseEntity<ApiResponse<ConversationResponse>> unpinMessage(
            @PathVariable UUID conversationId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        ConversationResponse response = chatService.unpinMessage(user, conversationId);
        return ResponseEntity.ok(ApiResponse.success("Message unpinned", response));
    }

    @PostMapping("/conversations/{conversationId}/participants/{targetUserId}/ban")
    @Operation(summary = "Ban an attendee from the event chat (organiser only)")
    public ResponseEntity<ApiResponse<Void>> banParticipant(
            @PathVariable UUID conversationId,
            @PathVariable UUID targetUserId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        chatService.banParticipant(user, conversationId, targetUserId);
        return ResponseEntity.ok(ApiResponse.success("Participant banned", null));
    }

    @DeleteMapping("/conversations/{conversationId}/participants/{targetUserId}/ban")
    @Operation(summary = "Lift a ban on an attendee (organiser only)")
    public ResponseEntity<ApiResponse<Void>> unbanParticipant(
            @PathVariable UUID conversationId,
            @PathVariable UUID targetUserId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        chatService.unbanParticipant(user, conversationId, targetUserId);
        return ResponseEntity.ok(ApiResponse.success("Participant unbanned", null));
    }

    @PostMapping("/conversations/{conversationId}/participants/{targetUserId}/mute")
    @Operation(summary = "Temporarily mute an attendee (organiser only). Pass minutes=0 to unmute.")
    public ResponseEntity<ApiResponse<Void>> muteParticipant(
            @PathVariable UUID conversationId,
            @PathVariable UUID targetUserId,
            @RequestParam(defaultValue = "60") int minutes,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        chatService.muteParticipant(user, conversationId, targetUserId, minutes);
        return ResponseEntity.ok(ApiResponse.success(minutes <= 0 ? "Participant unmuted" : "Participant muted", null));
    }

    @GetMapping("/conversations/{conversationId}/messages/search")
    @Operation(summary = "Search messages in a conversation by text content")
    public ResponseEntity<ApiResponse<PageResponse<MessageResponse>>> searchMessages(
            @PathVariable UUID conversationId,
            @RequestParam String q,
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 30) Pageable pageable) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(
                chatService.searchMessages(user, conversationId, q, pageable)));
    }

    @PostMapping("/events/{eventId}/contact-organiser")
    @Operation(summary = "Open (or create) a 1:1 support DM with the event organiser")
    public ResponseEntity<ApiResponse<ConversationResponse>> contactOrganiser(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(
                chatService.openSupportConversationWithOrganiser(user, eventId)));
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

    @GetMapping("/event-chats")
    @Operation(summary = "List event group chats for events the user has an APPROVED registration to")
    public ResponseEntity<ApiResponse<List<EventChatSummaryResponse>>> getEventChats(
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(chatService.getEventChats(user)));
    }

    @PostMapping("/event-chats/{eventId}/join")
    @Operation(summary = "Opt in to the group chat for a registered event")
    public ResponseEntity<ApiResponse<EventChatSummaryResponse>> joinEventChat(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        EventChatSummaryResponse response = chatService.joinEventChat(user, eventId);
        return ResponseEntity.ok(ApiResponse.success("Joined event chat", response));
    }

    @DeleteMapping("/event-chats/{eventId}/leave")
    @Operation(summary = "Leave an event group chat")
    public ResponseEntity<ApiResponse<Void>> leaveEventChat(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        chatService.leaveEventChat(user, eventId);
        return ResponseEntity.ok(ApiResponse.success("Left event chat", null));
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

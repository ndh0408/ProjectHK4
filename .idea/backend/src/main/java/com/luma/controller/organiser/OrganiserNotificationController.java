package com.luma.controller.organiser;

import com.luma.dto.request.SendEventNotificationRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.NotificationResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.Event;
import com.luma.entity.User;
import com.luma.exception.BadRequestException;
import com.luma.service.EventService;
import com.luma.service.NotificationService;
import com.luma.service.UserService;
import jakarta.validation.Valid;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/organiser/notifications")
@RequiredArgsConstructor
@Tag(name = "Organiser Notifications", description = "APIs for organiser notification management")
public class OrganiserNotificationController {

    private final NotificationService notificationService;
    private final UserService userService;
    private final EventService eventService;

    @GetMapping
    @Operation(summary = "Get organiser notifications")
    public ResponseEntity<ApiResponse<PageResponse<NotificationResponse>>> getNotifications(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(notificationService.getUserNotifications(user, pageable)));
    }

    @GetMapping("/unread")
    @Operation(summary = "Get unread notifications")
    public ResponseEntity<ApiResponse<PageResponse<NotificationResponse>>> getUnreadNotifications(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(notificationService.getUnreadNotifications(user, pageable)));
    }

    @GetMapping("/unread-count")
    @Operation(summary = "Get unread notification count")
    public ResponseEntity<ApiResponse<Map<String, Long>>> getUnreadCount(@AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        long count = notificationService.getUnreadCount(user);
        return ResponseEntity.ok(ApiResponse.success(Map.of("count", count)));
    }

    @PutMapping("/{id}/read")
    @Operation(summary = "Mark notification as read")
    public ResponseEntity<ApiResponse<Void>> markAsRead(@PathVariable UUID id) {
        notificationService.markAsRead(id);
        return ResponseEntity.ok(ApiResponse.success("Notification marked as read", null));
    }

    @PutMapping("/read-all")
    @Operation(summary = "Mark all notifications as read")
    public ResponseEntity<ApiResponse<Void>> markAllAsRead(@AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        notificationService.markAllAsRead(user);
        return ResponseEntity.ok(ApiResponse.success("All notifications marked as read", null));
    }

    @PostMapping("/reply")
    @Operation(summary = "Send a reply message to a user")
    public ResponseEntity<ApiResponse<NotificationResponse>> sendReply(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody Map<String, String> request) {
        User sender = userService.getEntityByEmail(userDetails.getUsername());
        UUID recipientId = UUID.fromString(request.get("recipientId"));
        String message = request.get("message");
        UUID eventId = request.get("eventId") != null ? UUID.fromString(request.get("eventId")) : null;

        var notification = notificationService.sendReplyToUser(sender, recipientId, message, eventId);
        return ResponseEntity.ok(ApiResponse.success("Reply sent successfully", NotificationResponse.fromEntity(notification)));
    }

    @PostMapping("/send-to-attendees")
    @Operation(summary = "Send notification to event attendees based on notification type")
    public ResponseEntity<ApiResponse<Map<String, Integer>>> sendToEventAttendees(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody SendEventNotificationRequest request) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        Event event = eventService.getEntityById(request.getEventId());

        if (!event.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You can only send notifications to your own event attendees");
        }

        int count = notificationService.sendNotificationByType(
                event, organiser, request.getTitle(), request.getMessage(), request.getNotificationType());

        return ResponseEntity.ok(ApiResponse.success(
                "Notification sent to " + count + " recipients",
                Map.of("recipientCount", count)));
    }

    @GetMapping("/recipient-count")
    @Operation(summary = "Get recipient count for a notification type")
    public ResponseEntity<ApiResponse<Map<String, Long>>> getRecipientCount(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam UUID eventId,
            @RequestParam String notificationType) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        Event event = eventService.getEntityById(eventId);

        if (!event.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You can only view recipient counts for your own events");
        }

        long count = notificationService.getRecipientCountByType(event, organiser, notificationType);

        return ResponseEntity.ok(ApiResponse.success(Map.of("recipientCount", count)));
    }
}

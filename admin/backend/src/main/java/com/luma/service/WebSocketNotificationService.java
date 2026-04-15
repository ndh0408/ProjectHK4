package com.luma.service;

import com.luma.dto.response.NotificationResponse;
import com.luma.entity.Notification;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class WebSocketNotificationService {

    private final SimpMessagingTemplate messagingTemplate;

    public void sendToUser(UUID userId, Notification notification) {
        try {
            NotificationResponse response = NotificationResponse.fromEntity(notification);
            messagingTemplate.convertAndSendToUser(
                    userId.toString(),
                    "/queue/notifications",
                    response
            );
            log.debug("WebSocket notification sent to user: {}", userId);
        } catch (Exception e) {
            log.error("Failed to send WebSocket notification to user {}: {}", userId, e.getMessage());
        }
    }

    public void sendToUser(UUID userId, NotificationResponse notification) {
        try {
            messagingTemplate.convertAndSendToUser(
                    userId.toString(),
                    "/queue/notifications",
                    notification
            );
            log.debug("WebSocket notification sent to user: {}", userId);
        } catch (Exception e) {
            log.error("Failed to send WebSocket notification to user {}: {}", userId, e.getMessage());
        }
    }

    public void broadcast(NotificationResponse notification) {
        try {
            messagingTemplate.convertAndSend("/topic/notifications", notification);
            log.debug("Broadcast notification sent");
        } catch (Exception e) {
            log.error("Failed to broadcast notification: {}", e.getMessage());
        }
    }
}

package com.luma.config;

import com.luma.entity.User;
import com.luma.service.ChatWebSocketService;
import com.luma.service.UserService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.event.EventListener;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.messaging.SessionConnectedEvent;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

import java.security.Principal;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
@RequiredArgsConstructor
@Slf4j
public class WebSocketEventListener {

    private final ChatWebSocketService webSocketService;
    private final UserService userService;

    private final Map<String, String> sessionUserMap = new ConcurrentHashMap<>();

    @EventListener
    public void handleWebSocketConnectListener(SessionConnectedEvent event) {
        StompHeaderAccessor headerAccessor = StompHeaderAccessor.wrap(event.getMessage());
        Principal principal = headerAccessor.getUser();

        if (principal != null) {
            String sessionId = headerAccessor.getSessionId();
            String email = principal.getName();
            sessionUserMap.put(sessionId, email);

            try {
                User user = userService.getEntityByEmail(email);
                webSocketService.broadcastOnlineStatus(user.getId(), user.getFullName(), true);
                log.info("User connected: {} (session: {})", email, sessionId);
            } catch (Exception e) {
                log.error("Error handling connect for user: {}", email, e);
            }
        }
    }

    @EventListener
    public void handleWebSocketDisconnectListener(SessionDisconnectEvent event) {
        StompHeaderAccessor headerAccessor = StompHeaderAccessor.wrap(event.getMessage());
        String sessionId = headerAccessor.getSessionId();
        String email = sessionUserMap.remove(sessionId);

        if (email != null) {
            try {
                User user = userService.getEntityByEmail(email);
                webSocketService.broadcastOnlineStatus(user.getId(), user.getFullName(), false);
                log.info("User disconnected: {} (session: {})", email, sessionId);
            } catch (Exception e) {
                log.error("Error handling disconnect for user: {}", email, e);
            }
        }
    }

    public boolean isUserOnline(String email) {
        return sessionUserMap.containsValue(email);
    }
}

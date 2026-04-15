package com.luma.controller.websocket;

import com.luma.entity.User;
import com.luma.service.ChatWebSocketService;
import com.luma.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.stereotype.Controller;

import java.security.Principal;
import java.util.UUID;

@Controller
@RequiredArgsConstructor
public class ChatWebSocketController {

    private final ChatWebSocketService webSocketService;
    private final UserService userService;

    @MessageMapping("/chat/{conversationId}/typing")
    public void handleTyping(
            @DestinationVariable UUID conversationId,
            SimpMessageHeaderAccessor headerAccessor) {
        Principal principal = headerAccessor.getUser();
        if (principal != null) {
            User user = userService.getEntityByEmail(principal.getName());
            webSocketService.broadcastTyping(conversationId, user.getId(), user.getFullName());
        }
    }

    @MessageMapping("/chat/{conversationId}/read")
    public void handleRead(
            @DestinationVariable UUID conversationId,
            SimpMessageHeaderAccessor headerAccessor) {
        Principal principal = headerAccessor.getUser();
        if (principal != null) {
            User user = userService.getEntityByEmail(principal.getName());
            webSocketService.broadcastRead(conversationId, user.getId());
        }
    }
}

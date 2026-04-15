package com.luma.controller.user;

import com.luma.dto.response.ApiResponse;
import com.luma.entity.User;
import com.luma.service.AIAssistantService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/user/assistant")
@RequiredArgsConstructor
@Tag(name = "AI Assistant", description = "Conversational AI chatbot for event discovery")
public class UserAIAssistantController {

    private final AIAssistantService assistantService;
    private final UserService userService;

    @PostMapping("/chat")
    @Operation(summary = "Chat with AI assistant — detects intent, queries DB, generates natural response")
    public ResponseEntity<ApiResponse<Map<String, Object>>> chat(
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserDetails userDetails) {
        String message = body.get("message");
        if (message == null || message.isBlank()) {
            throw new com.luma.exception.BadRequestException("Message is required");
        }

        User user = userDetails != null
                ? userService.getEntityByEmail(userDetails.getUsername())
                : null;

        Map<String, Object> result = assistantService.chat(message, user);
        return ResponseEntity.ok(ApiResponse.success(result));
    }
}

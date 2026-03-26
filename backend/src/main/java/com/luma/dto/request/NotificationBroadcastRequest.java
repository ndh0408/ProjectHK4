package com.luma.dto.request;

import com.luma.entity.enums.UserRole;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class NotificationBroadcastRequest {
    
    @NotBlank(message = "Title is required")
    private String title;

    @NotBlank(message = "Message is required")
    private String message;
    
    private UserRole targetRole; // null = all users
}

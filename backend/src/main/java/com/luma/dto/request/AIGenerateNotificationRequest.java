package com.luma.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class AIGenerateNotificationRequest {
    @NotBlank(message = "Event title is required")
    private String eventTitle;

    @NotBlank(message = "Notification type is required")
    private String notificationType;

    private String additionalContext;
}

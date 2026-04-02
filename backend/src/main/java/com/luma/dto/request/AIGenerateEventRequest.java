package com.luma.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class AIGenerateEventRequest {

    @NotBlank(message = "Event idea is required")
    private String eventIdea;

    private String eventType;

    private String targetAudience;

    private String preferredDate;

    private String preferredTime;

    private Long cityId;

    private String language = "vi";
}

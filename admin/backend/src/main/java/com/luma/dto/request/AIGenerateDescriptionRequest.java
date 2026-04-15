package com.luma.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class AIGenerateDescriptionRequest {
    @NotBlank(message = "Title is required")
    private String title;

    private String category;
    private String venue;
    private String address;
    private String startTime;
    private String endTime;
}

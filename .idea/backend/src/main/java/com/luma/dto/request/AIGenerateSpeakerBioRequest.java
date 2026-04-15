package com.luma.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class AIGenerateSpeakerBioRequest {
    @NotBlank(message = "Speaker name is required")
    private String name;

    @NotBlank(message = "Speaker title is required")
    private String title;

    private String eventTitle;
}

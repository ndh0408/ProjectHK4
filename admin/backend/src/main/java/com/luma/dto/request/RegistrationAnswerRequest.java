package com.luma.dto.request;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.UUID;

@Data
public class RegistrationAnswerRequest {

    @NotNull(message = "Question ID is required")
    private UUID questionId;

    private String answer;
}

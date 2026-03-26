package com.luma.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class QuestionRequest {
    
    @NotBlank(message = "Question is required")
    private String question;
}

package com.luma.dto.request;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class AIGenerateQuestionsRequest {
    @NotBlank(message = "Event title is required")
    private String eventTitle;

    private String eventCategory;

    private String eventDescription;

    @Min(value = 1, message = "Number of questions must be at least 1")
    @Max(value = 10, message = "Number of questions must be at most 10")
    private int numberOfQuestions = 3;
}

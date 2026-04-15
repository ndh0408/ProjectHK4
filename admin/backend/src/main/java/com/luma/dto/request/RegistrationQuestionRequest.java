package com.luma.dto.request;

import com.luma.entity.enums.QuestionType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.List;
import java.util.UUID;

@Data
public class RegistrationQuestionRequest {

    private UUID id;

    @NotBlank(message = "Question text is required")
    private String questionText;

    @NotNull(message = "Question type is required")
    private QuestionType questionType;

    private List<String> options;

    private boolean required = true;

    private int displayOrder = 0;
}

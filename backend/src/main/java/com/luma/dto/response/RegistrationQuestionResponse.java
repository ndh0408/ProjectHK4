package com.luma.dto.response;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.luma.entity.RegistrationQuestion;
import com.luma.entity.enums.QuestionType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Collections;
import java.util.List;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RegistrationQuestionResponse {

    private UUID id;
    private String questionText;
    private QuestionType questionType;
    private List<String> options;
    private boolean required;
    private int displayOrder;

    private static final ObjectMapper objectMapper = new ObjectMapper();

    public static RegistrationQuestionResponse fromEntity(RegistrationQuestion question) {
        List<String> optionsList = Collections.emptyList();

        if (question.getOptions() != null && !question.getOptions().isEmpty()) {
            try {
                optionsList = objectMapper.readValue(question.getOptions(),
                        new TypeReference<List<String>>() {});
            } catch (Exception e) {
            }
        }

        return RegistrationQuestionResponse.builder()
                .id(question.getId())
                .questionText(question.getQuestionText())
                .questionType(question.getQuestionType())
                .options(optionsList)
                .required(question.isRequired())
                .displayOrder(question.getDisplayOrder())
                .build();
    }
}

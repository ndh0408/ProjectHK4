package com.luma.dto.response;

import com.luma.entity.RegistrationAnswer;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RegistrationAnswerResponse {

    private UUID id;
    private UUID questionId;
    private String questionText;
    private String answer;

    public static RegistrationAnswerResponse fromEntity(RegistrationAnswer answer) {
        return RegistrationAnswerResponse.builder()
                .id(answer.getId())
                .questionId(answer.getQuestion().getId())
                .questionText(answer.getQuestion().getQuestionText())
                .answer(answer.getAnswerText())
                .build();
    }
}

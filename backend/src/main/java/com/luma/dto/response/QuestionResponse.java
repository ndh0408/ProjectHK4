package com.luma.dto.response;

import com.luma.entity.Question;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class QuestionResponse {

    private UUID id;
    private UUID eventId;
    private String eventTitle;
    private UUID userId;
    private String userName;
    private String userAvatarUrl;
    private String question;
    private String answer;
    private boolean isAnswered;
    private LocalDateTime createdAt;
    private LocalDateTime answeredAt;

    public static QuestionResponse fromEntity(Question question) {
        return QuestionResponse.builder()
                .id(question.getId())
                .eventId(question.getEvent().getId())
                .eventTitle(question.getEvent().getTitle())
                .userId(question.getUser().getId())
                .userName(question.getUser().getFullName())
                .userAvatarUrl(question.getUser().getAvatarUrl())
                .question(question.getQuestion())
                .answer(question.getAnswer())
                .isAnswered(question.isAnswered())
                .createdAt(question.getCreatedAt())
                .answeredAt(question.getAnsweredAt())
                .build();
    }
}

package com.luma.dto.response;

import lombok.*;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SmartAnswerResponse {
    private String questionId;
    private String suggestedAnswer;
    private int similarQuestionsFound;
    private int eventFAQsCount;
    private boolean contextUsed;
    private List<SimilarQuestion> similarQuestions;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SimilarQuestion {
        private String question;
        private String answer;
    }
}

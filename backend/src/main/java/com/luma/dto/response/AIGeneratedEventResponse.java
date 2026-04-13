package com.luma.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AIGeneratedEventResponse {

    private List<String> titleSuggestions;

    private String description;

    private String suggestedCategory;

    private Long categoryId;

    private String suggestedVenue;

    private String suggestedAddress;

    private String suggestedStartTime;

    private String suggestedEndTime;

    private Integer suggestedCapacity;

    private BigDecimal suggestedPrice;

    private Boolean isFree;

    private String suggestedCity;

    private Long cityId;

    private List<SpeakerSuggestion> suggestedSpeakers;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SpeakerSuggestion {
        private String name;
        private String title;
        private String bio;
    }
}

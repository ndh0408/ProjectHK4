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

    private String suggestedVenue;

    private String suggestedAddress;

    private Integer suggestedCapacity;

    private BigDecimal suggestedPrice;

    private Boolean isFree;

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

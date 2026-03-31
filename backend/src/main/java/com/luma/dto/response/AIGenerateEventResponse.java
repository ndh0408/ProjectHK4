package com.luma.dto.response;

import com.luma.entity.enums.EventVisibility;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AIGenerateEventResponse {

    private String title;
    private String description;
    private LocalDateTime startTime;
    private LocalDateTime endTime;
    private String venue;
    private String address;
    private String suggestedCategory;
    private Long suggestedCategoryId;
    private String suggestedCity;
    private Long suggestedCityId;
    private boolean isFree;
    private BigDecimal ticketPrice;
    private Integer capacity;
    private EventVisibility visibility;
    private List<SuggestedSpeaker> speakers;

    // AI reasoning/explanation
    private String aiExplanation;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SuggestedSpeaker {
        private String name;
        private String title;
        private String bio;
    }
}

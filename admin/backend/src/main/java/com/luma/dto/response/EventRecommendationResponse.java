package com.luma.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EventRecommendationResponse {
    private List<EventResponse> recommendedEvents;
    private List<EventResponse> similarEvents;
    private List<EventResponse> trendingEvents;
    private String recommendationType;
}

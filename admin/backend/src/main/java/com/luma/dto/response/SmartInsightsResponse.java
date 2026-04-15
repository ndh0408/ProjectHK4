package com.luma.dto.response;

import lombok.*;

import java.util.List;
import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SmartInsightsResponse {
    private String summary;
    private Integer performanceScore;
    private List<Insight> insights;
    private List<String> recommendations;
    private Map<String, Object> rawStats;
    private Map<String, Object> benchmarks;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Insight {
        private String type;
        private String title;
        private String description;
        private String actionText;
        private String priority;
    }
}

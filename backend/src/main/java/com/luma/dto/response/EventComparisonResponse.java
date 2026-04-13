package com.luma.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EventComparisonResponse {

    private List<ComparedEvent> events;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ComparedEvent {
        private UUID id;
        private String title;
        private String imageUrl;
        private String organiserName;
        private LocalDateTime startTime;
        private LocalDateTime endTime;
        private String venue;
        private String address;
        private String cityName;
        private String categoryName;
        private BigDecimal ticketPrice;
        private int capacity;
        private int registrationCount;
        private double fillRate;
        private Double averageRating;
        private long reviewCount;
        private boolean isFree;
        private String status;
    }
}

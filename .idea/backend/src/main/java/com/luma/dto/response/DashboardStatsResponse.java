package com.luma.dto.response;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

@Data
@Builder
public class DashboardStatsResponse {
    private long totalEvents;
    private long publishedEvents;
    private long draftEvents;
    private long completedEvents;
    private long cancelledEvents;
    private long totalRegistrations;
    private long approvedRegistrations;
    private long pendingRegistrations;
    private long totalFollowers;
    private BigDecimal totalRevenue;
    private List<RegistrationGrowthData> registrationGrowth;
    private List<RecentEventData> recentEvents;

    @Data
    @Builder
    public static class RegistrationGrowthData {
        private String date;
        private long count;
    }

    @Data
    @Builder
    public static class RecentEventData {
        private String id;
        private String title;
        private String status;
        private String imageUrl;
        private int currentRegistrations;
        private int capacity;
    }
}

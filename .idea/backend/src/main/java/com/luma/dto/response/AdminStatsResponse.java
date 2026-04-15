package com.luma.dto.response;

import lombok.Builder;
import lombok.Data;

import java.util.List;
import java.util.Map;

@Data
@Builder
public class AdminStatsResponse {
    private long totalUsers;
    private long totalOrganisers;
    private long totalAdmins;
    private long activeUsers;
    private long lockedUsers;
    private long totalEvents;
    private long publishedEvents;
    private long totalRegistrations;
    private long totalCities;
    private long totalCategories;
    private List<MonthlyStats> newUsersPerMonth;
    private List<MonthlyStats> newEventsPerMonth;
    private List<CityEventStats> eventsByCity;
    private List<CategoryEventStats> eventsByCategory;

    @Data
    @Builder
    public static class MonthlyStats {
        private int year;
        private int month;
        private long count;
    }

    @Data
    @Builder
    public static class CityEventStats {
        private Long cityId;
        private String cityName;
        private long eventCount;
    }

    @Data
    @Builder
    public static class CategoryEventStats {
        private Long categoryId;
        private String categoryName;
        private long eventCount;
    }
}

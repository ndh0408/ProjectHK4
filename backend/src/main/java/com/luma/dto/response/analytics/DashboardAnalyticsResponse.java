package com.luma.dto.response.analytics;

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
public class DashboardAnalyticsResponse {

    private long totalUsers;
    private long newUsersThisMonth;
    private double userGrowthPercent;

    private long totalEvents;
    private long newEventsThisMonth;
    private double eventGrowthPercent;

    private long totalRegistrations;
    private long newRegistrationsThisMonth;
    private double registrationGrowthPercent;

    private BigDecimal totalRevenue;
    private BigDecimal revenueThisMonth;
    private double revenueGrowthPercent;

    private List<TimeSeriesData> userGrowthChart;
    private List<TimeSeriesData> eventGrowthChart;
    private List<TimeSeriesData> registrationGrowthChart;
    private List<TimeSeriesData> revenueChart;

    private List<CategoryDistribution> eventsByCategory;
    private List<CityDistribution> eventsByCity;
    private List<StatusDistribution> eventsByStatus;

    private List<TopOrganiser> topOrganisers;
    private List<TopEvent> topEvents;
}

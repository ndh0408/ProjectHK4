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

    // Overview metrics
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

    // Charts data
    private List<TimeSeriesData> userGrowthChart;
    private List<TimeSeriesData> eventGrowthChart;
    private List<TimeSeriesData> registrationGrowthChart;
    private List<TimeSeriesData> revenueChart;

    // Distribution data
    private List<CategoryDistribution> eventsByCategory;
    private List<CityDistribution> eventsByCity;
    private List<StatusDistribution> eventsByStatus;

    // Top performers
    private List<TopOrganiser> topOrganisers;
    private List<TopEvent> topEvents;
}

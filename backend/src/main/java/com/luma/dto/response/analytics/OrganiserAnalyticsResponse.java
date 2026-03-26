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
public class OrganiserAnalyticsResponse {

    private long totalEvents;
    private long activeEvents;
    private long totalRegistrations;
    private BigDecimal totalRevenue;

    private List<TimeSeriesData> registrationGrowthChart;
    private List<TimeSeriesData> revenueChart;
    private List<EventPerformance> eventPerformances;
}

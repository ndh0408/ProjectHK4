package com.luma.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RevenueStatsResponse {

    // Total Revenue
    private BigDecimal totalRevenue;
    private BigDecimal subscriptionRevenue;
    private BigDecimal boostRevenue;

    // This Month
    private BigDecimal monthlyRevenue;
    private BigDecimal monthlySubscriptionRevenue;
    private BigDecimal monthlyBoostRevenue;

    // Last Month (for comparison)
    private BigDecimal lastMonthRevenue;
    private BigDecimal lastMonthSubscriptionRevenue;
    private BigDecimal lastMonthBoostRevenue;

    // Growth percentages
    private Double revenueGrowthPercent;
    private Double subscriptionGrowthPercent;
    private Double boostGrowthPercent;

    // Counts
    private int totalSubscriptions;
    private int activeSubscriptions;
    private int totalBoosts;
    private int activeBoosts;

    // By Subscription Plan
    private Map<String, PlanStats> subscriptionByPlan;

    // By Boost Package
    private Map<String, PackageStats> boostByPackage;

    // Monthly Trend (last 12 months)
    private List<MonthlyRevenue> monthlyTrend;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class PlanStats {
        private String plan;
        private int count;
        private BigDecimal revenue;
        private BigDecimal monthlyRecurringRevenue; // MRR
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class PackageStats {
        private String packageName;
        private int count;
        private BigDecimal revenue;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class MonthlyRevenue {
        private String month; // "2024-01"
        private BigDecimal subscriptionRevenue;
        private BigDecimal boostRevenue;
        private BigDecimal totalRevenue;
    }
}

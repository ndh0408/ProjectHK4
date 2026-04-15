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

    private BigDecimal totalRevenue;
    private BigDecimal subscriptionRevenue;
    private BigDecimal boostRevenue;

    private BigDecimal monthlyRevenue;
    private BigDecimal monthlySubscriptionRevenue;
    private BigDecimal monthlyBoostRevenue;

    private BigDecimal lastMonthRevenue;
    private BigDecimal lastMonthSubscriptionRevenue;
    private BigDecimal lastMonthBoostRevenue;

    private Double revenueGrowthPercent;
    private Double subscriptionGrowthPercent;
    private Double boostGrowthPercent;

    private int totalSubscriptions;
    private int activeSubscriptions;
    private int totalBoosts;
    private int activeBoosts;

    private Map<String, PlanStats> subscriptionByPlan;

    private Map<String, PackageStats> boostByPackage;

    private List<MonthlyRevenue> monthlyTrend;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class PlanStats {
        private String plan;
        private int count;
        private BigDecimal revenue;
        private BigDecimal monthlyRecurringRevenue;
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
        private String month;
        private BigDecimal subscriptionRevenue;
        private BigDecimal boostRevenue;
        private BigDecimal totalRevenue;
    }
}

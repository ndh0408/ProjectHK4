package com.luma.dto.response;

import com.luma.service.CommissionService.OrganiserRevenueStats;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OrganiserStatsResponse {

    private BigDecimal totalSales;
    private BigDecimal totalEarnings;
    private BigDecimal totalCommissionPaid;
    private BigDecimal pendingPayout;
    private BigDecimal settledPayout;
    private BigDecimal currentCommissionRate;
    private long transactionCount;

    public static OrganiserStatsResponse fromStats(OrganiserRevenueStats stats) {
        return OrganiserStatsResponse.builder()
                .totalSales(stats.totalSales())
                .totalEarnings(stats.totalEarnings())
                .totalCommissionPaid(stats.totalCommissionPaid())
                .pendingPayout(stats.pendingPayout())
                .settledPayout(stats.settledPayout())
                .currentCommissionRate(stats.currentCommissionRate())
                .transactionCount(stats.transactionCount())
                .build();
    }
}

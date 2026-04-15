package com.luma.dto.response;

import com.luma.service.CommissionService.PlatformCommissionStats;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PlatformStatsResponse {

    private BigDecimal totalCommission;
    private BigDecimal totalSales;
    private BigDecimal pendingPayouts;
    private long totalTransactions;
    private long pendingTransactions;

    public static PlatformStatsResponse fromStats(PlatformCommissionStats stats) {
        return PlatformStatsResponse.builder()
                .totalCommission(stats.totalCommission())
                .totalSales(stats.totalSales())
                .pendingPayouts(stats.pendingPayouts())
                .totalTransactions(stats.totalTransactions())
                .pendingTransactions(stats.pendingTransactions())
                .build();
    }
}

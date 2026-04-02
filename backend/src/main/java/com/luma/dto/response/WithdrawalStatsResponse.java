package com.luma.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class WithdrawalStatsResponse {

    private long pendingCount;

    private long approvedCount;

    private long processingCount;

    private long completedCount;

    private long rejectedCount;

    private BigDecimal pendingAmount;

    private BigDecimal completedAmount;

    private BigDecimal totalPlatformCommission;

    private BigDecimal totalOrganiserEarnings;

    private String currency;
}

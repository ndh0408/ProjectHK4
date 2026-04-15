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
public class PayoutSummaryResponse {

    private BigDecimal totalEarnings;
    private BigDecimal totalPaidOut;
    private BigDecimal pendingPayout;
    private BigDecimal totalPlatformFees;
    private long totalPayouts;
    private long pendingPayoutsCount;
    private long completedPayoutsCount;
    private long failedPayoutsCount;
}

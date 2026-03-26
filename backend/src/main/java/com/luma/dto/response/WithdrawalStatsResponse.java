package com.luma.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Response DTO for admin withdrawal statistics
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class WithdrawalStatsResponse {

    /**
     * Total pending withdrawal requests count
     */
    private long pendingCount;

    /**
     * Total approved (waiting to process) requests count
     */
    private long approvedCount;

    /**
     * Total processing requests count
     */
    private long processingCount;

    /**
     * Total completed requests count
     */
    private long completedCount;

    /**
     * Total rejected requests count
     */
    private long rejectedCount;

    /**
     * Total pending withdrawal amount
     */
    private BigDecimal pendingAmount;

    /**
     * Total completed withdrawal amount
     */
    private BigDecimal completedAmount;

    /**
     * Total platform commission earned
     */
    private BigDecimal totalPlatformCommission;

    /**
     * Total organiser earnings
     */
    private BigDecimal totalOrganiserEarnings;

    /**
     * Currency
     */
    private String currency;
}

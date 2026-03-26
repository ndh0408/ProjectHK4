package com.luma.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Response DTO for organiser balance information
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BalanceResponse {

    /**
     * Total earnings from all confirmed transactions
     */
    private BigDecimal totalEarnings;

    /**
     * Amount available for withdrawal (totalEarnings - pendingWithdrawals - completedWithdrawals)
     */
    private BigDecimal availableBalance;

    /**
     * Amount currently pending in withdrawal requests
     */
    private BigDecimal pendingWithdrawals;

    /**
     * Amount already withdrawn
     */
    private BigDecimal completedWithdrawals;

    /**
     * Minimum amount required for withdrawal
     */
    private BigDecimal minWithdrawalAmount;

    /**
     * Current commission rate for this organiser
     */
    private BigDecimal commissionRate;

    /**
     * Currency
     */
    private String currency;

    /**
     * Whether the organiser has a connected bank account
     */
    private boolean hasBankAccount;

    /**
     * Whether payouts are enabled for this organiser
     */
    private boolean payoutsEnabled;
}

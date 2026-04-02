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
public class BalanceResponse {

    private BigDecimal totalEarnings;

    private BigDecimal availableBalance;

    private BigDecimal pendingWithdrawals;

    private BigDecimal completedWithdrawals;

    private BigDecimal minWithdrawalAmount;

    private BigDecimal commissionRate;

    private String currency;

    private boolean hasBankAccount;

    private boolean payoutsEnabled;
}

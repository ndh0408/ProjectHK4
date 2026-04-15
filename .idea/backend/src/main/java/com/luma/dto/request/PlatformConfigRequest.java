package com.luma.dto.request;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PlatformConfigRequest {

    @DecimalMin(value = "0.00", message = "Default commission rate must be at least 0%")
    @DecimalMax(value = "100.00", message = "Default commission rate cannot exceed 100%")
    private BigDecimal defaultCommissionRate;

    @DecimalMin(value = "0.00", message = "Minimum commission rate must be at least 0%")
    @DecimalMax(value = "100.00", message = "Minimum commission rate cannot exceed 100%")
    private BigDecimal minCommissionRate;

    @DecimalMin(value = "0.00", message = "Maximum commission rate must be at least 0%")
    @DecimalMax(value = "100.00", message = "Maximum commission rate cannot exceed 100%")
    private BigDecimal maxCommissionRate;

    @DecimalMin(value = "0.00", message = "Minimum payout amount cannot be negative")
    private BigDecimal minPayoutAmount;
}

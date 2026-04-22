package com.luma.dto.request;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class SubscriptionPlanConfigUpdateRequest {
    @NotNull
    private String displayName;

    @NotNull
    @Min(0)
    private BigDecimal monthlyPriceUsd;

    /** -1 means unlimited. */
    @NotNull
    private Integer maxEventsPerMonth;

    @NotNull
    @Min(0)
    private Integer boostDiscountPercent;

    private Boolean active;
    private Integer sortOrder;
}

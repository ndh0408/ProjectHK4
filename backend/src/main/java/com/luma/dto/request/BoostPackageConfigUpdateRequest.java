package com.luma.dto.request;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class BoostPackageConfigUpdateRequest {
    @NotNull
    private String displayName;

    @NotNull
    @Min(0)
    private BigDecimal priceUsd;

    @NotNull
    @Min(1)
    private Integer durationDays;

    @NotNull
    @Min(1)
    private Double boostMultiplier;

    @NotNull
    private String badgeText;

    private Boolean featuredInCategory;
    private Boolean featuredOnHome;
    private Boolean priorityInSearch;
    private Boolean homeBanner;
    private Boolean active;
    private Integer sortOrder;
}

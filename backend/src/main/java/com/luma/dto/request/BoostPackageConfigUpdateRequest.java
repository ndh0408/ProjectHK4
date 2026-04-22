package com.luma.dto.request;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class BoostPackageConfigUpdateRequest {
    @NotBlank(message = "Display name is required")
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

    @NotBlank(message = "Badge text is required")
    private String badgeText;

    private Boolean featuredInCategory;
    private Boolean featuredOnHome;
    private Boolean priorityInSearch;
    private Boolean homeBanner;
    private Boolean active;
    private Boolean discountEligible;
    private Integer discountPercent;
    private Integer sortOrder;
}

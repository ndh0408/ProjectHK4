package com.luma.entity.enums;

import lombok.Getter;

import java.math.BigDecimal;

@Getter
public enum BoostPackage {
    BASIC("Basic", 7, BigDecimal.valueOf(9.99), 1.5, false, false, true, false),

    STANDARD("Standard", 14, BigDecimal.valueOf(24.99), 2.0, true, false, true, false),

    PREMIUM("Premium", 30, BigDecimal.valueOf(49.99), 3.0, true, true, true, false),

    VIP("VIP", 30, BigDecimal.valueOf(99.99), 5.0, true, true, true, true);

    private final String displayName;
    private final int durationDays;
    private final BigDecimal price;
    private final double boostMultiplier;
    private final boolean featuredInCategory;
    private final boolean featuredOnHome;
    private final boolean priorityInSearch;
    private final boolean homeBanner;

    BoostPackage(String displayName, int durationDays, BigDecimal price,
                 double boostMultiplier, boolean featuredInCategory,
                 boolean featuredOnHome, boolean priorityInSearch, boolean homeBanner) {
        this.displayName = displayName;
        this.durationDays = durationDays;
        this.price = price;
        this.boostMultiplier = boostMultiplier;
        this.featuredInCategory = featuredInCategory;
        this.featuredOnHome = featuredOnHome;
        this.priorityInSearch = priorityInSearch;
        this.homeBanner = homeBanner;
    }

    public String getBadgeText() {
        return switch (this) {
            case BASIC -> "BOOSTED";
            case STANDARD -> "FEATURED";
            case PREMIUM -> "PREMIUM";
            case VIP -> "VIP";
        };
    }
}

package com.luma.entity.enums;

import lombok.Getter;

import java.math.BigDecimal;

@Getter
public enum UserBoostPackage {
    SPOTLIGHT("Spotlight", 3, BigDecimal.valueOf(2.99), 1.5, true, false, "BOOSTED"),
    HIGHLIGHT("Highlight", 7, BigDecimal.valueOf(5.99), 2.0, true, true, "FEATURED");

    private final String displayName;
    private final int durationDays;
    private final BigDecimal price;
    private final double boostMultiplier;
    private final boolean priorityInSearch;
    private final boolean showBadge;
    private final String badgeText;

    UserBoostPackage(String displayName, int durationDays, BigDecimal price,
                     double boostMultiplier, boolean priorityInSearch,
                     boolean showBadge, String badgeText) {
        this.displayName = displayName;
        this.durationDays = durationDays;
        this.price = price;
        this.boostMultiplier = boostMultiplier;
        this.priorityInSearch = priorityInSearch;
        this.showBadge = showBadge;
        this.badgeText = badgeText;
    }

    public String getDescription() {
        return switch (this) {
            case SPOTLIGHT -> "Priority in search results for " + durationDays + " days";
            case HIGHLIGHT -> "Priority search + Featured badge for " + durationDays + " days";
        };
    }
}

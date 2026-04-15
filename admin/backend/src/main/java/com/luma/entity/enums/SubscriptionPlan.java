package com.luma.entity.enums;

import lombok.Getter;

import java.math.BigDecimal;

@Getter
public enum SubscriptionPlan {
    FREE("Free", BigDecimal.ZERO, 3, 0),
    STANDARD("Standard", BigDecimal.valueOf(19.99), 10, 10),
    PREMIUM("Premium", BigDecimal.valueOf(49.99), 30, 20),
    VIP("VIP", BigDecimal.valueOf(99.99), -1, 30);

    private final String displayName;
    private final BigDecimal monthlyPrice;
    private final int maxEventsPerMonth;
    private final int boostDiscountPercent;

    SubscriptionPlan(String displayName, BigDecimal monthlyPrice,
                     int maxEventsPerMonth, int boostDiscountPercent) {
        this.displayName = displayName;
        this.monthlyPrice = monthlyPrice;
        this.maxEventsPerMonth = maxEventsPerMonth;
        this.boostDiscountPercent = boostDiscountPercent;
    }

    public boolean isUnlimitedEvents() {
        return maxEventsPerMonth == -1;
    }

    public String getBadgeText() {
        return switch (this) {
            case FREE -> "FREE";
            case STANDARD -> "STANDARD";
            case PREMIUM -> "PREMIUM";
            case VIP -> "VIP";
        };
    }

    public String getBadgeColor() {
        return switch (this) {
            case FREE -> "#6B7280";
            case STANDARD -> "#3B82F6";
            case PREMIUM -> "#8B5CF6";
            case VIP -> "#F59E0B";
        };
    }
}

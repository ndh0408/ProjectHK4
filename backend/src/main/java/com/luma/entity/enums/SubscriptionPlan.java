package com.luma.entity.enums;

import lombok.Getter;

import java.math.BigDecimal;

@Getter
public enum SubscriptionPlan {
    FREE("Free", BigDecimal.ZERO, 3, 100, 3, false, false, 0),
    STANDARD("Standard", BigDecimal.valueOf(19.99), 10, 500, 30, true, true, 10),
    PREMIUM("Premium", BigDecimal.valueOf(49.99), 30, 2000, -1, true, true, 20),
    VIP("VIP", BigDecimal.valueOf(99.99), -1, -1, -1, true, true, 30);

    private final String displayName;
    private final BigDecimal monthlyPrice;
    private final int maxEventsPerMonth;      // -1 = unlimited
    private final int maxAttendeesPerEvent;   // -1 = unlimited
    private final int aiUsagePerMonth;        // -1 = unlimited
    private final boolean canGenerateCertificates;
    private final boolean canExportExcel;
    private final int boostDiscountPercent;

    SubscriptionPlan(String displayName, BigDecimal monthlyPrice,
                     int maxEventsPerMonth, int maxAttendeesPerEvent,
                     int aiUsagePerMonth, boolean canGenerateCertificates,
                     boolean canExportExcel, int boostDiscountPercent) {
        this.displayName = displayName;
        this.monthlyPrice = monthlyPrice;
        this.maxEventsPerMonth = maxEventsPerMonth;
        this.maxAttendeesPerEvent = maxAttendeesPerEvent;
        this.aiUsagePerMonth = aiUsagePerMonth;
        this.canGenerateCertificates = canGenerateCertificates;
        this.canExportExcel = canExportExcel;
        this.boostDiscountPercent = boostDiscountPercent;
    }

    public boolean isUnlimitedEvents() {
        return maxEventsPerMonth == -1;
    }

    public boolean isUnlimitedAttendees() {
        return maxAttendeesPerEvent == -1;
    }

    public boolean isUnlimitedAI() {
        return aiUsagePerMonth == -1;
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
            case FREE -> "#6B7280";      // Gray
            case STANDARD -> "#3B82F6";  // Blue
            case PREMIUM -> "#8B5CF6";   // Purple
            case VIP -> "#F59E0B";       // Gold
        };
    }
}

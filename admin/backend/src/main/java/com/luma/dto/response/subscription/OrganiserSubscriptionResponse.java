package com.luma.dto.response.subscription;

import com.luma.entity.OrganiserSubscription;
import com.luma.entity.enums.SubscriptionPlan;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
public class OrganiserSubscriptionResponse {
    private UUID id;
    private SubscriptionPlan plan;
    private String planDisplayName;
    private String badge;
    private String badgeColor;
    private LocalDateTime startDate;
    private LocalDateTime endDate;
    private boolean isActive;
    private boolean autoRenew;

    private int eventsCreatedThisMonth;
    private String remainingEvents;
    private LocalDateTime billingCycleStart;

    private String maxEventsPerMonth;
    private int boostDiscountPercent;

    public static OrganiserSubscriptionResponse fromEntity(OrganiserSubscription subscription) {
        SubscriptionPlan plan = subscription.getEffectivePlan();

        return OrganiserSubscriptionResponse.builder()
                .id(subscription.getId())
                .plan(plan)
                .planDisplayName(plan.getDisplayName())
                .badge(plan.getBadgeText())
                .badgeColor(plan.getBadgeColor())
                .startDate(subscription.getStartDate())
                .endDate(subscription.getEndDate())
                .isActive(subscription.isActive())
                .autoRenew(subscription.isAutoRenew())
                .eventsCreatedThisMonth(subscription.getEventsCreatedThisMonth())
                .remainingEvents(formatRemaining(subscription.getRemainingEvents()))
                .billingCycleStart(subscription.getBillingCycleStart())
                .maxEventsPerMonth(plan.isUnlimitedEvents() ? "Unlimited" : String.valueOf(plan.getMaxEventsPerMonth()))
                .boostDiscountPercent(plan.getBoostDiscountPercent())
                .build();
    }

    private static String formatRemaining(int remaining) {
        return remaining == -1 ? "Unlimited" : String.valueOf(remaining);
    }
}

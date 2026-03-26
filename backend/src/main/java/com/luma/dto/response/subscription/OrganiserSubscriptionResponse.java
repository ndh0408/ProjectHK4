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

    // Usage info
    private int eventsCreatedThisMonth;
    private int aiUsageThisMonth;
    private String remainingEvents;
    private String remainingAIUsage;
    private LocalDateTime billingCycleStart;

    // Plan limits
    private String maxEventsPerMonth;
    private String maxAttendeesPerEvent;
    private String aiUsagePerMonth;
    private boolean canGenerateCertificates;
    private boolean canExportExcel;
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
                .aiUsageThisMonth(subscription.getAiUsageThisMonth())
                .remainingEvents(formatRemaining(subscription.getRemainingEvents()))
                .remainingAIUsage(formatRemaining(subscription.getRemainingAIUsage()))
                .billingCycleStart(subscription.getBillingCycleStart())
                .maxEventsPerMonth(plan.isUnlimitedEvents() ? "Unlimited" : String.valueOf(plan.getMaxEventsPerMonth()))
                .maxAttendeesPerEvent(plan.isUnlimitedAttendees() ? "Unlimited" : String.valueOf(plan.getMaxAttendeesPerEvent()))
                .aiUsagePerMonth(plan.isUnlimitedAI() ? "Unlimited" : String.valueOf(plan.getAiUsagePerMonth()))
                .canGenerateCertificates(plan.isCanGenerateCertificates())
                .canExportExcel(plan.isCanExportExcel())
                .boostDiscountPercent(plan.getBoostDiscountPercent())
                .build();
    }

    private static String formatRemaining(int remaining) {
        return remaining == -1 ? "Unlimited" : String.valueOf(remaining);
    }
}

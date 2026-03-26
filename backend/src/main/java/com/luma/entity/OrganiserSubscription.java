package com.luma.entity;

import com.luma.entity.enums.SubscriptionPlan;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "organiser_subscriptions")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OrganiserSubscription {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "organiser_id", nullable = false, unique = true)
    private User organiser;

    @Enumerated(EnumType.STRING)
    @Column(name = "subscription_plan", nullable = false)
    @Builder.Default
    private SubscriptionPlan plan = SubscriptionPlan.FREE;

    @Column(name = "start_date")
    private LocalDateTime startDate;

    @Column(name = "end_date")
    private LocalDateTime endDate;

    @Column(name = "is_active")
    @Builder.Default
    private boolean isActive = true;

    @Column(name = "auto_renew")
    @Builder.Default
    private boolean autoRenew = false;

    // Usage tracking for current billing period
    @Column(name = "events_created_this_month")
    @Builder.Default
    private int eventsCreatedThisMonth = 0;

    @Column(name = "ai_usage_this_month")
    @Builder.Default
    private int aiUsageThisMonth = 0;

    @Column(name = "billing_cycle_start")
    private LocalDateTime billingCycleStart;

    // Stripe subscription ID for paid plans
    @Column(name = "stripe_subscription_id")
    private String stripeSubscriptionId;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    // Check if subscription is valid (active and not expired)
    public boolean isValid() {
        if (!isActive) return false;
        if (plan == SubscriptionPlan.FREE) return true;
        return endDate == null || endDate.isAfter(LocalDateTime.now());
    }

    // Get effective plan (FREE if subscription expired)
    public SubscriptionPlan getEffectivePlan() {
        return isValid() ? plan : SubscriptionPlan.FREE;
    }

    // Reset monthly usage counters
    public void resetMonthlyUsage() {
        this.eventsCreatedThisMonth = 0;
        this.aiUsageThisMonth = 0;
        this.billingCycleStart = LocalDateTime.now();
    }

    // Check if can create more events
    public boolean canCreateEvent() {
        SubscriptionPlan effectivePlan = getEffectivePlan();
        if (effectivePlan.isUnlimitedEvents()) return true;
        return eventsCreatedThisMonth < effectivePlan.getMaxEventsPerMonth();
    }

    // Check if can use AI
    public boolean canUseAI() {
        SubscriptionPlan effectivePlan = getEffectivePlan();
        if (effectivePlan.isUnlimitedAI()) return true;
        return aiUsageThisMonth < effectivePlan.getAiUsagePerMonth();
    }

    // Get remaining events quota
    public int getRemainingEvents() {
        SubscriptionPlan effectivePlan = getEffectivePlan();
        if (effectivePlan.isUnlimitedEvents()) return -1;
        return Math.max(0, effectivePlan.getMaxEventsPerMonth() - eventsCreatedThisMonth);
    }

    // Get remaining AI usage quota
    public int getRemainingAIUsage() {
        SubscriptionPlan effectivePlan = getEffectivePlan();
        if (effectivePlan.isUnlimitedAI()) return -1;
        return Math.max(0, effectivePlan.getAiUsagePerMonth() - aiUsageThisMonth);
    }

    // Increment event count
    public void incrementEventCount() {
        this.eventsCreatedThisMonth++;
    }

    // Increment AI usage
    public void incrementAIUsage() {
        this.aiUsageThisMonth++;
    }
}

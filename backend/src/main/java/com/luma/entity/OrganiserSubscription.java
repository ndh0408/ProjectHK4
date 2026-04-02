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

    @Column(name = "events_created_this_month")
    @Builder.Default
    private int eventsCreatedThisMonth = 0;

    @Column(name = "billing_cycle_start")
    private LocalDateTime billingCycleStart;

    @Column(name = "stripe_subscription_id")
    private String stripeSubscriptionId;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    public boolean isValid() {
        if (!isActive) return false;
        if (plan == SubscriptionPlan.FREE) return true;
        return endDate == null || endDate.isAfter(LocalDateTime.now());
    }

    public SubscriptionPlan getEffectivePlan() {
        return isValid() ? plan : SubscriptionPlan.FREE;
    }

    public void resetMonthlyUsage() {
        this.eventsCreatedThisMonth = 0;
        this.billingCycleStart = LocalDateTime.now();
    }

    public boolean canCreateEvent() {
        SubscriptionPlan effectivePlan = getEffectivePlan();
        if (effectivePlan.isUnlimitedEvents()) return true;
        return eventsCreatedThisMonth < effectivePlan.getMaxEventsPerMonth();
    }

    public int getRemainingEvents() {
        SubscriptionPlan effectivePlan = getEffectivePlan();
        if (effectivePlan.isUnlimitedEvents()) return -1;
        return Math.max(0, effectivePlan.getMaxEventsPerMonth() - eventsCreatedThisMonth);
    }

    public void incrementEventCount() {
        this.eventsCreatedThisMonth++;
    }
}

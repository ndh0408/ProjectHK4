package com.luma.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "user_event_limits")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserEventLimit {

    public static final int FREE_EVENTS_PER_MONTH = 1;
    public static final int FREE_ATTENDEES_PER_EVENT = 50;
    public static final BigDecimal EXTRA_EVENT_PRICE = BigDecimal.valueOf(2.99);

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    @Builder.Default
    @Column(name = "free_events_used_this_month")
    private int freeEventsUsedThisMonth = 0;

    @Builder.Default
    @Column(name = "extra_events_purchased_this_month")
    private int extraEventsPurchasedThisMonth = 0;

    @Builder.Default
    @Column(name = "extra_events_used_this_month")
    private int extraEventsUsedThisMonth = 0;

    @Builder.Default
    @Column(name = "total_extra_events_purchased")
    private int totalExtraEventsPurchased = 0;

    @Builder.Default
    @Column(name = "total_amount_spent", precision = 10, scale = 2)
    private BigDecimal totalAmountSpent = BigDecimal.ZERO;

    @Column(name = "billing_cycle_start")
    private LocalDateTime billingCycleStart;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    public boolean canCreateFreeEvent() {
        return freeEventsUsedThisMonth < FREE_EVENTS_PER_MONTH;
    }

    public boolean hasExtraEventAvailable() {
        return extraEventsPurchasedThisMonth > extraEventsUsedThisMonth;
    }

    public boolean canCreateEvent() {
        return canCreateFreeEvent() || hasExtraEventAvailable();
    }

    public int getRemainingFreeEvents() {
        return Math.max(0, FREE_EVENTS_PER_MONTH - freeEventsUsedThisMonth);
    }

    public int getRemainingExtraEvents() {
        return Math.max(0, extraEventsPurchasedThisMonth - extraEventsUsedThisMonth);
    }

    public void useFreeEvent() {
        if (canCreateFreeEvent()) {
            freeEventsUsedThisMonth++;
        } else {
            throw new IllegalStateException("No free events available");
        }
    }

    public void useExtraEvent() {
        if (hasExtraEventAvailable()) {
            extraEventsUsedThisMonth++;
        } else {
            throw new IllegalStateException("No extra events available");
        }
    }

    public void purchaseExtraEvent(BigDecimal amount) {
        extraEventsPurchasedThisMonth++;
        totalExtraEventsPurchased++;
        totalAmountSpent = totalAmountSpent.add(amount);
    }

    public void resetMonthlyUsage() {
        freeEventsUsedThisMonth = 0;
        extraEventsPurchasedThisMonth = 0;
        extraEventsUsedThisMonth = 0;
        billingCycleStart = LocalDateTime.now();
    }

    public boolean shouldResetMonthly() {
        if (billingCycleStart == null) return true;
        LocalDateTime nextReset = billingCycleStart.plusMonths(1);
        return LocalDateTime.now().isAfter(nextReset);
    }
}

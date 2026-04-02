package com.luma.dto.response.userboost;

import com.luma.entity.UserEventLimit;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserEventLimitResponse {

    private int freeEventsPerMonth;
    private int freeEventsUsedThisMonth;
    private int freeEventsRemaining;
    private int extraEventsPurchasedThisMonth;
    private int extraEventsUsedThisMonth;
    private int extraEventsRemaining;
    private int maxAttendeesPerEvent;
    private BigDecimal extraEventPrice;
    private String extraEventPriceFormatted;
    private BigDecimal totalAmountSpent;
    private boolean canCreateFreeEvent;
    private boolean canCreateEvent;
    private boolean needsToPurchase;
    private LocalDateTime billingCycleStart;
    private LocalDateTime nextResetDate;

    public static UserEventLimitResponse fromEntity(UserEventLimit limit) {
        LocalDateTime nextReset = limit.getBillingCycleStart() != null
                ? limit.getBillingCycleStart().plusMonths(1)
                : LocalDateTime.now().plusMonths(1);

        return UserEventLimitResponse.builder()
                .freeEventsPerMonth(UserEventLimit.FREE_EVENTS_PER_MONTH)
                .freeEventsUsedThisMonth(limit.getFreeEventsUsedThisMonth())
                .freeEventsRemaining(limit.getRemainingFreeEvents())
                .extraEventsPurchasedThisMonth(limit.getExtraEventsPurchasedThisMonth())
                .extraEventsUsedThisMonth(limit.getExtraEventsUsedThisMonth())
                .extraEventsRemaining(limit.getRemainingExtraEvents())
                .maxAttendeesPerEvent(UserEventLimit.FREE_ATTENDEES_PER_EVENT)
                .extraEventPrice(UserEventLimit.EXTRA_EVENT_PRICE)
                .extraEventPriceFormatted(String.format("$%.2f", UserEventLimit.EXTRA_EVENT_PRICE))
                .totalAmountSpent(limit.getTotalAmountSpent())
                .canCreateFreeEvent(limit.canCreateFreeEvent())
                .canCreateEvent(limit.canCreateEvent())
                .needsToPurchase(!limit.canCreateFreeEvent() && !limit.hasExtraEventAvailable())
                .billingCycleStart(limit.getBillingCycleStart())
                .nextResetDate(nextReset)
                .build();
    }

    public static UserEventLimitResponse createDefault() {
        return UserEventLimitResponse.builder()
                .freeEventsPerMonth(UserEventLimit.FREE_EVENTS_PER_MONTH)
                .freeEventsUsedThisMonth(0)
                .freeEventsRemaining(UserEventLimit.FREE_EVENTS_PER_MONTH)
                .extraEventsPurchasedThisMonth(0)
                .extraEventsUsedThisMonth(0)
                .extraEventsRemaining(0)
                .maxAttendeesPerEvent(UserEventLimit.FREE_ATTENDEES_PER_EVENT)
                .extraEventPrice(UserEventLimit.EXTRA_EVENT_PRICE)
                .extraEventPriceFormatted(String.format("$%.2f", UserEventLimit.EXTRA_EVENT_PRICE))
                .totalAmountSpent(BigDecimal.ZERO)
                .canCreateFreeEvent(true)
                .canCreateEvent(true)
                .needsToPurchase(false)
                .billingCycleStart(LocalDateTime.now())
                .nextResetDate(LocalDateTime.now().plusMonths(1))
                .build();
    }
}

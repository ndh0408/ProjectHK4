package com.luma.service;

import com.luma.dto.response.userboost.UserEventLimitResponse;
import com.luma.entity.User;
import com.luma.entity.UserEventLimit;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.UserEventLimitRepository;
import com.luma.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class UserEventLimitService {

    private final UserEventLimitRepository limitRepository;
    private final UserRepository userRepository;

    @Transactional
    public UserEventLimit getOrCreateLimit(UUID userId) {
        return limitRepository.findByUserId(userId)
                .map(limit -> {
                    if (limit.shouldResetMonthly()) {
                        limit.resetMonthlyUsage();
                        return limitRepository.save(limit);
                    }
                    return limit;
                })
                .orElseGet(() -> createDefaultLimit(userId));
    }

    private UserEventLimit createDefaultLimit(UUID userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        UserEventLimit limit = UserEventLimit.builder()
                .user(user)
                .freeEventsUsedThisMonth(0)
                .extraEventsPurchasedThisMonth(0)
                .extraEventsUsedThisMonth(0)
                .totalExtraEventsPurchased(0)
                .totalAmountSpent(BigDecimal.ZERO)
                .billingCycleStart(LocalDateTime.now())
                .build();

        return limitRepository.save(limit);
    }

    public UserEventLimitResponse getUserEventLimit(UUID userId) {
        UserEventLimit limit = getOrCreateLimit(userId);
        return UserEventLimitResponse.fromEntity(limit);
    }

    public boolean canCreateEvent(UUID userId) {
        UserEventLimit limit = getOrCreateLimit(userId);
        return limit.canCreateEvent();
    }

    public boolean canCreateFreeEvent(UUID userId) {
        UserEventLimit limit = getOrCreateLimit(userId);
        return limit.canCreateFreeEvent();
    }

    public boolean needsToPurchaseEvent(UUID userId) {
        UserEventLimit limit = getOrCreateLimit(userId);
        return !limit.canCreateFreeEvent() && !limit.hasExtraEventAvailable();
    }

    @Transactional
    public void useEventSlot(UUID userId) {
        UserEventLimit limit = getOrCreateLimit(userId);

        if (limit.canCreateFreeEvent()) {
            limit.useFreeEvent();
            log.info("User {} used free event slot. Remaining: {}", userId, limit.getRemainingFreeEvents());
        } else if (limit.hasExtraEventAvailable()) {
            limit.useExtraEvent();
            log.info("User {} used extra event slot. Remaining: {}", userId, limit.getRemainingExtraEvents());
        } else {
            throw new BadRequestException(
                    "No event slots available. Please purchase an extra event for $" +
                            UserEventLimit.EXTRA_EVENT_PRICE + " to continue.");
        }

        limitRepository.save(limit);
    }

    @Transactional
    public UserEventLimitResponse purchaseExtraEvent(UUID userId, int quantity) {
        if (quantity < 1) {
            throw new BadRequestException("Quantity must be at least 1");
        }

        UserEventLimit limit = getOrCreateLimit(userId);
        BigDecimal totalAmount = UserEventLimit.EXTRA_EVENT_PRICE.multiply(BigDecimal.valueOf(quantity));

        for (int i = 0; i < quantity; i++) {
            limit.purchaseExtraEvent(UserEventLimit.EXTRA_EVENT_PRICE);
        }

        UserEventLimit saved = limitRepository.save(limit);
        log.info("User {} purchased {} extra event(s) for total ${}. Available: {}",
                userId, quantity, totalAmount, saved.getRemainingExtraEvents());

        return UserEventLimitResponse.fromEntity(saved);
    }

    @Transactional
    public UserEventLimitResponse purchaseExtraEventAfterPayment(UUID userId, int quantity, String paymentIntentId) {
        log.info("Processing extra event purchase for user {} with payment {}", userId, paymentIntentId);
        return purchaseExtraEvent(userId, quantity);
    }

    public void validateEventCreation(UUID userId) {
        if (!canCreateEvent(userId)) {
            throw new BadRequestException(
                    "You have used your free event for this month. " +
                            "Purchase an extra event for $" + UserEventLimit.EXTRA_EVENT_PRICE + " to create more events.");
        }
    }

    public void validateAttendeeCapacity(int requestedCapacity) {
        if (requestedCapacity > UserEventLimit.FREE_ATTENDEES_PER_EVENT) {
            throw new BadRequestException(
                    "Free users can have up to " + UserEventLimit.FREE_ATTENDEES_PER_EVENT +
                            " attendees per event. Requested: " + requestedCapacity +
                            ". Consider becoming an Organiser for larger events.");
        }
    }

    public BigDecimal getExtraEventPrice() {
        return UserEventLimit.EXTRA_EVENT_PRICE;
    }

    public int getMaxAttendeesPerEvent() {
        return UserEventLimit.FREE_ATTENDEES_PER_EVENT;
    }

    @Scheduled(cron = "0 0 0 1 * *")
    @Transactional
    public void resetMonthlyLimits() {
        log.info("Running monthly reset for user event limits...");
        limitRepository.findAll().forEach(limit -> {
            if (limit.shouldResetMonthly()) {
                limit.resetMonthlyUsage();
                limitRepository.save(limit);
            }
        });
        log.info("Monthly reset completed");
    }
}

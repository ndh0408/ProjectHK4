package com.luma.scheduler;

import com.luma.entity.Registration;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.repository.RegistrationRepository;
import com.luma.service.WaitlistService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Reclaims seats from waitlist-promoted users who accepted an offer but never
 * paid. Without this sweep the PENDING row holds a ticket pool slot forever
 * and the next person in line never gets promoted.
 *
 * Pairs with {@code WaitlistService.PROMOTED_PAYMENT_DEADLINE_MINUTES}, which
 * is written to {@code Registration.paymentDeadline} at {@code acceptOffer}
 * for paid events.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class PromotedPaymentReclaimScheduler {

    private final RegistrationRepository registrationRepository;
    private final WaitlistService waitlistService;

    @Scheduled(fixedRate = 60000)
    @Transactional
    public void reclaimAbandonedPromotedRegistrations() {
        List<Registration> stale = registrationRepository
                .findPromotedPendingPastDeadline(RegistrationStatus.PENDING, LocalDateTime.now());

        if (stale.isEmpty()) return;

        log.info("Reclaiming {} stale promoted-PENDING registrations past payment deadline", stale.size());

        for (Registration reg : stale) {
            try {
                waitlistService.releasePromotedRegistration(reg, "payment_deadline_exceeded");
            } catch (Exception e) {
                log.error("Failed to reclaim registration {}: {}", reg.getId(), e.getMessage(), e);
            }
        }
    }
}

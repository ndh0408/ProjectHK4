package com.luma.service;

import com.luma.dto.response.WaitlistOfferResponse;
import com.luma.entity.*;
import com.luma.entity.enums.*;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class WaitlistService {

    private static final int OFFER_EXPIRY_MINUTES = 30;

    /**
     * A paid waitlist-promoted user has this long to complete payment.
     * Exceeding it releases the seat back to the waitlist via
     * {@code releasePromotedRegistration}.
     */
    public static final int PROMOTED_PAYMENT_DEADLINE_MINUTES = 30;

    private final WaitlistOfferRepository waitlistOfferRepository;
    private final RegistrationRepository registrationRepository;
    private final TicketTypeRepository ticketTypeRepository;
    private final OrganiserSubscriptionRepository subscriptionRepository;
    private final EventService eventService;
    private final NotificationService notificationService;
    private final WebSocketNotificationService webSocketNotificationService;

    public int calculatePriorityScore(User user, Event event) {
        int score = 0;

        if (user.getRole() == UserRole.ORGANISER || user.getRole() == UserRole.ADMIN) {
            score += 20;

            int subscriptionBonus = subscriptionRepository.findActiveByOrganiserId(user.getId())
                    .filter(OrganiserSubscription::isValid)
                    .map(sub -> switch (sub.getPlan()) {
                        case VIP -> 40;
                        case PREMIUM -> 30;
                        case STANDARD -> 20;
                        case FREE -> 0;
                    })
                    .orElse(0);
            score += subscriptionBonus;
        }

        long pastApprovedCount = registrationRepository.countApprovedByUser(user);
        score += (int) Math.min(pastApprovedCount * 2, 20);

        if (user.isPhoneVerified() && user.isEmailVerified()) {
            score += 10;
        } else if (user.isEmailVerified()) {
            score += 5;
        }

        long cancelledCount = registrationRepository.countByUserAndStatus(user, RegistrationStatus.CANCELLED);
        score -= (int) Math.min(cancelledCount * 5, 20);

        return Math.max(score, 0);
    }

    @Transactional
    public void createOfferForNextInLine(Event event) {
        if (waitlistOfferRepository.countPendingOffersByEvent(event) > 0) {
            log.info("Event {} already has a pending offer, skipping", event.getId());
            return;
        }

        List<Registration> waitingList = registrationRepository.findWaitingListByEvent(event);
        if (waitingList.isEmpty()) {
            log.info("No one on waiting list for event {}", event.getId());
            return;
        }

        Registration nextInLine = waitingList.stream()
                .sorted(Comparator.comparingInt((Registration r) ->
                        r.getPriorityScore() != null ? r.getPriorityScore() : 0).reversed()
                        .thenComparing(Registration::getCreatedAt))
                .findFirst()
                .orElse(null);

        if (nextInLine == null) return;

        boolean hasActiveOffer = waitlistOfferRepository.existsByRegistrationAndStatusIn(
                nextInLine, List.of(WaitlistOfferStatus.PENDING));
        if (hasActiveOffer) {
            log.info("Registration {} already has a pending offer", nextInLine.getId());
            return;
        }

        WaitlistOffer offer = WaitlistOffer.builder()
                .registration(nextInLine)
                .event(event)
                .user(nextInLine.getUser())
                .status(WaitlistOfferStatus.PENDING)
                .expiresAt(LocalDateTime.now().plusMinutes(OFFER_EXPIRY_MINUTES))
                .priorityScore(nextInLine.getPriorityScore() != null ? nextInLine.getPriorityScore() : 0)
                .build();

        waitlistOfferRepository.save(offer);

        log.info("Created waitlist offer {} for user {} on event {}, expires at {}",
                offer.getId(), nextInLine.getUser().getId(), event.getId(), offer.getExpiresAt());

        sendWaitlistOfferNotification(offer);
    }

    @Transactional
    public WaitlistOfferResponse acceptOffer(UUID offerId, User user) {
        WaitlistOffer offer = waitlistOfferRepository.findByIdWithLock(offerId)
                .orElseThrow(() -> new ResourceNotFoundException("Waitlist offer not found"));

        if (!offer.getUser().getId().equals(user.getId())) {
            throw new BadRequestException("You do not have permission to accept this offer");
        }

        if (offer.getStatus() != WaitlistOfferStatus.PENDING) {
            throw new BadRequestException("This offer is no longer available (status: " + offer.getStatus() + ")");
        }

        if (offer.isExpired()) {
            offer.setStatus(WaitlistOfferStatus.EXPIRED);
            waitlistOfferRepository.save(offer);
            throw new BadRequestException("This offer has expired");
        }

        Event event = offer.getEvent();
        Registration registration = offer.getRegistration();

        if (registration.getTicketType() != null) {
            try {
                int qty = registration.getQuantity() != null ? registration.getQuantity() : 1;
                int updated = ticketTypeRepository.incrementSoldCount(registration.getTicketType().getId(), qty);
                if (updated == 0) {
                    throw new BadRequestException("Unable to reserve tickets. They may have been sold out.");
                }
            } catch (BadRequestException e) {
                throw e;
            }
        }

        offer.setStatus(WaitlistOfferStatus.ACCEPTED);
        offer.setAcceptedAt(LocalDateTime.now());
        waitlistOfferRepository.save(offer);

        Integer oldPosition = registration.getWaitingListPosition();

        java.math.BigDecimal ticketPrice = registration.getTicketType() != null
                ? registration.getTicketType().getPrice()
                : event.getTicketPrice();
        boolean isPaidEvent = ticketPrice != null && ticketPrice.compareTo(java.math.BigDecimal.ZERO) > 0;

        if (isPaidEvent) {
            registration.setStatus(RegistrationStatus.PENDING);
            registration.setPaymentDeadline(
                    LocalDateTime.now().plusMinutes(PROMOTED_PAYMENT_DEADLINE_MINUTES));
        } else {
            registration.setStatus(RegistrationStatus.APPROVED);
            registration.setApprovedAt(LocalDateTime.now());
            registration.setPaymentDeadline(null);
            eventService.incrementApprovedCount(event);
        }
        registration.setWaitingListPosition(null);
        registrationRepository.save(registration);

        if (oldPosition != null) {
            registrationRepository.decrementWaitingListPositionsAfter(event, oldPosition);
        }

        log.info("User {} accepted waitlist offer {} for event {} (requiresPayment={})",
                user.getId(), offerId, event.getId(), isPaidEvent);

        if (isPaidEvent) {
            notificationService.sendPromotedFromWaitingListNotification(registration);
        } else {
            notificationService.sendRegistrationApprovedNotification(registration);
        }

        WaitlistOfferResponse response = WaitlistOfferResponse.fromEntity(offer);
        response.setRequiresPayment(isPaidEvent);
        return response;
    }

    @Transactional
    public WaitlistOfferResponse declineOffer(UUID offerId, User user) {
        WaitlistOffer offer = waitlistOfferRepository.findByIdWithLock(offerId)
                .orElseThrow(() -> new ResourceNotFoundException("Waitlist offer not found"));

        if (!offer.getUser().getId().equals(user.getId())) {
            throw new BadRequestException("You do not have permission to decline this offer");
        }

        if (offer.getStatus() != WaitlistOfferStatus.PENDING) {
            throw new BadRequestException("This offer is no longer available");
        }

        offer.setStatus(WaitlistOfferStatus.DECLINED);
        offer.setDeclinedAt(LocalDateTime.now());
        waitlistOfferRepository.save(offer);

        Registration registration = offer.getRegistration();
        Integer oldPosition = registration.getWaitingListPosition();
        registration.setStatus(RegistrationStatus.CANCELLED);
        registration.setWaitingListPosition(null);
        registrationRepository.save(registration);

        if (oldPosition != null) {
            registrationRepository.decrementWaitingListPositionsAfter(offer.getEvent(), oldPosition);
        }

        log.info("User {} declined waitlist offer {} for event {}", user.getId(), offerId, offer.getEvent().getId());

        createOfferForNextInLine(offer.getEvent());

        return WaitlistOfferResponse.fromEntity(offer);
    }

    @Transactional
    public void expireOffer(WaitlistOffer offer) {
        offer.setStatus(WaitlistOfferStatus.EXPIRED);
        waitlistOfferRepository.save(offer);

        Registration registration = offer.getRegistration();
        Integer oldPosition = registration.getWaitingListPosition();

        if (oldPosition != null) {
            registrationRepository.decrementWaitingListPositionsAfter(offer.getEvent(), oldPosition);
        }

        int newLastPosition = (int) registrationRepository.countByEventAndStatus(
                offer.getEvent(), RegistrationStatus.WAITING_LIST);
        registration.setWaitingListPosition(newLastPosition);
        registrationRepository.save(registration);

        log.info("Waitlist offer {} expired for user {} on event {}, moved to position {}",
                offer.getId(), offer.getUser().getId(), offer.getEvent().getId(), newLastPosition);

        sendWaitlistOfferExpiredNotification(offer);

        createOfferForNextInLine(offer.getEvent());
    }

    /**
     * Release a PENDING registration that was promoted off the waitlist but
     * never completed payment (fail/abandon/timeout). Returns the held tickets
     * to the pool, cancels the registration, and triggers the next waitlist
     * offer so another user can take the spot.
     *
     * Called from:
     *   - PaymentService webhook on payment_intent.payment_failed
     *   - PromotedPaymentReclaimScheduler on payment deadline expiry
     */
    @Transactional
    public void releasePromotedRegistration(Registration registration, String reason) {
        if (registration.getStatus() != RegistrationStatus.PENDING) {
            log.info("Skip release: registration {} is not PENDING (status={})",
                    registration.getId(), registration.getStatus());
            return;
        }

        Event event = registration.getEvent();

        if (registration.getTicketType() != null && registration.getQuantity() != null) {
            ticketTypeRepository.decrementSoldCount(
                    registration.getTicketType().getId(),
                    registration.getQuantity()
            );
        }

        registration.setStatus(RegistrationStatus.CANCELLED);
        registration.setWaitingListPosition(null);
        registration.setPaymentDeadline(null);
        registrationRepository.save(registration);

        log.info("Released promoted PENDING registration {} on event {} (reason: {})",
                registration.getId(), event.getId(), reason);

        createOfferForNextInLine(event);
    }

    public List<WaitlistOfferResponse> getPendingOffersForUser(UUID userId) {
        return waitlistOfferRepository.findPendingOffersByUser(userId).stream()
                .filter(o -> !o.isExpired())
                .map(WaitlistOfferResponse::fromEntity)
                .toList();
    }

    public List<WaitlistOfferResponse> getOffersByEvent(Event event) {
        return waitlistOfferRepository.findByEventOrderByCreatedAtDesc(event).stream()
                .map(WaitlistOfferResponse::fromEntity)
                .toList();
    }

    private void sendWaitlistOfferNotification(WaitlistOffer offer) {
        try {
            notificationService.sendWaitlistOfferNotification(offer);
        } catch (Exception e) {
            log.error("Failed to send waitlist offer notification: {}", e.getMessage());
        }
    }

    private void sendWaitlistOfferExpiredNotification(WaitlistOffer offer) {
        try {
            notificationService.sendWaitlistOfferExpiredNotification(offer);
        } catch (Exception e) {
            log.error("Failed to send waitlist offer expired notification: {}", e.getMessage());
        }
    }
}

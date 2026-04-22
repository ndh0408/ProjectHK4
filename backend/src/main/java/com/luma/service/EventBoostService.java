package com.luma.service;

import com.luma.dto.request.boost.CreateBoostRequest;
import com.luma.dto.response.boost.BoostPackageInfo;
import com.luma.dto.response.boost.BoostResponse;
import com.luma.dto.response.boost.BoostUpgradeInfo;
import com.luma.dto.response.boost.BoostUpgradeInfo.BoostAction;
import com.luma.entity.Event;
import com.luma.entity.EventBoost;
import com.luma.entity.User;
import com.luma.entity.enums.BoostPackage;
import com.luma.entity.enums.BoostStatus;
import com.luma.entity.enums.EventStatus;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.EventBoostRepository;
import com.luma.repository.EventRepository;
import com.luma.repository.EventViewRepository;
import com.luma.repository.RegistrationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class EventBoostService {

    private final EventBoostRepository boostRepository;
    private final EventRepository eventRepository;
    private final EventViewRepository eventViewRepository;
    private final RegistrationRepository registrationRepository;
    private final OrganiserSubscriptionService subscriptionService;
    private final NotificationService notificationService;
    private final BoostPackageConfigService boostConfigService;

    private static final List<RegistrationStatus> BOOST_REGISTRATION_STATUSES = List.of(
            RegistrationStatus.PENDING,
            RegistrationStatus.APPROVED,
            RegistrationStatus.WAITING_LIST
    );

    /**
     * Best-effort convert a config key (may be canonical enum name or a custom tier) to the
     * BoostPackage enum. Returns null for custom tiers that don't map — caller should fall
     * back to synthesising a BoostPackageInfo by hand.
     */
    private BoostPackage enumKey(String key) {
        try { return BoostPackage.valueOf(key); } catch (IllegalArgumentException ex) { return null; }
    }

    /** Build the base info object from config, falling back to packageKey when displayName is blank. */
    private BoostPackageInfo buildBaseInfo(com.luma.entity.BoostPackageConfig cfg) {
        BoostPackage pkg = enumKey(cfg.getPackageKey());
        String name = cfg.getDisplayName() == null || cfg.getDisplayName().isBlank()
                ? cfg.getPackageKey()
                : cfg.getDisplayName();
        BoostPackageInfo info = pkg != null
                ? BoostPackageInfo.fromEnum(pkg)
                : BoostPackageInfo.builder()
                    .packageType(null)
                    .displayName(name)
                    .badge(cfg.getBadgeText())
                    .description(name + " tier")
                    .build();
        info.setPackageKey(cfg.getPackageKey());
        if (pkg == null) {
            info.setDisplayName(name);
        }
        info.setDurationDays(cfg.getDurationDays());
        info.setDiscountEligible(Boolean.TRUE.equals(cfg.getDiscountEligible()));
        return info;
    }

    public List<BoostPackageInfo> getAvailablePackages() {
        return boostConfigService.listActive().stream()
                .map(cfg -> {
                    BoostPackageInfo info = buildBaseInfo(cfg);
                    java.math.BigDecimal basePrice = cfg.getPriceUsd();
                    info.setPrice(basePrice);
                    info.setPriceFormatted(String.format("$%.2f", basePrice));
                    info.setOriginalPrice(basePrice);
                    info.setOriginalPriceFormatted(String.format("$%.2f", basePrice));
                    return info;
                })
                .collect(Collectors.toList());
    }

    public List<BoostPackageInfo> getAvailablePackagesWithDiscount(UUID organiserId) {
        int discountPercent = subscriptionService.getBoostDiscountPercent(organiserId);

        return boostConfigService.listActive().stream()
                .map(cfg -> {
                    BoostPackageInfo info = buildBaseInfo(cfg);
                    java.math.BigDecimal basePrice = cfg.getPriceUsd();
                    info.setOriginalPrice(basePrice);
                    info.setOriginalPriceFormatted(String.format("$%.2f", basePrice));
                    boolean eligible = Boolean.TRUE.equals(cfg.getDiscountEligible());
                    if (discountPercent > 0 && eligible) {
                        java.math.BigDecimal discountedPrice = basePrice
                                .multiply(java.math.BigDecimal.valueOf(100 - discountPercent))
                                .divide(java.math.BigDecimal.valueOf(100), 2, java.math.RoundingMode.HALF_UP);
                        info.setPrice(discountedPrice);
                        info.setPriceFormatted(String.format("$%.2f", discountedPrice));
                        String desc = info.getDescription() == null ? "" : info.getDescription();
                        info.setDescription(desc + " (" + discountPercent + "% subscription discount applied)");
                    } else {
                        info.setPrice(basePrice);
                        info.setPriceFormatted(String.format("$%.2f", basePrice));
                    }
                    return info;
                })
                .collect(Collectors.toList());
    }

    /** Service-wide helper: admin-edited price for a boost tier, falling back to enum default. */
    private java.math.BigDecimal configuredPrice(BoostPackage pkg) {
        return boostConfigService.getPriceOrDefault(pkg);
    }

    /** Service-wide helper: admin-edited duration for a boost tier, falling back to enum default. */
    private int configuredDuration(BoostPackage pkg) {
        return boostConfigService.getDurationDaysOrDefault(pkg);
    }

    @Transactional
    public BoostResponse createBoostAfterPayment(CreateBoostRequest request, User organiser, String paymentIntentId) {
        Event event = eventRepository.findById(request.getEventId())
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        if (!event.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You can only boost your own events");
        }

        if (event.getStatus() != EventStatus.PUBLISHED) {
            throw new BadRequestException("Only published events can be boosted");
        }

        if (boostRepository.hasActiveBoost(event.getId(), LocalDateTime.now())) {
            throw new BadRequestException("Event already has an active boost");
        }

        if (event.getStartTime().isBefore(LocalDateTime.now())) {
            throw new BadRequestException("Cannot boost past events");
        }

        BoostPackage pkg = request.getBoostPackage();

        java.math.BigDecimal basePrice = configuredPrice(pkg);
        int discountPercent = subscriptionService.getBoostDiscountPercent(organiser.getId());
        boolean discountEligible = boostConfigService.isDiscountEligible(pkg);
        java.math.BigDecimal finalPrice = basePrice;
        if (discountPercent > 0 && discountEligible) {
            finalPrice = basePrice
                    .multiply(java.math.BigDecimal.valueOf(100 - discountPercent))
                    .divide(java.math.BigDecimal.valueOf(100), 2, java.math.RoundingMode.HALF_UP);
            log.info("Applied {}% subscription discount to boost. Original: {}, Final: {}",
                    discountPercent, basePrice, finalPrice);
        }

        LocalDateTime now = LocalDateTime.now();
        int viewsBeforeBoost = safeCount(eventViewRepository.countByEvent(event));
        int registrationsBeforeBoost = safeCount(
                registrationRepository.countByEventAndStatusIn(event, BOOST_REGISTRATION_STATUSES)
        );

        EventBoost boost = EventBoost.builder()
                .event(event)
                .organiser(organiser)
                .boostPackage(pkg)
                .status(BoostStatus.ACTIVE)
                .amount(finalPrice)
                .paymentIntentId(paymentIntentId)
                .paidAt(now)
                .startTime(now)
                .endTime(now.plusDays(configuredDuration(pkg)))
                .viewsBeforeBoost(viewsBeforeBoost)
                .registrationsBeforeBoost(registrationsBeforeBoost)
                .build();

        boost = boostRepository.save(boost);
        log.info("Boost created and activated for event {} with package {}", event.getId(), pkg);
        return mapToResponse(boost);
    }

    public BoostUpgradeInfo checkExistingBoost(UUID eventId, BoostPackage newPackage, UUID organiserId) {
        LocalDateTime now = LocalDateTime.now();

        List<EventBoost> activeBoosts = boostRepository.findByEventIdAndStatus(eventId, BoostStatus.ACTIVE);
        EventBoost currentBoost = activeBoosts.stream()
                .filter(EventBoost::isActive)
                .findFirst()
                .orElse(null);

        if (currentBoost == null) {
            return BoostUpgradeInfo.builder()
                    .hasExistingBoost(false)
                    .canBoost(true)
                    .action(BoostAction.NEW)
                    .build();
        }
        BoostPackage currentPackage = currentBoost.getBoostPackage();

        LocalDateTime endTime = currentBoost.getEndTime();
        long remainingDays = 0;
        if (endTime != null) {
            remainingDays = ChronoUnit.DAYS.between(now, endTime);
            if (remainingDays < 0) remainingDays = 0;
        }

        int discountPercent = subscriptionService.getBoostDiscountPercent(organiserId);
        boolean newEligible = boostConfigService.isDiscountEligible(newPackage);

        if (currentPackage == newPackage) {
            java.math.BigDecimal extendPrice = configuredPrice(newPackage);
            if (discountPercent > 0 && newEligible) {
                extendPrice = extendPrice
                        .multiply(java.math.BigDecimal.valueOf(100 - discountPercent))
                        .divide(java.math.BigDecimal.valueOf(100), 2, java.math.RoundingMode.HALF_UP);
            }

            LocalDateTime newEndTime = endTime != null
                    ? endTime.plusDays(configuredDuration(newPackage))
                    : LocalDateTime.now().plusDays(configuredDuration(newPackage));

            return BoostUpgradeInfo.builder()
                    .hasExistingBoost(true)
                    .canBoost(true)
                    .action(BoostAction.EXTEND)
                    .currentPackage(currentPackage)
                    .currentBoostId(currentBoost.getId())
                    .remainingDays((int) remainingDays)
                    .currentEndTime(endTime)
                    .newEndTime(newEndTime)
                    .additionalDays(configuredDuration(newPackage))
                    .price(extendPrice)
                    .message(String.format("Extend your %s boost by %d more days",
                            currentPackage.getDisplayName(), configuredDuration(newPackage)))
                    .build();
        } else {
            int currentTier = getPackageTier(currentPackage);
            int newTier = getPackageTier(newPackage);

            java.math.BigDecimal newPrice = configuredPrice(newPackage);
            if (discountPercent > 0 && newEligible) {
                newPrice = newPrice
                        .multiply(java.math.BigDecimal.valueOf(100 - discountPercent))
                        .divide(java.math.BigDecimal.valueOf(100), 2, java.math.RoundingMode.HALF_UP);
            }

            java.math.BigDecimal currentAmount = currentBoost.getAmount();
            java.math.BigDecimal refundAmount = java.math.BigDecimal.ZERO;
            java.math.BigDecimal finalPrice = newPrice;

            if (currentAmount != null && currentAmount.compareTo(java.math.BigDecimal.ZERO) > 0) {
                java.math.BigDecimal dailyRate = currentAmount
                        .divide(java.math.BigDecimal.valueOf(currentPackage.getDurationDays()), 2, java.math.RoundingMode.HALF_UP);
                refundAmount = dailyRate.multiply(java.math.BigDecimal.valueOf(remainingDays));
                finalPrice = newPrice.subtract(refundAmount);
                if (finalPrice.compareTo(java.math.BigDecimal.ZERO) < 0) {
                    finalPrice = java.math.BigDecimal.ZERO;
                }
            }

            String actionLabel = newTier > currentTier ? "Upgrade" : "Change";

            return BoostUpgradeInfo.builder()
                    .hasExistingBoost(true)
                    .canBoost(true)
                    .action(newTier > currentTier ? BoostAction.UPGRADE : BoostAction.DOWNGRADE)
                    .currentPackage(currentPackage)
                    .newPackage(newPackage)
                    .currentBoostId(currentBoost.getId())
                    .remainingDays((int) remainingDays)
                    .currentEndTime(endTime)
                    .newEndTime(LocalDateTime.now().plusDays(configuredDuration(newPackage)))
                    .refundAmount(refundAmount)
                    .price(finalPrice)
                    .originalPrice(newPrice)
                    .message(String.format("%s from %s to %s. Prorated credit: $%.2f",
                            actionLabel, currentPackage.getDisplayName(), newPackage.getDisplayName(), refundAmount))
                    .build();
        }
    }

    private int getPackageTier(BoostPackage pkg) {
        switch (pkg) {
            case BASIC: return 1;
            case STANDARD: return 2;
            case PREMIUM: return 3;
            case VIP: return 4;
            default: return 0;
        }
    }

    @Transactional
    public BoostResponse createBoost(CreateBoostRequest request, User organiser) {
        Event event = eventRepository.findById(request.getEventId())
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        if (!event.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You can only boost your own events");
        }

        if (event.getStatus() != EventStatus.PUBLISHED) {
            throw new BadRequestException("Only published events can be boosted");
        }

        if (event.getStartTime().isBefore(LocalDateTime.now())) {
            throw new BadRequestException("Cannot boost past events");
        }

        BoostPackage pkg = request.getBoostPackage();

        // If there's already a PENDING boost on this event, it's almost always an abandoned
        // Stripe checkout (user closed the tab or pressed Cancel on Stripe's side). Auto-cancel
        // stale PENDING (>1 minute old) so the organiser isn't locked out of retrying. Only
        // the organiser's own stale rows are touched; a true in-flight double-click within the
        // same minute is still rejected to stop accidental duplicate charges.
        List<EventBoost> pending = boostRepository.findByEventIdAndStatus(event.getId(), BoostStatus.PENDING);
        LocalDateTime oneMinuteAgo = LocalDateTime.now().minusMinutes(1);
        boolean hasFreshPending = false;
        for (EventBoost p : pending) {
            if (!p.getOrganiser().getId().equals(organiser.getId())) continue;
            if (p.getCreatedAt() != null && p.getCreatedAt().isAfter(oneMinuteAgo)) {
                hasFreshPending = true;
            } else {
                p.setStatus(BoostStatus.CANCELLED);
                boostRepository.save(p);
                log.info("Auto-cancelled stale PENDING boost {} on event {} (abandoned checkout)",
                        p.getId(), event.getId());
            }
        }
        if (hasFreshPending) {
            throw new BadRequestException(
                    "A boost checkout for this event is already in progress. Complete or cancel it before starting another.");
        }

        int discountPercent = subscriptionService.getBoostDiscountPercent(organiser.getId());
        boolean discountEligible = boostConfigService.isDiscountEligible(pkg);
        java.math.BigDecimal finalPrice = configuredPrice(pkg);
        if (discountPercent > 0 && discountEligible) {
            finalPrice = configuredPrice(pkg)
                    .multiply(java.math.BigDecimal.valueOf(100 - discountPercent))
                    .divide(java.math.BigDecimal.valueOf(100), 2, java.math.RoundingMode.HALF_UP);
            log.info("Applied {}% subscription discount to boost. Original: {}, Final: {}",
                    discountPercent, configuredPrice(pkg), finalPrice);
        }

        EventBoost boost = EventBoost.builder()
                .event(event)
                .organiser(organiser)
                .boostPackage(pkg)
                .status(BoostStatus.PENDING)
                .amount(finalPrice)
                .build();

        boost = boostRepository.save(boost);
        return mapToResponse(boost);
    }

    @Transactional
    public void deletePendingBoost(UUID boostId, User organiser) {
        EventBoost boost = boostRepository.findById(boostId)
                .orElseThrow(() -> new ResourceNotFoundException("Boost not found"));

        if (!boost.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You can only delete your own boosts");
        }

        if (boost.getStatus() != BoostStatus.PENDING) {
            throw new BadRequestException("Can only delete pending boosts");
        }

        boostRepository.delete(boost);
        log.info("Deleted pending boost {}", boostId);
    }

    @Transactional
    public BoostResponse extendBoost(UUID existingBoostId, User organiser, String paymentIntentId) {
        EventBoost existingBoost = boostRepository.findById(existingBoostId)
                .orElseThrow(() -> new ResourceNotFoundException("Boost not found"));

        if (!existingBoost.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You can only extend your own boosts");
        }

        if (existingBoost.getStatus() != BoostStatus.ACTIVE) {
            throw new BadRequestException("Can only extend active boosts");
        }

        int additionalDays = existingBoost.getBoostPackage().getDurationDays();
        LocalDateTime currentEndTime = existingBoost.getEndTime();
        if (currentEndTime == null) {
            currentEndTime = LocalDateTime.now();
        }
        existingBoost.setEndTime(currentEndTime.plusDays(additionalDays));

        log.info("Extended boost {} by {} days. New end time: {}",
                existingBoostId, additionalDays, existingBoost.getEndTime());

        existingBoost = boostRepository.save(existingBoost);
        return mapToResponse(existingBoost);
    }

    @Transactional
    public BoostResponse upgradeBoost(UUID existingBoostId, BoostPackage newPackage, User organiser, String paymentIntentId) {
        EventBoost existingBoost = boostRepository.findById(existingBoostId)
                .orElseThrow(() -> new ResourceNotFoundException("Boost not found"));

        if (!existingBoost.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You can only upgrade your own boosts");
        }

        if (existingBoost.getStatus() != BoostStatus.ACTIVE) {
            throw new BadRequestException("Can only upgrade active boosts");
        }

        existingBoost.setStatus(BoostStatus.CANCELLED);
        existingBoost.setEndTime(LocalDateTime.now());
        boostRepository.save(existingBoost);

        int discountPercent = subscriptionService.getBoostDiscountPercent(organiser.getId());
        boolean newEligible = boostConfigService.isDiscountEligible(newPackage);
        java.math.BigDecimal finalPrice = configuredPrice(newPackage);
        if (discountPercent > 0 && newEligible) {
            finalPrice = finalPrice
                    .multiply(java.math.BigDecimal.valueOf(100 - discountPercent))
                    .divide(java.math.BigDecimal.valueOf(100), 2, java.math.RoundingMode.HALF_UP);
        }

        LocalDateTime now = LocalDateTime.now();
        EventBoost newBoost = EventBoost.builder()
                .event(existingBoost.getEvent())
                .organiser(organiser)
                .boostPackage(newPackage)
                .status(BoostStatus.ACTIVE)
                .amount(finalPrice)
                .paymentIntentId(paymentIntentId)
                .paidAt(now)
                .startTime(now)
                .endTime(now.plusDays(configuredDuration(newPackage)))
                .viewsBeforeBoost(safeCount(eventViewRepository.countByEvent(existingBoost.getEvent())))
                .registrationsBeforeBoost(safeCount(
                        registrationRepository.countByEventAndStatusIn(
                                existingBoost.getEvent(),
                                BOOST_REGISTRATION_STATUSES
                        )
                ))
                .build();

        newBoost = boostRepository.save(newBoost);
        log.info("Upgraded boost from {} to {} for event {}",
                existingBoost.getBoostPackage(), newPackage, existingBoost.getEvent().getId());

        return mapToResponse(newBoost);
    }

    /**
     * Idempotent post-checkout confirmation. Frontend calls this when Stripe redirects back;
     * the Stripe webhook may or may not have fired first depending on environment (e.g. local
     * dev without Stripe CLI). Handles every action cleanly and is safe to call twice:
     *
     *   EXTEND          — boost is already ACTIVE; add the package's duration to endTime
     *   UPGRADE/DOWNGRADE — the pending new-tier boost might already be ACTIVE (webhook
     *                     already ran and self-heal expired the old tier) or still PENDING
     *                     (webhook missed); either way finish by ensuring pending→ACTIVE and
     *                     the old tier is expired
     *   NEW (default)   — flip PENDING→ACTIVE; if already ACTIVE, just return it
     */
    @Transactional
    public BoostResponse confirmPayment(UUID boostId, String action, UUID existingBoostId, User organiser) {
        EventBoost boost = boostRepository.findById(boostId)
                .orElseThrow(() -> new ResourceNotFoundException("Boost not found"));
        if (!boost.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You can only confirm your own boosts");
        }

        if ("EXTEND".equals(action)) {
            if (boost.getStatus() == BoostStatus.ACTIVE) {
                return extendBoost(boostId, organiser, "payment_confirmed");
            }
            // Fallback: someone landed on EXTEND but the target boost isn't ACTIVE anymore —
            // treat as a regular activate to avoid stuck PENDING rows.
            return activateBoost(boostId, "payment_confirmed");
        }

        // UPGRADE / DOWNGRADE / NEW — all reduce to "make sure this boost is ACTIVE".
        // activateBoost's self-heal logic handles expiring the previous tier on the same
        // event; passing existingBoostId is unnecessary because the unique filtered index
        // keeps only one ACTIVE per event anyway.
        if (boost.getStatus() == BoostStatus.PENDING) {
            return activateBoost(boostId, "payment_confirmed");
        }
        if (boost.getStatus() == BoostStatus.ACTIVE) {
            // Webhook already activated. Belt-and-braces: if caller passed an existingBoostId
            // that is somehow still ACTIVE (webhook race on a different event), expire it.
            if (existingBoostId != null && !existingBoostId.equals(boostId)) {
                boostRepository.findById(existingBoostId).ifPresent(old -> {
                    if (old.getStatus() == BoostStatus.ACTIVE
                            && old.getOrganiser().getId().equals(organiser.getId())) {
                        old.setStatus(BoostStatus.EXPIRED);
                        old.setEndTime(LocalDateTime.now());
                        boostRepository.save(old);
                    }
                });
            }
            return mapToResponse(boost);
        }
        // CANCELLED / EXPIRED — return as-is; the frontend will refresh and see the actual state.
        return mapToResponse(boost);
    }

    @Transactional
    public BoostResponse activateBoost(UUID boostId, String paymentIntentId) {
        EventBoost boost = boostRepository.findById(boostId)
                .orElseThrow(() -> new ResourceNotFoundException("Boost not found"));

        if (boost.getStatus() != BoostStatus.PENDING) {
            throw new BadRequestException("Boost is not in pending status");
        }

        // Self-heal duplicates: if an ACTIVE boost already exists on this event (prior tier
        // before an upgrade, or race from double-click), expire them FIRST and flush so the
        // filtered unique index (UQ_event_boosts_one_active_per_event) sees them as EXPIRED
        // by the time we flip this PENDING→ACTIVE. Without the flush, Hibernate batches both
        // UPDATEs and the index rejects the second with "This record already exists".
        UUID eventId = boost.getEvent().getId();
        List<EventBoost> existingActive = boostRepository.findByEventIdAndStatus(eventId, BoostStatus.ACTIVE);
        boolean didExpire = false;
        for (EventBoost other : existingActive) {
            if (!other.getId().equals(boost.getId())) {
                other.setStatus(BoostStatus.EXPIRED);
                other.setEndTime(LocalDateTime.now());
                boostRepository.save(other);
                didExpire = true;
                log.info("Auto-expired stale active boost {} on event {} in favour of new boost {}",
                        other.getId(), eventId, boost.getId());
            }
        }
        if (didExpire) {
            // Force the EXPIRED updates to hit the DB now, before the VIP UPDATE follows —
            // otherwise SQL Server sees two ACTIVE rows for the event in the same statement
            // batch and the filtered unique index rejects the whole transaction.
            boostRepository.flush();
        }

        LocalDateTime now = LocalDateTime.now();
        boost.setStatus(BoostStatus.ACTIVE);
        boost.setPaymentIntentId(paymentIntentId);
        boost.setPaidAt(now);
        boost.setStartTime(now);
        boost.setEndTime(now.plusDays(configuredDuration(boost.getBoostPackage())));
        boost.setViewsBeforeBoost(safeCount(eventViewRepository.countByEvent(boost.getEvent())));
        boost.setRegistrationsBeforeBoost(safeCount(
                registrationRepository.countByEventAndStatusIn(boost.getEvent(), BOOST_REGISTRATION_STATUSES)
        ));

        // Single-transaction race is handled above by expiring siblings before flipping
        // this boost to ACTIVE. Cross-transaction races are blocked by the DB filtered
        // unique index `UQ_event_boosts_one_active_per_event` — if that fires, the webhook
        // returns 500 and Stripe retries, which re-enters activateBoost where the sibling
        // is now visible and gets expired cleanly.
        boost = boostRepository.save(boost);
        log.info("Boost activated: {} for event {}", boostId, boost.getEvent().getId());

        // Blast a notification to every follower of the organiser so the newly-featured event
        // reaches its audience immediately, not just via passive list ranking.
        try {
            notificationService.notifyFollowersOfBoost(
                    boost.getOrganiser(),
                    boost.getEvent(),
                    boost.getBoostPackage().getBadgeText());
        } catch (Exception e) {
            log.warn("Failed to notify followers of boost activation {}: {}", boostId, e.getMessage());
        }

        return mapToResponse(boost);
    }

    @Transactional
    public void cancelBoost(UUID boostId, User organiser) {
        EventBoost boost = boostRepository.findById(boostId)
                .orElseThrow(() -> new ResourceNotFoundException("Boost not found"));

        if (!boost.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You can only cancel your own boosts");
        }

        if (boost.getStatus() == BoostStatus.ACTIVE) {
            throw new BadRequestException("Cannot cancel active boost. Contact support for refund.");
        }

        boost.setStatus(BoostStatus.CANCELLED);
        boostRepository.save(boost);
    }

    public Page<BoostResponse> getOrganiserBoosts(UUID organiserId, BoostStatus status, Pageable pageable) {
        Page<EventBoost> boosts;
        if (status != null) {
            boosts = boostRepository.findByOrganiserIdAndStatus(organiserId, status, pageable);
        } else {
            boosts = boostRepository.findByOrganiserId(organiserId, pageable);
        }
        return boosts.map(this::mapToResponse);
    }

    public BoostResponse getBoostById(UUID boostId) {
        EventBoost boost = boostRepository.findById(boostId)
                .orElseThrow(() -> new ResourceNotFoundException("Boost not found"));
        return mapToResponse(boost);
    }

    public List<UUID> getBoostedEventIds() {
        return boostRepository.findBoostedEventIds(LocalDateTime.now());
    }

    // Home-surface caps — keep the carousel short enough to stay interesting,
    // and stop a single organiser buying many slots from dominating the view.
    private static final int MAX_FEATURED_EVENTS = 24;
    private static final int MAX_BANNER_EVENTS = 6;
    private static final int MAX_PER_ORGANISER_FEATURED = 2;
    private static final int MAX_PER_ORGANISER_BANNER = 1;

    public List<Event> getFeaturedEvents() {
        // Filter by admin-configured featured flags (not hardcoded tier names). Admin can
        // toggle featuredOnHome / featuredInCategory off on VIP and any ACTIVE boost of that
        // tier stops appearing in the Home Featured row; likewise a new custom tier with
        // featuredOnHome=true surfaces here automatically.
        java.util.Set<String> featuredKeys = boostConfigService.activeFeaturedKeys();
        List<EventBoost> featuredBoosts = boostRepository.findFeaturedBoosts(LocalDateTime.now()).stream()
                .filter(b -> featuredKeys.contains(b.getBoostPackage().name()))
                .collect(java.util.stream.Collectors.toList());

        java.util.Map<UUID, EventBoost> uniqueBoosts = new java.util.LinkedHashMap<>();
        for (EventBoost boost : featuredBoosts) {
            uniqueBoosts.putIfAbsent(boost.getEvent().getId(), boost);
        }

        return smartArrangeBoosts(
                new java.util.ArrayList<>(uniqueBoosts.values()),
                MAX_PER_ORGANISER_FEATURED, MAX_FEATURED_EVENTS)
                .stream().map(EventBoost::getEvent)
                .collect(java.util.stream.Collectors.toList());
    }

    public List<Event> getHomeBannerEvents() {
        // Admin-controlled: only tiers whose config row has homeBanner=true AND active=true
        // render as a banner. Flipping homeBanner=false on VIP hides VIP banners immediately.
        java.util.Set<String> bannerKeys = boostConfigService.activeHomeBannerKeys();
        if (bannerKeys.isEmpty()) return java.util.Collections.emptyList();

        List<EventBoost> bannerBoosts = boostRepository.findFeaturedBoosts(LocalDateTime.now()).stream()
                .filter(b -> bannerKeys.contains(b.getBoostPackage().name()))
                .collect(java.util.stream.Collectors.toList());

        java.util.Map<UUID, EventBoost> uniqueBoosts = new java.util.LinkedHashMap<>();
        for (EventBoost boost : bannerBoosts) {
            uniqueBoosts.putIfAbsent(boost.getEvent().getId(), boost);
        }

        return smartArrangeBoosts(
                new java.util.ArrayList<>(uniqueBoosts.values()),
                MAX_PER_ORGANISER_BANNER, MAX_BANNER_EVENTS)
                .stream().map(EventBoost::getEvent)
                .collect(java.util.stream.Collectors.toList());
    }

    /**
     * Smart arrangement for boosted/featured slots:
     * 1) Keep VIP above PREMIUM above STANDARD above BASIC so paying more always wins the
     *    higher slot.
     * 2) Rotate within each tier by the current hour so every paying organiser cycles
     *    through the top slot over the day — prevents "first buyer sits forever".
     * 3) Cap per-organiser so one account can't flood the surface.
     * 4) Final total cap keeps the carousel short enough to stay scannable.
     */
    private List<EventBoost> smartArrangeBoosts(List<EventBoost> boosts,
                                                int maxPerOrganiser,
                                                int maxTotal) {
        if (boosts.isEmpty()) return boosts;

        java.util.Map<BoostPackage, List<EventBoost>> byTier = new java.util.LinkedHashMap<>();
        for (BoostPackage tier : new BoostPackage[]{BoostPackage.VIP, BoostPackage.PREMIUM,
                                                    BoostPackage.STANDARD, BoostPackage.BASIC}) {
            byTier.put(tier, new java.util.ArrayList<>());
        }
        for (EventBoost b : boosts) {
            byTier.computeIfAbsent(b.getBoostPackage(), k -> new java.util.ArrayList<>()).add(b);
        }

        int rotation = LocalDateTime.now().getHour();
        List<EventBoost> arranged = new java.util.ArrayList<>(boosts.size());
        for (List<EventBoost> tierList : byTier.values()) {
            int n = tierList.size();
            if (n == 0) continue;
            int start = Math.floorMod(rotation, n);
            for (int i = 0; i < n; i++) {
                arranged.add(tierList.get((start + i) % n));
            }
        }

        java.util.Map<UUID, Integer> perOrganiser = new java.util.HashMap<>();
        List<EventBoost> result = new java.util.ArrayList<>(Math.min(arranged.size(), maxTotal));
        for (EventBoost b : arranged) {
            UUID orgId = b.getOrganiser() != null ? b.getOrganiser().getId() : null;
            int used = orgId != null ? perOrganiser.getOrDefault(orgId, 0) : 0;
            if (used >= maxPerOrganiser) continue;
            result.add(b);
            if (orgId != null) perOrganiser.put(orgId, used + 1);
            if (result.size() >= maxTotal) break;
        }
        return result;
    }

    public boolean isEventBoosted(UUID eventId) {
        return boostRepository.hasActiveBoost(eventId, LocalDateTime.now());
    }

    public BoostPackage getEventBoostPackage(UUID eventId) {
        return boostRepository.findByEventIdAndStatus(eventId, BoostStatus.ACTIVE)
                .stream()
                .filter(EventBoost::isActive)
                .findFirst()
                .map(EventBoost::getBoostPackage)
                .orElse(null);
    }

    public Page<BoostResponse> getAllBoosts(BoostStatus status, Pageable pageable) {
        Page<EventBoost> boosts;
        if (status != null) {
            boosts = boostRepository.findByStatus(status, pageable);
        } else {
            boosts = boostRepository.findAll(pageable);
        }
        return boosts.map(this::mapToResponse);
    }

    @Scheduled(fixedRate = 60000)
    @Transactional
    public void expireBoosts() {
        int expired = boostRepository.expireBoosts(LocalDateTime.now());
        if (expired > 0) {
            log.info("Expired {} boosts", expired);
        }
    }

    /**
     * Garbage-collect abandoned PENDING boosts. A PENDING row is created when the organiser
     * clicks Boost Now; it should flip to ACTIVE once Stripe fires the webhook. If it sits
     * PENDING for longer than {@value #PENDING_BOOST_TIMEOUT_MINUTES} minutes the organiser
     * either bailed on Stripe checkout or the webhook never arrived — the row just clogs the
     * Boost History as "Pending Payment" forever and also blocks them from trying again
     * (createBoost rejects duplicate PENDING on same event). Auto-cancel so the UI is honest
     * and retries are unblocked.
     */
    private static final int PENDING_BOOST_TIMEOUT_MINUTES = 30;

    @Scheduled(fixedRate = 300000) // every 5 min
    @Transactional
    public void cancelAbandonedPendingBoosts() {
        LocalDateTime cutoff = LocalDateTime.now().minusMinutes(PENDING_BOOST_TIMEOUT_MINUTES);
        int cancelled = boostRepository.cancelStalePending(cutoff);
        if (cancelled > 0) {
            log.info("Auto-cancelled {} abandoned PENDING boosts older than {} minutes",
                    cancelled, PENDING_BOOST_TIMEOUT_MINUTES);
        }
    }

    /**
     * Admin/moderation: stop a boost immediately regardless of its original endTime.
     * Sets status=EXPIRED and clamps endTime to now so it disappears from every home surface
     * and listing on the next request.
     */
    @Transactional
    public BoostResponse forceExpireBoost(UUID boostId) {
        EventBoost boost = boostRepository.findById(boostId)
                .orElseThrow(() -> new ResourceNotFoundException("Boost not found"));
        if (boost.getStatus() == BoostStatus.EXPIRED) {
            return mapToResponse(boost);
        }
        boost.setStatus(BoostStatus.EXPIRED);
        boost.setEndTime(LocalDateTime.now());
        boost = boostRepository.save(boost);
        log.info("Admin force-expired boost {} for event {}", boostId, boost.getEvent().getId());
        return mapToResponse(boost);
    }

    @Transactional
    public void updateBoostStats(UUID eventId, int views, int clicks, int registrations) {
        boostRepository.findByEventIdAndStatus(eventId, BoostStatus.ACTIVE)
                .stream()
                .filter(EventBoost::isActive)
                .findFirst()
                .ifPresent(boost -> {
                    boost.setViewsDuringBoost(boost.getViewsDuringBoost() + views);
                    boost.setClicksDuringBoost(boost.getClicksDuringBoost() + clicks);
                    boost.setRegistrationsDuringBoost(boost.getRegistrationsDuringBoost() + registrations);
                    boostRepository.save(boost);
                });
    }

    private int safeCount(long count) {
        return count > Integer.MAX_VALUE ? Integer.MAX_VALUE : (int) count;
    }

    private LocalDateTime resolveStatsWindowEnd(EventBoost boost, LocalDateTime now) {
        if (boost.getStartTime() == null) {
            return null;
        }

        if (boost.getStatus() == BoostStatus.CANCELLED
                && boost.getUpdatedAt() != null
                && boost.getUpdatedAt().isAfter(boost.getStartTime())) {
            return boost.getUpdatedAt();
        }

        if (boost.getEndTime() != null && !boost.getEndTime().isAfter(now)) {
            return boost.getEndTime();
        }

        return null;
    }

    private int calculateViewsDuringBoost(EventBoost boost, LocalDateTime now) {
        if (boost.getStartTime() == null) {
            return boost.getViewsDuringBoost();
        }

        LocalDateTime windowEnd = resolveStatsWindowEnd(boost, now);
        long views = windowEnd == null
                ? eventViewRepository.countByEventAndCreatedAtAfter(boost.getEvent(), boost.getStartTime())
                : eventViewRepository.countByEventAndCreatedAtRange(boost.getEvent(), boost.getStartTime(), windowEnd);
        return safeCount(views);
    }

    private int calculateRegistrationsDuringBoost(EventBoost boost, LocalDateTime now) {
        if (boost.getStartTime() == null) {
            return boost.getRegistrationsDuringBoost();
        }

        LocalDateTime windowEnd = resolveStatsWindowEnd(boost, now);
        long registrations = windowEnd == null
                ? registrationRepository.countByEventAndStatusInAndCreatedAtAfter(
                        boost.getEvent(),
                        BOOST_REGISTRATION_STATUSES,
                        boost.getStartTime()
                )
                : registrationRepository.countByEventAndStatusInAndCreatedAtRange(
                        boost.getEvent(),
                        BOOST_REGISTRATION_STATUSES,
                        boost.getStartTime(),
                        windowEnd
                );
        return safeCount(registrations);
    }

    private BoostResponse mapToResponse(EventBoost boost) {
        Event event = boost.getEvent();
        LocalDateTime now = LocalDateTime.now();
        int viewsDuringBoost = calculateViewsDuringBoost(boost, now);
        int registrationsDuringBoost = calculateRegistrationsDuringBoost(boost, now);

        int daysRemaining = 0;
        if (boost.getStatus() == BoostStatus.ACTIVE && boost.getEndTime() != null) {
            daysRemaining = (int) ChronoUnit.DAYS.between(now, boost.getEndTime());
            if (daysRemaining < 0) daysRemaining = 0;
        }

        return BoostResponse.builder()
                .id(boost.getId())
                .eventId(event.getId())
                .eventTitle(event.getTitle())
                .eventImageUrl(event.getImageUrl())
                .boostPackage(boost.getBoostPackage())
                .packageDisplayName(boost.getBoostPackage().getDisplayName())
                .status(boost.getStatus())
                .amount(boost.getAmount())
                .startTime(boost.getStartTime())
                .endTime(boost.getEndTime())
                .paidAt(boost.getPaidAt())
                .isActive(boost.isActive())
                .daysRemaining(daysRemaining)
                .viewsBeforeBoost(boost.getViewsBeforeBoost())
                .viewsDuringBoost(viewsDuringBoost)
                .clicksBeforeBoost(boost.getClicksBeforeBoost())
                .clicksDuringBoost(boost.getClicksDuringBoost())
                .registrationsBeforeBoost(boost.getRegistrationsBeforeBoost())
                .registrationsDuringBoost(registrationsDuringBoost)
                .conversionRate(viewsDuringBoost > 0 ? (double) registrationsDuringBoost / viewsDuringBoost * 100 : 0)
                .createdAt(boost.getCreatedAt())
                .build();
    }
}

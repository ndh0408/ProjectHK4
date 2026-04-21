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

    private static final List<RegistrationStatus> BOOST_REGISTRATION_STATUSES = List.of(
            RegistrationStatus.PENDING,
            RegistrationStatus.APPROVED,
            RegistrationStatus.WAITING_LIST
    );

    public List<BoostPackageInfo> getAvailablePackages() {
        return Arrays.stream(BoostPackage.values())
                .map(BoostPackageInfo::fromEnum)
                .collect(Collectors.toList());
    }

    public List<BoostPackageInfo> getAvailablePackagesWithDiscount(UUID organiserId) {
        int discountPercent = subscriptionService.getBoostDiscountPercent(organiserId);

        return Arrays.stream(BoostPackage.values())
                .map(pkg -> {
                    BoostPackageInfo info = BoostPackageInfo.fromEnum(pkg);
                    if (discountPercent > 0) {
                        java.math.BigDecimal discountedPrice = pkg.getPrice()
                                .multiply(java.math.BigDecimal.valueOf(100 - discountPercent))
                                .divide(java.math.BigDecimal.valueOf(100), 2, java.math.RoundingMode.HALF_UP);
                        info.setPrice(discountedPrice);
                        info.setPriceFormatted(String.format("$%.2f", discountedPrice));
                        info.setDescription(info.getDescription() + " (" + discountPercent + "% subscription discount applied)");
                    }
                    return info;
                })
                .collect(Collectors.toList());
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

        int discountPercent = subscriptionService.getBoostDiscountPercent(organiser.getId());
        java.math.BigDecimal finalPrice = pkg.getPrice();
        if (discountPercent > 0) {
            finalPrice = pkg.getPrice()
                    .multiply(java.math.BigDecimal.valueOf(100 - discountPercent))
                    .divide(java.math.BigDecimal.valueOf(100), 2, java.math.RoundingMode.HALF_UP);
            log.info("Applied {}% subscription discount to boost. Original: {}, Final: {}",
                    discountPercent, pkg.getPrice(), finalPrice);
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
                .endTime(now.plusDays(pkg.getDurationDays()))
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

        if (currentPackage == newPackage) {
            java.math.BigDecimal extendPrice = newPackage.getPrice();
            if (discountPercent > 0) {
                extendPrice = extendPrice
                        .multiply(java.math.BigDecimal.valueOf(100 - discountPercent))
                        .divide(java.math.BigDecimal.valueOf(100), 2, java.math.RoundingMode.HALF_UP);
            }

            LocalDateTime newEndTime = endTime != null
                    ? endTime.plusDays(newPackage.getDurationDays())
                    : LocalDateTime.now().plusDays(newPackage.getDurationDays());

            return BoostUpgradeInfo.builder()
                    .hasExistingBoost(true)
                    .canBoost(true)
                    .action(BoostAction.EXTEND)
                    .currentPackage(currentPackage)
                    .currentBoostId(currentBoost.getId())
                    .remainingDays((int) remainingDays)
                    .currentEndTime(endTime)
                    .newEndTime(newEndTime)
                    .additionalDays(newPackage.getDurationDays())
                    .price(extendPrice)
                    .message(String.format("Extend your %s boost by %d more days",
                            currentPackage.getDisplayName(), newPackage.getDurationDays()))
                    .build();
        } else {
            int currentTier = getPackageTier(currentPackage);
            int newTier = getPackageTier(newPackage);

            java.math.BigDecimal newPrice = newPackage.getPrice();
            if (discountPercent > 0) {
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
                    .newEndTime(LocalDateTime.now().plusDays(newPackage.getDurationDays()))
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

        List<EventBoost> activeBoosts = boostRepository.findByEventIdAndStatus(event.getId(), BoostStatus.ACTIVE);
        boolean hasActiveBoost = activeBoosts.stream().anyMatch(EventBoost::isActive);

        if (hasActiveBoost) {
            log.info("Event {} has active boost, creating extend/upgrade request", event.getId());
        }

        int discountPercent = subscriptionService.getBoostDiscountPercent(organiser.getId());
        java.math.BigDecimal finalPrice = pkg.getPrice();
        if (discountPercent > 0) {
            finalPrice = pkg.getPrice()
                    .multiply(java.math.BigDecimal.valueOf(100 - discountPercent))
                    .divide(java.math.BigDecimal.valueOf(100), 2, java.math.RoundingMode.HALF_UP);
            log.info("Applied {}% subscription discount to boost. Original: {}, Final: {}",
                    discountPercent, pkg.getPrice(), finalPrice);
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
        java.math.BigDecimal finalPrice = newPackage.getPrice();
        if (discountPercent > 0) {
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
                .endTime(now.plusDays(newPackage.getDurationDays()))
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

    @Transactional
    public BoostResponse activateBoost(UUID boostId, String paymentIntentId) {
        EventBoost boost = boostRepository.findById(boostId)
                .orElseThrow(() -> new ResourceNotFoundException("Boost not found"));

        if (boost.getStatus() != BoostStatus.PENDING) {
            throw new BadRequestException("Boost is not in pending status");
        }

        LocalDateTime now = LocalDateTime.now();
        boost.setStatus(BoostStatus.ACTIVE);
        boost.setPaymentIntentId(paymentIntentId);
        boost.setPaidAt(now);
        boost.setStartTime(now);
        boost.setEndTime(now.plusDays(boost.getBoostPackage().getDurationDays()));
        boost.setViewsBeforeBoost(safeCount(eventViewRepository.countByEvent(boost.getEvent())));
        boost.setRegistrationsBeforeBoost(safeCount(
                registrationRepository.countByEventAndStatusIn(boost.getEvent(), BOOST_REGISTRATION_STATUSES)
        ));

        boost = boostRepository.save(boost);
        log.info("Boost activated: {} for event {}", boostId, boost.getEvent().getId());
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

    public List<Event> getFeaturedEvents() {
        List<EventBoost> featuredBoosts = boostRepository.findFeaturedBoosts(LocalDateTime.now());
        
        // Remove duplicates - keep only the highest package boost per event
        java.util.Map<UUID, EventBoost> uniqueBoosts = new java.util.HashMap<>();
        for (EventBoost boost : featuredBoosts) {
            UUID eventId = boost.getEvent().getId();
            EventBoost existing = uniqueBoosts.get(eventId);
            
            // Keep VIP > PREMIUM > STANDARD > BASIC
            if (existing == null || boost.getBoostPackage().compareTo(existing.getBoostPackage()) > 0) {
                uniqueBoosts.put(eventId, boost);
            }
        }
        
        return uniqueBoosts.values().stream()
                .map(EventBoost::getEvent)
                .collect(java.util.stream.Collectors.toList());
    }

    public List<Event> getHomeBannerEvents() {
        List<EventBoost> bannerBoosts = boostRepository.findHomeBannerBoosts(LocalDateTime.now());
        
        // Remove duplicates - keep only one boost per event
        java.util.Map<UUID, EventBoost> uniqueBoosts = new java.util.HashMap<>();
        for (EventBoost boost : bannerBoosts) {
            uniqueBoosts.put(boost.getEvent().getId(), boost);
        }
        
        return uniqueBoosts.values().stream()
                .map(EventBoost::getEvent)
                .collect(java.util.stream.Collectors.toList());
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

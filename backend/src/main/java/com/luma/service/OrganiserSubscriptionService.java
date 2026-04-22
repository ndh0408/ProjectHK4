package com.luma.service;

import com.luma.dto.response.subscription.OrganiserSubscriptionResponse;
import com.luma.dto.response.subscription.SubscriptionPlanInfo;
import com.luma.entity.OrganiserSubscription;
import com.luma.entity.User;
import com.luma.entity.enums.SubscriptionPlan;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.OrganiserSubscriptionRepository;
import com.luma.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class OrganiserSubscriptionService {

    private final OrganiserSubscriptionRepository subscriptionRepository;
    private final UserRepository userRepository;
    private final SubscriptionPlanConfigService planConfigService;

    public List<SubscriptionPlanInfo> getAllPlans() {
        return planConfigService.listActive().stream()
                .map(cfg -> {
                    // Config key may be a canonical enum name or a custom admin-added plan.
                    SubscriptionPlan planEnum;
                    try { planEnum = SubscriptionPlan.valueOf(cfg.getPlanKey()); }
                    catch (IllegalArgumentException ex) { planEnum = null; }
                    SubscriptionPlanInfo info = planEnum != null
                            ? SubscriptionPlanInfo.fromEnum(planEnum)
                            : SubscriptionPlanInfo.builder()
                                .name(cfg.getPlanKey())
                                .planType(null)
                                .displayName(cfg.getDisplayName())
                                .features(java.util.List.of())
                                .badge(cfg.getPlanKey())
                                .badgeColor("#6B7280")
                                .description(cfg.getDisplayName() + " plan")
                                .build();
                    info.setMonthlyPrice(cfg.getMonthlyPriceUsd());
                    info.setPriceFormatted(String.format("$%.2f", cfg.getMonthlyPriceUsd()));
                    info.setMaxEventsPerMonth(cfg.getMaxEventsPerMonth() == -1
                            ? "Unlimited" : String.valueOf(cfg.getMaxEventsPerMonth()));
                    info.setBoostDiscountPercent(cfg.getBoostDiscountPercent());
                    info.setDisplayName(cfg.getDisplayName());
                    return info;
                })
                .collect(Collectors.toList());
    }

    /** Admin-edited monthly price for a plan, falling back to enum defaults. */
    public java.math.BigDecimal getMonthlyPrice(SubscriptionPlan plan) {
        return planConfigService.getMonthlyPriceOrDefault(plan);
    }

    @Transactional
    public OrganiserSubscriptionResponse getOrCreateSubscription(UUID organiserId) {
        OrganiserSubscription subscription = subscriptionRepository.findByOrganiserId(organiserId)
                .orElseGet(() -> createFreeSubscription(organiserId));
        return OrganiserSubscriptionResponse.fromEntity(subscription);
    }

    @Transactional
    public OrganiserSubscription getOrCreateSubscriptionEntity(UUID organiserId) {
        return subscriptionRepository.findByOrganiserId(organiserId)
                .orElseGet(() -> createFreeSubscription(organiserId));
    }

    private OrganiserSubscription createFreeSubscription(UUID organiserId) {
        User organiser = userRepository.findById(organiserId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        OrganiserSubscription subscription = OrganiserSubscription.builder()
                .organiser(organiser)
                .plan(SubscriptionPlan.FREE)
                .isActive(true)
                .billingCycleStart(LocalDateTime.now())
                .build();

        try {
            return subscriptionRepository.save(subscription);
        } catch (org.springframework.dao.DataIntegrityViolationException race) {
            // Another concurrent request just inserted the FREE subscription for this
            // organiser (unique index on organiser_id). Re-read and return that row.
            log.warn("Free subscription insert race for organiser {} — fetching existing row", organiserId);
            return subscriptionRepository.findByOrganiserId(organiserId)
                    .orElseThrow(() -> race);
        }
    }

    @Transactional
    public OrganiserSubscriptionResponse upgradePlan(UUID organiserId, SubscriptionPlan newPlan) {
        OrganiserSubscription subscription = getOrCreateSubscriptionEntity(organiserId);
        SubscriptionPlan currentPlan = subscription.getEffectivePlan();

        if (newPlan == currentPlan) {
            throw new BadRequestException("You are already on the " + newPlan.getDisplayName() + " plan");
        }
        if (newPlan == SubscriptionPlan.FREE) {
            // Downgrade to FREE goes through cancelSubscription, not this path.
            throw new BadRequestException("Use cancel subscription to downgrade to FREE plan");
        }

        // Paid → paid transition — either upgrade (higher tier) or downgrade (lower tier).
        // Both are accepted here; the caller (frontend + controller) decides whether to charge
        // via Stripe checkout (upgrade) or apply immediately (downgrade — no new charge since
        // the organiser has already paid for higher).
        boolean isDowngrade = newPlan.ordinal() < currentPlan.ordinal();
        subscription.setPlan(newPlan);
        subscription.setStartDate(LocalDateTime.now());
        subscription.setEndDate(LocalDateTime.now().plusMonths(1));
        subscription.setActive(true);
        subscription.resetMonthlyUsage();

        OrganiserSubscription saved = subscriptionRepository.save(subscription);
        log.info("Organiser {} {} to {} plan (from {})",
                organiserId, isDowngrade ? "downgraded" : "upgraded", newPlan, currentPlan);

        return OrganiserSubscriptionResponse.fromEntity(saved);
    }

    /**
     * Plan-tier helper for the frontend / controller to decide whether a proposed plan
     * change is an upgrade (charge via Stripe), downgrade (apply immediately / refund
     * excess as store credit in a future iteration), or a no-op.
     */
    public String comparePlan(UUID organiserId, SubscriptionPlan newPlan) {
        SubscriptionPlan current = getOrCreateSubscriptionEntity(organiserId).getEffectivePlan();
        if (newPlan == current) return "SAME";
        if (newPlan == SubscriptionPlan.FREE) return "CANCEL";
        if (newPlan.ordinal() > current.ordinal()) return "UPGRADE";
        return "DOWNGRADE";
    }

    @Transactional
    public OrganiserSubscriptionResponse cancelSubscription(UUID organiserId) {
        OrganiserSubscription subscription = subscriptionRepository.findByOrganiserId(organiserId)
                .orElseThrow(() -> new ResourceNotFoundException("Subscription not found"));

        subscription.setPlan(SubscriptionPlan.FREE);
        subscription.setEndDate(null);
        subscription.setAutoRenew(false);
        subscription.setStripeSubscriptionId(null);

        OrganiserSubscription saved = subscriptionRepository.save(subscription);
        log.info("Organiser {} cancelled subscription, downgraded to FREE", organiserId);

        return OrganiserSubscriptionResponse.fromEntity(saved);
    }

    public boolean canCreateEvent(UUID organiserId) {
        OrganiserSubscription subscription = getOrCreateSubscriptionEntity(organiserId);
        return subscription.canCreateEvent();
    }

    public int getBoostDiscountPercent(UUID organiserId) {
        OrganiserSubscription subscription = getOrCreateSubscriptionEntity(organiserId);
        // Prefer admin-editable config, fall back to enum default.
        return planConfigService.getBoostDiscountPercentOrDefault(subscription.getEffectivePlan());
    }

    @Transactional
    public void incrementEventCount(UUID organiserId) {
        OrganiserSubscription subscription = getOrCreateSubscriptionEntity(organiserId);
        subscription.incrementEventCount();
        subscriptionRepository.save(subscription);
    }

    public void validateEventCreation(UUID organiserId) {
        if (!canCreateEvent(organiserId)) {
            OrganiserSubscription subscription = getOrCreateSubscriptionEntity(organiserId);
            SubscriptionPlan plan = subscription.getEffectivePlan();
            throw new BadRequestException(String.format(
                    "Event limit reached. Your %s plan allows %d events per month. " +
                    "Please upgrade to create more events.",
                    plan.getDisplayName(), plan.getMaxEventsPerMonth()));
        }
    }

}

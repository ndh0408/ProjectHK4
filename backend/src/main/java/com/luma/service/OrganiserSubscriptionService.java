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

    /**
     * Get all available subscription plans
     */
    public List<SubscriptionPlanInfo> getAllPlans() {
        return Arrays.stream(SubscriptionPlan.values())
                .map(SubscriptionPlanInfo::fromEnum)
                .collect(Collectors.toList());
    }

    /**
     * Get subscription for an organiser (creates FREE if not exists)
     */
    @Transactional
    public OrganiserSubscriptionResponse getOrCreateSubscription(UUID organiserId) {
        OrganiserSubscription subscription = subscriptionRepository.findByOrganiserId(organiserId)
                .orElseGet(() -> createFreeSubscription(organiserId));
        return OrganiserSubscriptionResponse.fromEntity(subscription);
    }

    /**
     * Get subscription entity for an organiser
     */
    @Transactional
    public OrganiserSubscription getOrCreateSubscriptionEntity(UUID organiserId) {
        return subscriptionRepository.findByOrganiserId(organiserId)
                .orElseGet(() -> createFreeSubscription(organiserId));
    }

    /**
     * Create a FREE subscription for new organiser
     */
    private OrganiserSubscription createFreeSubscription(UUID organiserId) {
        User organiser = userRepository.findById(organiserId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        OrganiserSubscription subscription = OrganiserSubscription.builder()
                .organiser(organiser)
                .plan(SubscriptionPlan.FREE)
                .isActive(true)
                .billingCycleStart(LocalDateTime.now())
                .build();

        return subscriptionRepository.save(subscription);
    }

    /**
     * Upgrade subscription to a new plan
     */
    @Transactional
    public OrganiserSubscriptionResponse upgradePlan(UUID organiserId, SubscriptionPlan newPlan) {
        OrganiserSubscription subscription = getOrCreateSubscriptionEntity(organiserId);
        SubscriptionPlan currentPlan = subscription.getEffectivePlan();

        // Validate upgrade
        if (newPlan == SubscriptionPlan.FREE) {
            throw new BadRequestException("Cannot upgrade to FREE plan. Use downgrade instead.");
        }

        if (newPlan.ordinal() <= currentPlan.ordinal() && currentPlan != SubscriptionPlan.FREE) {
            throw new BadRequestException("New plan must be higher than current plan");
        }

        // Update subscription
        subscription.setPlan(newPlan);
        subscription.setStartDate(LocalDateTime.now());
        subscription.setEndDate(LocalDateTime.now().plusMonths(1));
        subscription.setActive(true);
        subscription.resetMonthlyUsage();

        OrganiserSubscription saved = subscriptionRepository.save(subscription);
        log.info("Organiser {} upgraded to {} plan", organiserId, newPlan);

        return OrganiserSubscriptionResponse.fromEntity(saved);
    }

    /**
     * Downgrade to FREE plan (cancel subscription)
     */
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

    // ==================== Usage Tracking ====================

    /**
     * Check if organiser can create an event
     */
    public boolean canCreateEvent(UUID organiserId) {
        OrganiserSubscription subscription = getOrCreateSubscriptionEntity(organiserId);
        return subscription.canCreateEvent();
    }

    /**
     * Check if organiser can use AI feature
     */
    public boolean canUseAI(UUID organiserId) {
        OrganiserSubscription subscription = getOrCreateSubscriptionEntity(organiserId);
        return subscription.canUseAI();
    }

    /**
     * Check if organiser can generate certificates
     */
    public boolean canGenerateCertificates(UUID organiserId) {
        OrganiserSubscription subscription = getOrCreateSubscriptionEntity(organiserId);
        return subscription.getEffectivePlan().isCanGenerateCertificates();
    }

    /**
     * Check if organiser can export to Excel
     */
    public boolean canExportExcel(UUID organiserId) {
        OrganiserSubscription subscription = getOrCreateSubscriptionEntity(organiserId);
        return subscription.getEffectivePlan().isCanExportExcel();
    }

    /**
     * Get max attendees allowed per event
     */
    public int getMaxAttendeesPerEvent(UUID organiserId) {
        OrganiserSubscription subscription = getOrCreateSubscriptionEntity(organiserId);
        return subscription.getEffectivePlan().getMaxAttendeesPerEvent();
    }

    /**
     * Get boost discount percentage
     */
    public int getBoostDiscountPercent(UUID organiserId) {
        OrganiserSubscription subscription = getOrCreateSubscriptionEntity(organiserId);
        return subscription.getEffectivePlan().getBoostDiscountPercent();
    }

    /**
     * Increment event creation count
     */
    @Transactional
    public void incrementEventCount(UUID organiserId) {
        OrganiserSubscription subscription = getOrCreateSubscriptionEntity(organiserId);
        subscription.incrementEventCount();
        subscriptionRepository.save(subscription);
    }

    /**
     * Increment AI usage count
     */
    @Transactional
    public void incrementAIUsage(UUID organiserId) {
        OrganiserSubscription subscription = getOrCreateSubscriptionEntity(organiserId);
        subscription.incrementAIUsage();
        subscriptionRepository.save(subscription);
    }

    // ==================== Validation Methods ====================

    /**
     * Validate event creation (throws exception if not allowed)
     */
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

    /**
     * Validate AI usage (throws exception if not allowed)
     */
    public void validateAIUsage(UUID organiserId) {
        if (!canUseAI(organiserId)) {
            OrganiserSubscription subscription = getOrCreateSubscriptionEntity(organiserId);
            SubscriptionPlan plan = subscription.getEffectivePlan();
            throw new BadRequestException(String.format(
                    "AI usage limit reached. Your %s plan allows %d AI generations per month. " +
                    "Please upgrade for more AI features.",
                    plan.getDisplayName(), plan.getAiUsagePerMonth()));
        }
    }

    /**
     * Validate certificate generation (throws exception if not allowed)
     */
    public void validateCertificateGeneration(UUID organiserId) {
        if (!canGenerateCertificates(organiserId)) {
            throw new BadRequestException(
                    "Certificate generation is not available on your plan. " +
                    "Please upgrade to STANDARD or higher to generate certificates.");
        }
    }

    /**
     * Validate Excel export (throws exception if not allowed)
     */
    public void validateExcelExport(UUID organiserId) {
        if (!canExportExcel(organiserId)) {
            throw new BadRequestException(
                    "Excel export is not available on your plan. " +
                    "Please upgrade to STANDARD or higher to export to Excel.");
        }
    }

    /**
     * Validate attendee capacity (throws exception if exceeded)
     */
    public void validateAttendeeCapacity(UUID organiserId, int requestedCapacity) {
        int maxCapacity = getMaxAttendeesPerEvent(organiserId);
        if (maxCapacity != -1 && requestedCapacity > maxCapacity) {
            OrganiserSubscription subscription = getOrCreateSubscriptionEntity(organiserId);
            throw new BadRequestException(String.format(
                    "Attendee limit exceeded. Your %s plan allows up to %d attendees per event. " +
                    "Please upgrade for larger events.",
                    subscription.getEffectivePlan().getDisplayName(), maxCapacity));
        }
    }
}

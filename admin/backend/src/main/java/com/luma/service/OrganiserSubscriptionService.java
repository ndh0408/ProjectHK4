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

    public List<SubscriptionPlanInfo> getAllPlans() {
        return Arrays.stream(SubscriptionPlan.values())
                .map(SubscriptionPlanInfo::fromEnum)
                .collect(Collectors.toList());
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

        return subscriptionRepository.save(subscription);
    }

    @Transactional
    public OrganiserSubscriptionResponse upgradePlan(UUID organiserId, SubscriptionPlan newPlan) {
        OrganiserSubscription subscription = getOrCreateSubscriptionEntity(organiserId);
        SubscriptionPlan currentPlan = subscription.getEffectivePlan();

        if (newPlan == SubscriptionPlan.FREE) {
            throw new BadRequestException("Cannot upgrade to FREE plan. Use downgrade instead.");
        }

        if (newPlan.ordinal() <= currentPlan.ordinal() && currentPlan != SubscriptionPlan.FREE) {
            throw new BadRequestException("New plan must be higher than current plan");
        }

        subscription.setPlan(newPlan);
        subscription.setStartDate(LocalDateTime.now());
        subscription.setEndDate(LocalDateTime.now().plusMonths(1));
        subscription.setActive(true);
        subscription.resetMonthlyUsage();

        OrganiserSubscription saved = subscriptionRepository.save(subscription);
        log.info("Organiser {} upgraded to {} plan", organiserId, newPlan);

        return OrganiserSubscriptionResponse.fromEntity(saved);
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
        return subscription.getEffectivePlan().getBoostDiscountPercent();
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

package com.luma.repository;

import com.luma.entity.OrganiserSubscription;
import com.luma.entity.enums.SubscriptionPlan;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface OrganiserSubscriptionRepository extends JpaRepository<OrganiserSubscription, UUID> {

    Optional<OrganiserSubscription> findByOrganiserId(UUID organiserId);

    boolean existsByOrganiserId(UUID organiserId);

    @Query("SELECT os FROM OrganiserSubscription os WHERE os.organiser.id = :organiserId AND os.isActive = true")
    Optional<OrganiserSubscription> findActiveByOrganiserId(@Param("organiserId") UUID organiserId);

    // Find subscriptions expiring soon (for reminder emails)
    @Query("SELECT os FROM OrganiserSubscription os WHERE os.isActive = true " +
           "AND os.plan != 'FREE' AND os.endDate BETWEEN :now AND :soon")
    List<OrganiserSubscription> findExpiringSoon(
            @Param("now") LocalDateTime now,
            @Param("soon") LocalDateTime soon);

    // Find expired subscriptions that need to be downgraded
    @Query("SELECT os FROM OrganiserSubscription os WHERE os.isActive = true " +
           "AND os.plan != 'FREE' AND os.endDate < :now")
    List<OrganiserSubscription> findExpired(@Param("now") LocalDateTime now);

    // Reset monthly usage for all subscriptions (scheduled job)
    @Modifying
    @Query("UPDATE OrganiserSubscription os SET os.eventsCreatedThisMonth = 0, " +
           "os.aiUsageThisMonth = 0, os.billingCycleStart = :now " +
           "WHERE os.billingCycleStart < :monthAgo")
    int resetMonthlyUsage(@Param("now") LocalDateTime now, @Param("monthAgo") LocalDateTime monthAgo);

    // Count by plan type (for analytics)
    @Query("SELECT os.plan, COUNT(os) FROM OrganiserSubscription os " +
           "WHERE os.isActive = true GROUP BY os.plan")
    List<Object[]> countByPlan();

    // Find by Stripe subscription ID
    Optional<OrganiserSubscription> findByStripeSubscriptionId(String stripeSubscriptionId);
}

package com.luma.repository;

import com.luma.entity.Coupon;
import com.luma.entity.Event;
import com.luma.entity.User;
import com.luma.entity.enums.CouponStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CouponRepository extends JpaRepository<Coupon, UUID> {

    Optional<Coupon> findByCode(String code);

    @Query("SELECT c FROM Coupon c WHERE c.code = :code AND c.status = 'ACTIVE'")
    Optional<Coupon> findActiveByCode(@Param("code") String code);

    Page<Coupon> findByCreatedByOrderByCreatedAtDesc(User createdBy, Pageable pageable);

    List<Coupon> findByEventAndStatus(Event event, CouponStatus status);

    @Modifying
    @Transactional
    @Query("UPDATE Coupon c SET c.usedCount = c.usedCount + 1 WHERE c.id = :id")
    void incrementUsedCount(@Param("id") UUID id);

    @Modifying
    @Transactional
    @Query("UPDATE Coupon c SET c.usedCount = CASE WHEN c.usedCount > 0 THEN c.usedCount - 1 ELSE 0 END WHERE c.id = :id")
    void decrementUsedCount(@Param("id") UUID id);

    boolean existsByCode(String code);

    @Query("SELECT c FROM Coupon c WHERE c.event IS NULL AND c.status = 'ACTIVE' " +
           "AND (c.validFrom IS NULL OR c.validFrom <= CURRENT_TIMESTAMP) " +
           "AND (c.validUntil IS NULL OR c.validUntil >= CURRENT_TIMESTAMP) " +
           "AND (c.maxUsageCount = 0 OR c.usedCount < c.maxUsageCount) " +
           "ORDER BY c.createdAt DESC")
    List<Coupon> findAvailableGlobalCoupons();

    @Query("SELECT c FROM Coupon c WHERE c.event.id = :eventId AND c.status = 'ACTIVE' " +
           "AND (c.validFrom IS NULL OR c.validFrom <= CURRENT_TIMESTAMP) " +
           "AND (c.validUntil IS NULL OR c.validUntil >= CURRENT_TIMESTAMP) " +
           "AND (c.maxUsageCount = 0 OR c.usedCount < c.maxUsageCount) " +
           "ORDER BY c.discountValue DESC")
    List<Coupon> findAvailableCouponsByEvent(@Param("eventId") UUID eventId);

    /**
     * Organiser-wide coupons (c.event IS NULL) authored by the same organiser
     * that owns the target event. Used to surface "shop coupons" on checkout.
     */
    @Query("SELECT c FROM Coupon c WHERE c.event IS NULL AND c.status = 'ACTIVE' " +
           "AND c.createdBy.id = (SELECT e.organiser.id FROM Event e WHERE e.id = :eventId) " +
           "AND (c.validFrom IS NULL OR c.validFrom <= CURRENT_TIMESTAMP) " +
           "AND (c.validUntil IS NULL OR c.validUntil >= CURRENT_TIMESTAMP) " +
           "AND (c.maxUsageCount = 0 OR c.usedCount < c.maxUsageCount) " +
           "ORDER BY c.discountValue DESC")
    List<Coupon> findOrganiserWideCouponsForEvent(@Param("eventId") UUID eventId);

    /**
     * All organiser-wide coupons a given user (organiser) has authored — used
     * by the user-facing "My Coupons" browse screen when no event context is
     * provided. Filters out expired / used-up / disabled rows.
     */
    @Query("SELECT c FROM Coupon c WHERE c.event IS NULL AND c.status = 'ACTIVE' " +
           "AND c.createdBy.id = :organiserId " +
           "AND (c.validFrom IS NULL OR c.validFrom <= CURRENT_TIMESTAMP) " +
           "AND (c.validUntil IS NULL OR c.validUntil >= CURRENT_TIMESTAMP) " +
           "AND (c.maxUsageCount = 0 OR c.usedCount < c.maxUsageCount) " +
           "ORDER BY c.createdAt DESC")
    List<Coupon> findActiveOrganiserWideCouponsByOrganiser(@Param("organiserId") UUID organiserId);
}

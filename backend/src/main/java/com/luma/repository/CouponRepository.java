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
}

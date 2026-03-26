package com.luma.repository;

import com.luma.entity.Payout;
import com.luma.entity.enums.PayoutStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PayoutRepository extends JpaRepository<Payout, UUID> {

    Optional<Payout> findByEventId(UUID eventId);

    Page<Payout> findByOrganiserId(UUID organiserId, Pageable pageable);

    Page<Payout> findByOrganiserIdAndStatus(UUID organiserId, PayoutStatus status, Pageable pageable);

    List<Payout> findByStatus(PayoutStatus status);

    @Query("SELECT p FROM Payout p WHERE p.status = :status AND p.event.endTime < :endTime")
    List<Payout> findPendingPayoutsForCompletedEvents(
            @Param("status") PayoutStatus status,
            @Param("endTime") LocalDateTime endTime);

    @Query("SELECT COALESCE(SUM(p.netAmount), 0) FROM Payout p WHERE p.organiser.id = :organiserId AND p.status = 'COMPLETED'")
    BigDecimal calculateTotalPayoutsByOrganiser(@Param("organiserId") UUID organiserId);

    @Query("SELECT COALESCE(SUM(p.netAmount), 0) FROM Payout p WHERE p.organiser.id = :organiserId AND p.status = 'PENDING'")
    BigDecimal calculatePendingPayoutsByOrganiser(@Param("organiserId") UUID organiserId);

    @Query("SELECT COALESCE(SUM(p.platformFee), 0) FROM Payout p WHERE p.status = 'COMPLETED'")
    BigDecimal calculateTotalPlatformFees();

    @Query("SELECT COALESCE(SUM(p.platformFee), 0) FROM Payout p WHERE p.status = 'COMPLETED' " +
           "AND p.completedAt >= :startDate AND p.completedAt < :endDate")
    BigDecimal calculatePlatformFeesBetween(
            @Param("startDate") LocalDateTime startDate,
            @Param("endDate") LocalDateTime endDate);

    @Query("SELECT COUNT(p) FROM Payout p WHERE p.status = :status")
    long countByStatus(@Param("status") PayoutStatus status);

    Page<Payout> findAllByOrderByCreatedAtDesc(Pageable pageable);

    @Query("SELECT p FROM Payout p WHERE p.status IN :statuses ORDER BY p.createdAt DESC")
    Page<Payout> findByStatusIn(@Param("statuses") List<PayoutStatus> statuses, Pageable pageable);

    boolean existsByEventId(UUID eventId);
}

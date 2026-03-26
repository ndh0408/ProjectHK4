package com.luma.repository;

import com.luma.entity.CommissionTransaction;
import com.luma.entity.enums.CommissionStatus;
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
public interface CommissionTransactionRepository extends JpaRepository<CommissionTransaction, UUID> {

    /**
     * Find commission by payment ID
     */
    Optional<CommissionTransaction> findByPaymentId(UUID paymentId);

    /**
     * Find all commissions for an organiser
     */
    Page<CommissionTransaction> findByOrganiserIdOrderByCreatedAtDesc(UUID organiserId, Pageable pageable);

    /**
     * Find all commissions for an event
     */
    List<CommissionTransaction> findByEventIdOrderByCreatedAtDesc(UUID eventId);

    /**
     * Find commissions by status
     */
    Page<CommissionTransaction> findByStatusOrderByCreatedAtDesc(CommissionStatus status, Pageable pageable);

    /**
     * Find pending commissions for an organiser (ready to settle)
     */
    List<CommissionTransaction> findByOrganiserIdAndStatus(UUID organiserId, CommissionStatus status);

    // ==================== Aggregations for Admin Dashboard ====================

    /**
     * Total platform commission earned (all time)
     */
    @Query("SELECT COALESCE(SUM(ct.commissionAmount), 0) FROM CommissionTransaction ct " +
           "WHERE ct.status IN ('CONFIRMED', 'SETTLED')")
    BigDecimal getTotalPlatformCommission();

    /**
     * Total platform commission in date range
     */
    @Query("SELECT COALESCE(SUM(ct.commissionAmount), 0) FROM CommissionTransaction ct " +
           "WHERE ct.status IN ('CONFIRMED', 'SETTLED') " +
           "AND ct.createdAt BETWEEN :startDate AND :endDate")
    BigDecimal getPlatformCommissionInRange(
            @Param("startDate") LocalDateTime startDate,
            @Param("endDate") LocalDateTime endDate);

    /**
     * Total sales amount (all time)
     */
    @Query("SELECT COALESCE(SUM(ct.saleAmount), 0) FROM CommissionTransaction ct " +
           "WHERE ct.status IN ('CONFIRMED', 'SETTLED')")
    BigDecimal getTotalSalesAmount();

    /**
     * Total organiser earnings pending settlement
     */
    @Query("SELECT COALESCE(SUM(ct.organiserEarnings), 0) FROM CommissionTransaction ct " +
           "WHERE ct.status = 'CONFIRMED'")
    BigDecimal getTotalPendingPayouts();

    /**
     * Count transactions by status
     */
    long countByStatus(CommissionStatus status);

    // ==================== Aggregations for Organiser Dashboard ====================

    /**
     * Total earnings for an organiser (all time)
     */
    @Query("SELECT COALESCE(SUM(ct.organiserEarnings), 0) FROM CommissionTransaction ct " +
           "WHERE ct.organiser.id = :organiserId " +
           "AND ct.status IN ('CONFIRMED', 'SETTLED')")
    BigDecimal getTotalOrganiserEarnings(@Param("organiserId") UUID organiserId);

    /**
     * Total commission paid by organiser (all time)
     */
    @Query("SELECT COALESCE(SUM(ct.commissionAmount), 0) FROM CommissionTransaction ct " +
           "WHERE ct.organiser.id = :organiserId " +
           "AND ct.status IN ('CONFIRMED', 'SETTLED')")
    BigDecimal getTotalCommissionPaidByOrganiser(@Param("organiserId") UUID organiserId);

    /**
     * Total sales for an organiser (all time)
     */
    @Query("SELECT COALESCE(SUM(ct.saleAmount), 0) FROM CommissionTransaction ct " +
           "WHERE ct.organiser.id = :organiserId " +
           "AND ct.status IN ('CONFIRMED', 'SETTLED')")
    BigDecimal getTotalOrganiserSales(@Param("organiserId") UUID organiserId);

    /**
     * Pending payout amount for an organiser
     */
    @Query("SELECT COALESCE(SUM(ct.organiserEarnings), 0) FROM CommissionTransaction ct " +
           "WHERE ct.organiser.id = :organiserId " +
           "AND ct.status = 'CONFIRMED'")
    BigDecimal getPendingPayoutForOrganiser(@Param("organiserId") UUID organiserId);

    /**
     * Settled payout amount for an organiser
     */
    @Query("SELECT COALESCE(SUM(ct.organiserEarnings), 0) FROM CommissionTransaction ct " +
           "WHERE ct.organiser.id = :organiserId " +
           "AND ct.status = 'SETTLED'")
    BigDecimal getSettledPayoutForOrganiser(@Param("organiserId") UUID organiserId);

    /**
     * Organiser earnings in date range
     */
    @Query("SELECT COALESCE(SUM(ct.organiserEarnings), 0) FROM CommissionTransaction ct " +
           "WHERE ct.organiser.id = :organiserId " +
           "AND ct.status IN ('CONFIRMED', 'SETTLED') " +
           "AND ct.createdAt BETWEEN :startDate AND :endDate")
    BigDecimal getOrganiserEarningsInRange(
            @Param("organiserId") UUID organiserId,
            @Param("startDate") LocalDateTime startDate,
            @Param("endDate") LocalDateTime endDate);

    /**
     * Count transactions for organiser
     */
    long countByOrganiserId(UUID organiserId);

    /**
     * Count transactions for organiser by status
     */
    long countByOrganiserIdAndStatus(UUID organiserId, CommissionStatus status);

    // ==================== For Event Statistics ====================

    /**
     * Total revenue for an event
     */
    @Query("SELECT COALESCE(SUM(ct.saleAmount), 0) FROM CommissionTransaction ct " +
           "WHERE ct.event.id = :eventId " +
           "AND ct.status IN ('CONFIRMED', 'SETTLED')")
    BigDecimal getTotalEventRevenue(@Param("eventId") UUID eventId);

    /**
     * Total commission for an event
     */
    @Query("SELECT COALESCE(SUM(ct.commissionAmount), 0) FROM CommissionTransaction ct " +
           "WHERE ct.event.id = :eventId " +
           "AND ct.status IN ('CONFIRMED', 'SETTLED')")
    BigDecimal getTotalEventCommission(@Param("eventId") UUID eventId);
}

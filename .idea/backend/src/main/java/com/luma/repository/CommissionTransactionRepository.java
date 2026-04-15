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

    Optional<CommissionTransaction> findByPaymentId(UUID paymentId);

    Page<CommissionTransaction> findByOrganiserIdOrderByCreatedAtDesc(UUID organiserId, Pageable pageable);

    List<CommissionTransaction> findByEventIdOrderByCreatedAtDesc(UUID eventId);

    Page<CommissionTransaction> findByStatusOrderByCreatedAtDesc(CommissionStatus status, Pageable pageable);

    List<CommissionTransaction> findByOrganiserIdAndStatus(UUID organiserId, CommissionStatus status);

    @Query("SELECT COALESCE(SUM(ct.commissionAmount), 0) FROM CommissionTransaction ct " +
           "WHERE ct.status IN ('CONFIRMED', 'SETTLED')")
    BigDecimal getTotalPlatformCommission();

    @Query("SELECT COALESCE(SUM(ct.commissionAmount), 0) FROM CommissionTransaction ct " +
           "WHERE ct.status IN ('CONFIRMED', 'SETTLED') " +
           "AND ct.createdAt BETWEEN :startDate AND :endDate")
    BigDecimal getPlatformCommissionInRange(
            @Param("startDate") LocalDateTime startDate,
            @Param("endDate") LocalDateTime endDate);

    @Query("SELECT COALESCE(SUM(ct.saleAmount), 0) FROM CommissionTransaction ct " +
           "WHERE ct.status IN ('CONFIRMED', 'SETTLED')")
    BigDecimal getTotalSalesAmount();

    @Query("SELECT COALESCE(SUM(ct.organiserEarnings), 0) FROM CommissionTransaction ct " +
           "WHERE ct.status = 'CONFIRMED'")
    BigDecimal getTotalPendingPayouts();

    long countByStatus(CommissionStatus status);

    @Query("SELECT COALESCE(SUM(ct.organiserEarnings), 0) FROM CommissionTransaction ct " +
           "WHERE ct.organiser.id = :organiserId " +
           "AND ct.status IN ('CONFIRMED', 'SETTLED')")
    BigDecimal getTotalOrganiserEarnings(@Param("organiserId") UUID organiserId);

    @Query("SELECT COALESCE(SUM(ct.commissionAmount), 0) FROM CommissionTransaction ct " +
           "WHERE ct.organiser.id = :organiserId " +
           "AND ct.status IN ('CONFIRMED', 'SETTLED')")
    BigDecimal getTotalCommissionPaidByOrganiser(@Param("organiserId") UUID organiserId);

    @Query("SELECT COALESCE(SUM(ct.saleAmount), 0) FROM CommissionTransaction ct " +
           "WHERE ct.organiser.id = :organiserId " +
           "AND ct.status IN ('CONFIRMED', 'SETTLED')")
    BigDecimal getTotalOrganiserSales(@Param("organiserId") UUID organiserId);

    @Query("SELECT COALESCE(SUM(ct.organiserEarnings), 0) FROM CommissionTransaction ct " +
           "WHERE ct.organiser.id = :organiserId " +
           "AND ct.status = 'CONFIRMED'")
    BigDecimal getPendingPayoutForOrganiser(@Param("organiserId") UUID organiserId);

    @Query("SELECT COALESCE(SUM(ct.organiserEarnings), 0) FROM CommissionTransaction ct " +
           "WHERE ct.organiser.id = :organiserId " +
           "AND ct.status = 'SETTLED'")
    BigDecimal getSettledPayoutForOrganiser(@Param("organiserId") UUID organiserId);

    @Query("SELECT COALESCE(SUM(ct.organiserEarnings), 0) FROM CommissionTransaction ct " +
           "WHERE ct.organiser.id = :organiserId " +
           "AND ct.status IN ('CONFIRMED', 'SETTLED') " +
           "AND ct.createdAt BETWEEN :startDate AND :endDate")
    BigDecimal getOrganiserEarningsInRange(
            @Param("organiserId") UUID organiserId,
            @Param("startDate") LocalDateTime startDate,
            @Param("endDate") LocalDateTime endDate);

    long countByOrganiserId(UUID organiserId);

    long countByOrganiserIdAndStatus(UUID organiserId, CommissionStatus status);

    @Query("SELECT COALESCE(SUM(ct.saleAmount), 0) FROM CommissionTransaction ct " +
           "WHERE ct.event.id = :eventId " +
           "AND ct.status IN ('CONFIRMED', 'SETTLED')")
    BigDecimal getTotalEventRevenue(@Param("eventId") UUID eventId);

    @Query("SELECT COALESCE(SUM(ct.commissionAmount), 0) FROM CommissionTransaction ct " +
           "WHERE ct.event.id = :eventId " +
           "AND ct.status IN ('CONFIRMED', 'SETTLED')")
    BigDecimal getTotalEventCommission(@Param("eventId") UUID eventId);
}

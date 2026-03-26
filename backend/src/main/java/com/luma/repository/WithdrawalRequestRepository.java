package com.luma.repository;

import com.luma.entity.WithdrawalRequest;
import com.luma.entity.enums.WithdrawalStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Repository
public interface WithdrawalRequestRepository extends JpaRepository<WithdrawalRequest, UUID> {

    // ==================== Find by Organiser ====================

    Page<WithdrawalRequest> findByOrganiserIdOrderByCreatedAtDesc(UUID organiserId, Pageable pageable);

    Page<WithdrawalRequest> findByOrganiserIdAndStatusOrderByCreatedAtDesc(
            UUID organiserId, WithdrawalStatus status, Pageable pageable);

    List<WithdrawalRequest> findByOrganiserIdAndStatusIn(UUID organiserId, List<WithdrawalStatus> statuses);

    // ==================== Find by Status ====================

    Page<WithdrawalRequest> findByStatusOrderByCreatedAtDesc(WithdrawalStatus status, Pageable pageable);

    Page<WithdrawalRequest> findByStatusInOrderByCreatedAtDesc(List<WithdrawalStatus> statuses, Pageable pageable);

    Page<WithdrawalRequest> findAllByOrderByCreatedAtDesc(Pageable pageable);

    // ==================== Count ====================

    long countByStatus(WithdrawalStatus status);

    long countByOrganiserId(UUID organiserId);

    long countByOrganiserIdAndStatus(UUID organiserId, WithdrawalStatus status);

    // ==================== Aggregations ====================

    /**
     * Total pending withdrawal amount for an organiser
     */
    @Query("SELECT COALESCE(SUM(w.amount), 0) FROM WithdrawalRequest w " +
           "WHERE w.organiser.id = :organiserId " +
           "AND w.status IN ('PENDING', 'APPROVED', 'PROCESSING')")
    BigDecimal getTotalPendingWithdrawalsByOrganiser(@Param("organiserId") UUID organiserId);

    /**
     * Total completed withdrawal amount for an organiser
     */
    @Query("SELECT COALESCE(SUM(w.amount), 0) FROM WithdrawalRequest w " +
           "WHERE w.organiser.id = :organiserId " +
           "AND w.status = 'COMPLETED'")
    BigDecimal getTotalCompletedWithdrawalsByOrganiser(@Param("organiserId") UUID organiserId);

    /**
     * Total pending withdrawal amount (platform-wide)
     */
    @Query("SELECT COALESCE(SUM(w.amount), 0) FROM WithdrawalRequest w " +
           "WHERE w.status IN ('PENDING', 'APPROVED', 'PROCESSING')")
    BigDecimal getTotalPendingWithdrawals();

    /**
     * Total completed withdrawal amount (platform-wide)
     */
    @Query("SELECT COALESCE(SUM(w.amount), 0) FROM WithdrawalRequest w " +
           "WHERE w.status = 'COMPLETED'")
    BigDecimal getTotalCompletedWithdrawals();

    /**
     * Total withdrawals in date range
     */
    @Query("SELECT COALESCE(SUM(w.amount), 0) FROM WithdrawalRequest w " +
           "WHERE w.status = 'COMPLETED' " +
           "AND w.completedAt BETWEEN :startDate AND :endDate")
    BigDecimal getTotalWithdrawalsInRange(
            @Param("startDate") LocalDateTime startDate,
            @Param("endDate") LocalDateTime endDate);

    // ==================== Check existence ====================

    /**
     * Check if organiser has any pending withdrawal
     */
    boolean existsByOrganiserIdAndStatusIn(UUID organiserId, List<WithdrawalStatus> statuses);
}

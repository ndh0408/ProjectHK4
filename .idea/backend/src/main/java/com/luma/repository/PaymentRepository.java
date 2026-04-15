package com.luma.repository;

import com.luma.entity.Payment;
import com.luma.entity.enums.PaymentStatus;
import org.springframework.data.jpa.repository.EntityGraph;
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
public interface PaymentRepository extends JpaRepository<Payment, UUID> {

    @EntityGraph(attributePaths = {"registration", "event", "user"})
    Optional<Payment> findByRegistrationId(UUID registrationId);

    @EntityGraph(attributePaths = {"registration", "event", "user"})
    Optional<Payment> findByStripePaymentIntentId(String stripePaymentIntentId);

    List<Payment> findByUserId(UUID userId);

    List<Payment> findByEventId(UUID eventId);

    List<Payment> findByStatus(PaymentStatus status);

    boolean existsByRegistrationId(UUID registrationId);

    void deleteByRegistrationId(UUID registrationId);

    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM Payment p WHERE p.status = 'SUCCEEDED'")
    BigDecimal calculateTotalRevenue();

    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM Payment p WHERE p.status = 'SUCCEEDED' AND p.createdAt BETWEEN :start AND :end")
    BigDecimal calculateRevenueBetween(@Param("start") LocalDateTime start, @Param("end") LocalDateTime end);

    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM Payment p WHERE p.status = 'SUCCEEDED' AND p.event.organiser.id = :organiserId")
    BigDecimal calculateRevenueByOrganiser(@Param("organiserId") UUID organiserId);

    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM Payment p WHERE p.status = 'SUCCEEDED' AND p.event.organiser.id = :organiserId AND p.createdAt BETWEEN :start AND :end")
    BigDecimal calculateRevenueByOrganiserBetween(@Param("organiserId") UUID organiserId, @Param("start") LocalDateTime start, @Param("end") LocalDateTime end);
}

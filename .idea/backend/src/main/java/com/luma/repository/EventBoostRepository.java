package com.luma.repository;

import com.luma.entity.EventBoost;
import com.luma.entity.enums.BoostStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
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
public interface EventBoostRepository extends JpaRepository<EventBoost, UUID> {

    Page<EventBoost> findByOrganiserId(UUID organiserId, Pageable pageable);

    Page<EventBoost> findByOrganiserIdAndStatus(UUID organiserId, BoostStatus status, Pageable pageable);

    List<EventBoost> findByEventIdAndStatus(UUID eventId, BoostStatus status);

    @Query("SELECT b FROM EventBoost b WHERE b.event.id = :eventId AND b.status = :status ORDER BY b.createdAt DESC")
    List<EventBoost> findByEventIdAndStatusOrderByCreatedAtDesc(@Param("eventId") UUID eventId, @Param("status") BoostStatus status);

    List<EventBoost> findByEventId(UUID eventId);

    @Query("SELECT b FROM EventBoost b WHERE b.status = :status AND b.endTime < :now")
    List<EventBoost> findExpiredBoosts(@Param("status") BoostStatus status, @Param("now") LocalDateTime now);

    @Query("SELECT b FROM EventBoost b WHERE b.status = 'ACTIVE' AND b.startTime <= :now AND b.endTime > :now")
    List<EventBoost> findActiveBoosts(@Param("now") LocalDateTime now);

    @Query("SELECT b.event.id FROM EventBoost b WHERE b.status = 'ACTIVE' AND b.startTime <= :now AND b.endTime > :now ORDER BY b.boostPackage DESC")
    List<UUID> findBoostedEventIds(@Param("now") LocalDateTime now);

    @Query("SELECT b FROM EventBoost b WHERE b.status = 'ACTIVE' AND b.boostPackage IN ('PREMIUM', 'VIP') AND b.startTime <= :now AND b.endTime > :now")
    List<EventBoost> findFeaturedBoosts(@Param("now") LocalDateTime now);

    @Query("SELECT b FROM EventBoost b WHERE b.status = 'ACTIVE' AND b.boostPackage = 'VIP' AND b.startTime <= :now AND b.endTime > :now")
    List<EventBoost> findHomeBannerBoosts(@Param("now") LocalDateTime now);

    @Modifying
    @Query("UPDATE EventBoost b SET b.status = 'EXPIRED' WHERE b.status = 'ACTIVE' AND b.endTime < :now")
    int expireBoosts(@Param("now") LocalDateTime now);

    @Query("SELECT COUNT(b) FROM EventBoost b WHERE b.organiser.id = :organiserId AND b.status = 'ACTIVE'")
    long countActiveBoostsByOrganiser(@Param("organiserId") UUID organiserId);

    @Query("SELECT SUM(b.amount) FROM EventBoost b WHERE b.status IN ('ACTIVE', 'EXPIRED') AND b.paidAt >= :startDate")
    java.math.BigDecimal getTotalRevenue(@Param("startDate") LocalDateTime startDate);

    @Query("SELECT CASE WHEN COUNT(b) > 0 THEN true ELSE false END FROM EventBoost b WHERE b.event.id = :eventId AND b.status = 'ACTIVE' AND b.startTime <= :now AND b.endTime > :now")
    boolean hasActiveBoost(@Param("eventId") UUID eventId, @Param("now") LocalDateTime now);

    @Query("SELECT b FROM EventBoost b WHERE b.event.id IN :eventIds AND b.status = 'ACTIVE' AND b.startTime <= :now AND b.endTime > :now")
    List<EventBoost> findActiveBoostsByEventIds(@Param("eventIds") List<UUID> eventIds, @Param("now") LocalDateTime now);

    Page<EventBoost> findByStatus(BoostStatus status, Pageable pageable);

    @Query("SELECT b FROM EventBoost b WHERE b.paidAt IS NOT NULL AND b.amount IS NOT NULL")
    List<EventBoost> findAllPaidBoosts();

    @Query("SELECT COALESCE(SUM(b.amount), 0) FROM EventBoost b WHERE b.paidAt IS NOT NULL AND b.amount IS NOT NULL")
    java.math.BigDecimal sumAllPaidBoostRevenue();

    @Query("SELECT COALESCE(SUM(b.amount), 0) FROM EventBoost b WHERE b.paidAt IS NOT NULL AND b.amount IS NOT NULL AND b.paidAt >= :start")
    java.math.BigDecimal sumPaidBoostRevenueAfter(@Param("start") LocalDateTime start);

    @Query("SELECT COALESCE(SUM(b.amount), 0) FROM EventBoost b WHERE b.paidAt IS NOT NULL AND b.amount IS NOT NULL AND b.paidAt >= :start AND b.paidAt < :end")
    java.math.BigDecimal sumPaidBoostRevenueBetween(@Param("start") LocalDateTime start, @Param("end") LocalDateTime end);

    @Query("SELECT COUNT(b) FROM EventBoost b WHERE b.paidAt IS NOT NULL AND b.amount IS NOT NULL")
    int countAllPaidBoosts();

    @Query("SELECT COUNT(b) FROM EventBoost b WHERE b.status = 'ACTIVE' AND b.startTime <= :now AND b.endTime > :now")
    int countActiveBoostsNow(@Param("now") LocalDateTime now);

    @Query("SELECT b.boostPackage, COUNT(b), COALESCE(SUM(b.amount), 0) FROM EventBoost b WHERE b.paidAt IS NOT NULL AND b.amount IS NOT NULL GROUP BY b.boostPackage")
    List<Object[]> sumRevenueGroupedByPackage();

    @Query("SELECT b FROM EventBoost b WHERE b.paidAt IS NOT NULL AND b.amount IS NOT NULL AND b.paidAt >= :start AND b.paidAt < :end")
    List<EventBoost> findPaidBoostsBetween(@Param("start") LocalDateTime start, @Param("end") LocalDateTime end);
}

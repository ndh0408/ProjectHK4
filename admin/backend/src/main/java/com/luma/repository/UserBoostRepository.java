package com.luma.repository;

import com.luma.entity.UserBoost;
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
import java.util.UUID;

@Repository
public interface UserBoostRepository extends JpaRepository<UserBoost, UUID> {

    List<UserBoost> findByEventIdAndStatus(UUID eventId, BoostStatus status);

    Page<UserBoost> findByUserId(UUID userId, Pageable pageable);

    Page<UserBoost> findByUserIdAndStatus(UUID userId, BoostStatus status, Pageable pageable);

    @Query("SELECT ub FROM UserBoost ub WHERE ub.event.id = :eventId AND ub.status = 'ACTIVE' " +
            "AND ub.startTime <= :now AND ub.endTime > :now")
    List<UserBoost> findActiveBoostsByEventId(@Param("eventId") UUID eventId, @Param("now") LocalDateTime now);

    @Query("SELECT CASE WHEN COUNT(ub) > 0 THEN true ELSE false END FROM UserBoost ub " +
            "WHERE ub.event.id = :eventId AND ub.status = 'ACTIVE' " +
            "AND ub.startTime <= :now AND ub.endTime > :now")
    boolean hasActiveBoost(@Param("eventId") UUID eventId, @Param("now") LocalDateTime now);

    @Query("SELECT ub.event.id FROM UserBoost ub WHERE ub.status = 'ACTIVE' " +
            "AND ub.startTime <= :now AND ub.endTime > :now")
    List<UUID> findBoostedEventIds(@Param("now") LocalDateTime now);

    @Modifying
    @Query("UPDATE UserBoost ub SET ub.status = 'EXPIRED' " +
            "WHERE ub.status = 'ACTIVE' AND ub.endTime < :now")
    int expireBoosts(@Param("now") LocalDateTime now);

    @Query("SELECT COUNT(ub) FROM UserBoost ub WHERE ub.user.id = :userId AND ub.status = 'ACTIVE'")
    long countActiveBoostsByUserId(@Param("userId") UUID userId);
}

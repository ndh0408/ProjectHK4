package com.luma.repository;

import com.luma.entity.Seat;
import com.luma.entity.SeatZone;
import com.luma.entity.enums.SeatStatus;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface SeatRepository extends JpaRepository<Seat, UUID> {

    List<Seat> findByZoneOrderByRowAscNumberAsc(SeatZone zone);

    @Query("SELECT s FROM Seat s JOIN s.zone z WHERE z.event.id = :eventId ORDER BY z.displayOrder, s.row, s.number")
    List<Seat> findByEventId(@Param("eventId") UUID eventId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT s FROM Seat s WHERE s.id = :id")
    Optional<Seat> findByIdWithLock(@Param("id") UUID id);

    @Modifying
    @Transactional
    @Query("UPDATE Seat s SET s.status = 'AVAILABLE', s.reservedBy = null, s.lockedUntil = null " +
           "WHERE s.status = 'LOCKED' AND s.lockedUntil < :now")
    int releaseExpiredLocks(@Param("now") LocalDateTime now);

    long countByZoneAndStatus(SeatZone zone, SeatStatus status);
}

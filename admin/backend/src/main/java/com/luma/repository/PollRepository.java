package com.luma.repository;

import com.luma.entity.Event;
import com.luma.entity.Poll;
import com.luma.entity.enums.PollStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Repository
public interface PollRepository extends JpaRepository<Poll, UUID> {

    List<Poll> findByEventOrderByCreatedAtDesc(Event event);

    @Query("SELECT DISTINCT p FROM Poll p LEFT JOIN FETCH p.event LEFT JOIN FETCH p.createdBy LEFT JOIN FETCH p.options WHERE p.event.id = :eventId ORDER BY p.createdAt DESC")
    List<Poll> findByEventIdOrderByCreatedAtDesc(@Param("eventId") UUID eventId);

    List<Poll> findByEventAndStatusOrderByCreatedAtDesc(Event event, PollStatus status);

    @Query("SELECT DISTINCT p FROM Poll p LEFT JOIN FETCH p.options WHERE p.event = :event AND p.status = 'ACTIVE' " +
           "AND (p.closesAt IS NULL OR p.closesAt > :now) ORDER BY p.createdAt DESC")
    List<Poll> findActiveByEvent(@Param("event") Event event, @Param("now") LocalDateTime now);

    @Query("SELECT DISTINCT p FROM Poll p LEFT JOIN FETCH p.options WHERE p.status = 'ACTIVE' AND p.closesAt IS NOT NULL AND p.closesAt < :now")
    List<Poll> findExpiredActivePolls(@Param("now") LocalDateTime now);

    /**
     * Tìm các poll SCHEDULED đã đến giờ mở
     */
    @Query("SELECT DISTINCT p FROM Poll p LEFT JOIN FETCH p.options WHERE p.status = 'SCHEDULED' " +
           "AND p.scheduledOpenAt IS NOT NULL AND p.scheduledOpenAt <= :now")
    List<Poll> findReadyToOpenPolls(@Param("now") LocalDateTime now);

    /**
     * Tìm các poll ACTIVE có event đã kết thúc và autoCloseEventEnd = true
     */
    @Query("SELECT DISTINCT p FROM Poll p LEFT JOIN FETCH p.options WHERE p.status = 'ACTIVE' " +
           "AND p.autoCloseEventEnd = true " +
           "AND p.event.endTime IS NOT NULL AND p.event.endTime <= :now")
    List<Poll> findActivePollsByEventEndTime(@Param("now") LocalDateTime now);

    /**
     * Tìm các poll ACTIVE có autoCloseTenDaysAfterEventEnd = true và đã quá 10 ngày sau khi event kết thúc
     */
    @Query("SELECT DISTINCT p FROM Poll p LEFT JOIN FETCH p.options WHERE p.status = 'ACTIVE' " +
           "AND p.autoCloseTenDaysAfterEventEnd = true " +
           "AND p.event.endTime IS NOT NULL AND p.event.endTime <= :tenDaysAgo")
    List<Poll> findActivePollsTenDaysAfterEventEnd(@Param("tenDaysAgo") LocalDateTime tenDaysAgo);

    /**
     * Tìm các poll SCHEDULED có event đã bắt đầu và autoOpenEventStart = true
     */
    @Query("SELECT DISTINCT p FROM Poll p LEFT JOIN FETCH p.options WHERE p.status = 'SCHEDULED' " +
           "AND p.autoOpenEventStart = true " +
           "AND p.event.startTime IS NOT NULL AND p.event.startTime <= :now")
    List<Poll> findScheduledPollsByEventStartTime(@Param("now") LocalDateTime now);

    /**
     * Tìm các poll ACTIVE có closeAtVoteCount được thiết lập
     */
    @Query("SELECT DISTINCT p FROM Poll p LEFT JOIN FETCH p.options WHERE p.status = 'ACTIVE' AND p.closeAtVoteCount IS NOT NULL")
    List<Poll> findActivePollsWithVoteLimit();

    long countByEventAndStatus(Event event, PollStatus status);

    /**
     * Load poll với options (cho vote và các operations cần options)
     */
    @Query("SELECT DISTINCT p FROM Poll p LEFT JOIN FETCH p.options WHERE p.id = :pollId")
    java.util.Optional<Poll> findByIdWithOptions(@Param("pollId") UUID pollId);
}

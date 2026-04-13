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

    List<Poll> findByEventAndStatusOrderByCreatedAtDesc(Event event, PollStatus status);

    @Query("SELECT p FROM Poll p WHERE p.event = :event AND p.status = 'ACTIVE' " +
           "AND (p.closesAt IS NULL OR p.closesAt > :now) ORDER BY p.createdAt DESC")
    List<Poll> findActiveByEvent(@Param("event") Event event, @Param("now") LocalDateTime now);

    @Query("SELECT p FROM Poll p WHERE p.status = 'ACTIVE' AND p.closesAt IS NOT NULL AND p.closesAt < :now")
    List<Poll> findExpiredActivePolls(@Param("now") LocalDateTime now);

    long countByEventAndStatus(Event event, PollStatus status);
}

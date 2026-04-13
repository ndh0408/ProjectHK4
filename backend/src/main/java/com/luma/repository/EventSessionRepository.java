package com.luma.repository;

import com.luma.entity.Event;
import com.luma.entity.EventSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Repository
public interface EventSessionRepository extends JpaRepository<EventSession, UUID> {

    List<EventSession> findByEventOrderByStartTimeAscDisplayOrderAsc(Event event);

    @Query("SELECT s FROM EventSession s WHERE s.event = :event AND s.track = :track ORDER BY s.startTime ASC")
    List<EventSession> findByEventAndTrack(@Param("event") Event event, @Param("track") String track);

    @Query("SELECT DISTINCT s.track FROM EventSession s WHERE s.event = :event AND s.track IS NOT NULL")
    List<String> findDistinctTracksByEvent(@Param("event") Event event);

    @Query("SELECT DISTINCT s.room FROM EventSession s WHERE s.event = :event AND s.room IS NOT NULL")
    List<String> findDistinctRoomsByEvent(@Param("event") Event event);

    @Query("SELECT s FROM EventSession s WHERE s.event = :event AND s.speaker.id = :speakerId " +
           "AND ((s.startTime < :endTime AND s.endTime > :startTime))")
    List<EventSession> findConflictingSpeakerSessions(
            @Param("event") Event event,
            @Param("speakerId") Long speakerId,
            @Param("startTime") LocalDateTime startTime,
            @Param("endTime") LocalDateTime endTime);

    @Query("SELECT s FROM EventSession s WHERE s.event = :event AND s.room = :room " +
           "AND ((s.startTime < :endTime AND s.endTime > :startTime)) AND s.id != :excludeId")
    List<EventSession> findConflictingRoomSessions(
            @Param("event") Event event,
            @Param("room") String room,
            @Param("startTime") LocalDateTime startTime,
            @Param("endTime") LocalDateTime endTime,
            @Param("excludeId") UUID excludeId);
}

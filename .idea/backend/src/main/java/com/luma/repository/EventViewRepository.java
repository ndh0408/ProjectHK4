package com.luma.repository;

import com.luma.entity.Event;
import com.luma.entity.EventView;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.UUID;

@Repository
public interface EventViewRepository extends JpaRepository<EventView, UUID> {

    long countByEvent(Event event);

    @Query("SELECT COUNT(DISTINCT ev.user.id) FROM EventView ev WHERE ev.event = :event AND ev.user IS NOT NULL")
    long countUniqueUserViewsByEvent(@Param("event") Event event);

    long countByEventAndCreatedAtAfter(Event event, LocalDateTime after);

    @Query("SELECT COUNT(ev) FROM EventView ev WHERE ev.event.organiser.id = :organiserId")
    long countByOrganiser(@Param("organiserId") UUID organiserId);

    @Query("SELECT COUNT(ev) FROM EventView ev WHERE ev.event.organiser.id = :organiserId AND ev.createdAt >= :after")
    long countByOrganiserAndCreatedAtAfter(@Param("organiserId") UUID organiserId, @Param("after") LocalDateTime after);

    @Query("SELECT COUNT(ev) FROM EventView ev WHERE ev.createdAt >= :after")
    long countAllAfter(@Param("after") LocalDateTime after);

    long count();
}

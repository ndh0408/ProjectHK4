package com.luma.repository;

import com.luma.entity.EventSession;
import com.luma.entity.SessionRegistration;
import com.luma.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface SessionRegistrationRepository extends JpaRepository<SessionRegistration, UUID> {

    boolean existsBySessionAndUser(EventSession session, User user);

    @Query("SELECT sr FROM SessionRegistration sr JOIN FETCH sr.session " +
           "WHERE sr.user = :user AND sr.session.event.id = :eventId ORDER BY sr.session.startTime")
    List<SessionRegistration> findByUserAndEventId(@Param("user") User user, @Param("eventId") UUID eventId);

    long countBySession(EventSession session);
}

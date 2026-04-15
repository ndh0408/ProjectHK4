package com.luma.repository;

import com.luma.entity.CalendarSync;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CalendarSyncRepository extends JpaRepository<CalendarSync, UUID> {

    Optional<CalendarSync> findByUserIdAndRegistrationId(UUID userId, UUID registrationId);

    List<CalendarSync> findByUserId(UUID userId);

    List<CalendarSync> findByUserIdAndIsSyncedTrue(UUID userId);

    boolean existsByUserIdAndRegistrationId(UUID userId, UUID registrationId);

    @Modifying
    @Query("DELETE FROM CalendarSync c WHERE c.user.id = :userId AND c.registration.id = :registrationId")
    void deleteByUserIdAndRegistrationId(@Param("userId") UUID userId, @Param("registrationId") UUID registrationId);

    @Modifying
    @Query("DELETE FROM CalendarSync c WHERE c.user.id = :userId")
    void deleteAllByUserId(@Param("userId") UUID userId);

    @Query("SELECT c FROM CalendarSync c WHERE c.registration.event.id = :eventId")
    List<CalendarSync> findByEventId(@Param("eventId") UUID eventId);
}

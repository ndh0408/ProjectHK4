package com.luma.repository;

import com.luma.entity.GoogleCalendarToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface GoogleCalendarTokenRepository extends JpaRepository<GoogleCalendarToken, UUID> {

    Optional<GoogleCalendarToken> findByUserId(UUID userId);

    Optional<GoogleCalendarToken> findByUserIdAndIsActiveTrue(UUID userId);

    boolean existsByUserIdAndIsActiveTrue(UUID userId);

    @Modifying
    @Query("UPDATE GoogleCalendarToken g SET g.isActive = false WHERE g.user.id = :userId")
    void deactivateByUserId(@Param("userId") UUID userId);

    @Modifying
    @Query("DELETE FROM GoogleCalendarToken g WHERE g.user.id = :userId")
    void deleteByUserId(@Param("userId") UUID userId);
}

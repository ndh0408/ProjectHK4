package com.luma.repository;

import com.luma.entity.UserEventLimit;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserEventLimitRepository extends JpaRepository<UserEventLimit, UUID> {

    Optional<UserEventLimit> findByUserId(UUID userId);

    @Query("SELECT CASE WHEN COUNT(uel) > 0 THEN true ELSE false END FROM UserEventLimit uel WHERE uel.user.id = :userId")
    boolean existsByUserId(@Param("userId") UUID userId);

    @Query("SELECT uel.freeEventsUsedThisMonth FROM UserEventLimit uel WHERE uel.user.id = :userId")
    Optional<Integer> getFreeEventsUsedThisMonth(@Param("userId") UUID userId);

    @Query("SELECT uel.extraEventsPurchasedThisMonth - uel.extraEventsUsedThisMonth FROM UserEventLimit uel WHERE uel.user.id = :userId")
    Optional<Integer> getRemainingExtraEvents(@Param("userId") UUID userId);
}

package com.luma.repository;

import com.luma.entity.ActivityLog;
import com.luma.entity.User;
import com.luma.entity.enums.ActivityType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Repository
public interface ActivityLogRepository extends JpaRepository<ActivityLog, UUID> {

    Page<ActivityLog> findByUserOrderByCreatedAtDesc(User user, Pageable pageable);

    Page<ActivityLog> findByUserAndActivityTypeOrderByCreatedAtDesc(User user, ActivityType activityType, Pageable pageable);

    @Query("SELECT a FROM ActivityLog a WHERE a.user.id = :userId ORDER BY a.createdAt DESC")
    Page<ActivityLog> findByUserId(@Param("userId") UUID userId, Pageable pageable);

    @Query("SELECT a FROM ActivityLog a WHERE a.createdAt BETWEEN :startDate AND :endDate ORDER BY a.createdAt DESC")
    Page<ActivityLog> findByDateRange(@Param("startDate") LocalDateTime startDate, 
                                       @Param("endDate") LocalDateTime endDate, 
                                       Pageable pageable);

    long countByActivityTypeAndCreatedAtBetween(ActivityType activityType, LocalDateTime startDate, LocalDateTime endDate);
}

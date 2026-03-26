package com.luma.service;

import com.luma.dto.response.ActivityLogResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.ActivityLog;
import com.luma.entity.User;
import com.luma.entity.enums.ActivityType;
import com.luma.repository.ActivityLogRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class ActivityLogService {

    private final ActivityLogRepository activityLogRepository;

    @Transactional
    public void logActivity(User user, ActivityType activityType, String description, 
                           String ipAddress, String userAgent, String entityType, String entityId) {
        ActivityLog log = ActivityLog.builder()
                .user(user)
                .activityType(activityType)
                .description(description)
                .ipAddress(ipAddress)
                .userAgent(userAgent)
                .entityType(entityType)
                .entityId(entityId)
                .build();
        activityLogRepository.save(log);
    }

    @Transactional
    public void logActivity(User user, ActivityType activityType, String description) {
        logActivity(user, activityType, description, null, null, null, null);
    }

    public PageResponse<ActivityLogResponse> getActivityLogsByUser(UUID userId, Pageable pageable) {
        Page<ActivityLog> logs = activityLogRepository.findByUserId(userId, pageable);
        return PageResponse.from(logs, ActivityLogResponse::fromEntity);
    }

    public PageResponse<ActivityLogResponse> getActivityLogsByDateRange(LocalDateTime startDate, 
                                                                         LocalDateTime endDate, 
                                                                         Pageable pageable) {
        Page<ActivityLog> logs = activityLogRepository.findByDateRange(startDate, endDate, pageable);
        return PageResponse.from(logs, ActivityLogResponse::fromEntity);
    }

    public long countLoginsByDateRange(LocalDateTime startDate, LocalDateTime endDate) {
        return activityLogRepository.countByActivityTypeAndCreatedAtBetween(ActivityType.LOGIN, startDate, endDate);
    }
}

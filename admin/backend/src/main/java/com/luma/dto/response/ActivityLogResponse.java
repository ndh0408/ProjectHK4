package com.luma.dto.response;

import com.luma.entity.ActivityLog;
import com.luma.entity.enums.ActivityType;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
public class ActivityLogResponse {
    private UUID id;
    private UUID userId;
    private String userName;
    private String userEmail;
    private ActivityType activityType;
    private String description;
    private String ipAddress;
    private String entityType;
    private String entityId;
    private LocalDateTime createdAt;

    public static ActivityLogResponse fromEntity(ActivityLog log) {
        return ActivityLogResponse.builder()
                .id(log.getId())
                .userId(log.getUser().getId())
                .userName(log.getUser().getFullName())
                .userEmail(log.getUser().getEmail())
                .activityType(log.getActivityType())
                .description(log.getDescription())
                .ipAddress(log.getIpAddress())
                .entityType(log.getEntityType())
                .entityId(log.getEntityId())
                .createdAt(log.getCreatedAt())
                .build();
    }
}

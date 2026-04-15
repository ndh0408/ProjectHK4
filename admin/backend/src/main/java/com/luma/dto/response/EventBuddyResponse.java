package com.luma.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EventBuddyResponse {

    private UUID userId;
    private String fullName;
    private String avatarUrl;
    private int sharedEventsCount;
    private List<SharedEventInfo> sharedEvents;
    private LocalDateTime lastEventDate;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SharedEventInfo {
        private UUID eventId;
        private String eventTitle;
        private LocalDateTime eventDate;
        private String eventImageUrl;
    }
}

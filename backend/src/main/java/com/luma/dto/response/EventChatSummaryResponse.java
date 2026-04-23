package com.luma.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EventChatSummaryResponse {

    private UUID eventId;
    private String eventTitle;
    private String eventImageUrl;
    private LocalDateTime eventStartTime;
    private LocalDateTime eventEndTime;
    private String venue;

    private UUID conversationId;
    private boolean joined;
    private boolean canModerate;
    private boolean closed;
    private LocalDateTime closedAt;
    private int participantCount;

    private String lastMessageContent;
    private LocalDateTime lastMessageAt;
    private int unreadCount;
}

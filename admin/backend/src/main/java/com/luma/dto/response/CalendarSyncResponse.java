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
public class CalendarSyncResponse {

    private UUID id;
    private UUID registrationId;
    private UUID eventId;
    private String eventTitle;
    private LocalDateTime eventStartTime;
    private LocalDateTime eventEndTime;
    private String googleEventId;
    private String calendarId;
    private boolean isSynced;
    private LocalDateTime lastSyncedAt;
}

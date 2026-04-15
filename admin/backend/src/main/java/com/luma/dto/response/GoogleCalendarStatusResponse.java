package com.luma.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GoogleCalendarStatusResponse {

    private boolean connected;
    private String email;
    private LocalDateTime connectedAt;
    private LocalDateTime expiresAt;
    private int syncedEventsCount;
}

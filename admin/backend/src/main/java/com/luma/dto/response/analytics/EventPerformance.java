package com.luma.dto.response.analytics;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EventPerformance {

    private UUID eventId;
    private String eventTitle;
    private LocalDateTime startTime;
    private String status;
    private int capacity;
    private int registrations;
    private int checkedIn;
    private double fillRate;
    private BigDecimal revenue;
    private double averageRating;
}

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
public class TopEvent {
    private UUID id;
    private String title;
    private String organiserName;
    private String imageUrl;
    private LocalDateTime startTime;
    private long registrationCount;
    private BigDecimal revenue;
    private double fillRate; // percentage of capacity filled
}

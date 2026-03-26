package com.luma.dto.response.analytics;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TopOrganiser {
    private UUID id;
    private String name;
    private String email;
    private String avatarUrl;
    private long totalEvents;
    private long totalRegistrations;
    private BigDecimal totalRevenue;
    private double averageRating;
}

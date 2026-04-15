package com.luma.dto.response;

import com.luma.service.CommissionService.EventRevenueStats;
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
public class EventRevenueResponse {

    private UUID eventId;
    private String eventTitle;
    private BigDecimal totalRevenue;
    private BigDecimal totalCommission;
    private BigDecimal netRevenue;

    public static EventRevenueResponse fromStats(EventRevenueStats stats, UUID eventId, String eventTitle) {
        return EventRevenueResponse.builder()
                .eventId(eventId)
                .eventTitle(eventTitle)
                .totalRevenue(stats.totalRevenue())
                .totalCommission(stats.totalCommission())
                .netRevenue(stats.netRevenue())
                .build();
    }
}

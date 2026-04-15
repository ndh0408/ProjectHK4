package com.luma.dto.response;

import com.luma.entity.TicketType;
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
public class TicketTypeResponse {

    private UUID id;
    private UUID eventId;
    private String name;
    private String description;
    private BigDecimal price;
    private String currency;
    private Integer quantity;
    private Integer soldCount;
    private Integer availableQuantity;
    private Integer maxPerOrder;
    private LocalDateTime saleStartDate;
    private LocalDateTime saleEndDate;
    private Boolean isVisible;
    private Integer displayOrder;
    private String status;
    private Boolean isFree;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public static TicketTypeResponse fromEntity(TicketType ticketType) {
        return TicketTypeResponse.builder()
                .id(ticketType.getId())
                .eventId(ticketType.getEvent().getId())
                .name(ticketType.getName())
                .description(ticketType.getDescription())
                .price(ticketType.getPrice())
                .currency("USD")
                .quantity(ticketType.getQuantity())
                .soldCount(ticketType.getSoldCount())
                .availableQuantity(ticketType.getAvailableQuantity())
                .maxPerOrder(ticketType.getMaxPerOrder())
                .saleStartDate(ticketType.getSaleStartDate())
                .saleEndDate(ticketType.getSaleEndDate())
                .isVisible(ticketType.getIsVisible())
                .displayOrder(ticketType.getDisplayOrder())
                .status(ticketType.getStatus())
                .isFree(ticketType.isFree())
                .createdAt(ticketType.getCreatedAt())
                .updatedAt(ticketType.getUpdatedAt())
                .build();
    }
}

package com.luma.dto.request;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
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
public class OrganiserCommissionRequest {

    @NotNull(message = "Organiser ID is required")
    private UUID organiserId;

    @NotNull(message = "Commission rate is required")
    @DecimalMin(value = "0.00", message = "Commission rate must be at least 0%")
    @DecimalMax(value = "100.00", message = "Commission rate cannot exceed 100%")
    private BigDecimal commissionRate;

    private String reason;

    private LocalDateTime effectiveFrom;

    private LocalDateTime effectiveUntil;
}

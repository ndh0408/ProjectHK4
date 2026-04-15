package com.luma.dto.response;

import com.luma.entity.PlatformConfig;
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
public class PlatformConfigResponse {

    private UUID id;
    private BigDecimal defaultCommissionRate;
    private BigDecimal minCommissionRate;
    private BigDecimal maxCommissionRate;
    private String currency;
    private BigDecimal minPayoutAmount;
    private BigDecimal payoutProcessingFee;
    private Boolean acceptingEvents;
    private Boolean acceptingOrganisers;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private UUID updatedBy;

    public static PlatformConfigResponse fromEntity(PlatformConfig config) {
        return PlatformConfigResponse.builder()
                .id(config.getId())
                .defaultCommissionRate(config.getDefaultCommissionRate())
                .minCommissionRate(config.getMinCommissionRate())
                .maxCommissionRate(config.getMaxCommissionRate())
                .currency(config.getCurrency())
                .minPayoutAmount(config.getMinPayoutAmount())
                .payoutProcessingFee(config.getPayoutProcessingFee())
                .acceptingEvents(config.getAcceptingEvents())
                .acceptingOrganisers(config.getAcceptingOrganisers())
                .createdAt(config.getCreatedAt())
                .updatedAt(config.getUpdatedAt())
                .updatedBy(config.getUpdatedBy())
                .build();
    }
}

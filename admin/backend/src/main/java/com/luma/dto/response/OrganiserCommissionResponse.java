package com.luma.dto.response;

import com.luma.entity.OrganiserCommission;
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
public class OrganiserCommissionResponse {

    private UUID id;
    private UUID organiserId;
    private String organiserName;
    private String organiserEmail;
    private BigDecimal commissionRate;
    private String reason;
    private LocalDateTime effectiveFrom;
    private LocalDateTime effectiveUntil;
    private Boolean isActive;
    private Boolean isCurrentlyValid;
    private UUID setByAdminId;
    private String setByAdminName;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public static OrganiserCommissionResponse fromEntity(OrganiserCommission commission) {
        OrganiserCommissionResponseBuilder builder = OrganiserCommissionResponse.builder()
                .id(commission.getId())
                .commissionRate(commission.getCommissionRate())
                .reason(commission.getReason())
                .effectiveFrom(commission.getEffectiveFrom())
                .effectiveUntil(commission.getEffectiveUntil())
                .isActive(commission.getIsActive())
                .isCurrentlyValid(commission.isCurrentlyValid())
                .createdAt(commission.getCreatedAt())
                .updatedAt(commission.getUpdatedAt());

        if (commission.getOrganiser() != null) {
            builder.organiserId(commission.getOrganiser().getId())
                    .organiserName(commission.getOrganiser().getFullName())
                    .organiserEmail(commission.getOrganiser().getEmail());
        }

        if (commission.getSetByAdmin() != null) {
            builder.setByAdminId(commission.getSetByAdmin().getId())
                    .setByAdminName(commission.getSetByAdmin().getFullName());
        }

        return builder.build();
    }
}

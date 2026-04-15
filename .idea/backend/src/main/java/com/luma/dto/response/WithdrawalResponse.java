package com.luma.dto.response;

import com.luma.entity.WithdrawalRequest;
import com.luma.entity.enums.WithdrawalStatus;
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
public class WithdrawalResponse {

    private UUID id;
    private UUID organiserId;
    private String organiserName;
    private String organiserEmail;
    private BigDecimal amount;
    private BigDecimal availableBalance;
    private String currency;
    private WithdrawalStatus status;
    private String organiserNote;
    private String adminNote;
    private UUID processedById;
    private String processedByName;
    private LocalDateTime processedAt;
    private LocalDateTime completedAt;
    private String stripeTransferId;
    private String failureReason;
    private String bankAccountLastFour;
    private String bankName;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public static WithdrawalResponse fromEntity(WithdrawalRequest entity) {
        if (entity == null) return null;

        WithdrawalResponseBuilder builder = WithdrawalResponse.builder()
                .id(entity.getId())
                .amount(entity.getAmount())
                .availableBalance(entity.getAvailableBalance())
                .currency(entity.getCurrency())
                .status(entity.getStatus())
                .organiserNote(entity.getOrganiserNote())
                .adminNote(entity.getAdminNote())
                .processedAt(entity.getProcessedAt())
                .completedAt(entity.getCompletedAt())
                .stripeTransferId(entity.getStripeTransferId())
                .failureReason(entity.getFailureReason())
                .bankAccountLastFour(entity.getBankAccountLastFour())
                .bankName(entity.getBankName())
                .createdAt(entity.getCreatedAt())
                .updatedAt(entity.getUpdatedAt());

        if (entity.getOrganiser() != null) {
            builder.organiserId(entity.getOrganiser().getId())
                   .organiserName(entity.getOrganiser().getFullName())
                   .organiserEmail(entity.getOrganiser().getEmail());
        }

        if (entity.getProcessedBy() != null) {
            builder.processedById(entity.getProcessedBy().getId())
                   .processedByName(entity.getProcessedBy().getFullName());
        }

        return builder.build();
    }
}

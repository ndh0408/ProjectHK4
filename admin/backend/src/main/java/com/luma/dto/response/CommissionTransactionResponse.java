package com.luma.dto.response;

import com.luma.entity.CommissionTransaction;
import com.luma.entity.enums.CommissionStatus;
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
public class CommissionTransactionResponse {

    private UUID id;
    private UUID paymentId;
    private UUID eventId;
    private String eventTitle;
    private UUID organiserId;
    private String organiserName;
    private BigDecimal saleAmount;
    private BigDecimal commissionRate;
    private BigDecimal commissionAmount;
    private BigDecimal organiserEarnings;
    private String currency;
    private CommissionStatus status;
    private LocalDateTime settledAt;
    private String payoutReference;
    private String notes;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public static CommissionTransactionResponse fromEntity(CommissionTransaction transaction) {
        CommissionTransactionResponseBuilder builder = CommissionTransactionResponse.builder()
                .id(transaction.getId())
                .saleAmount(transaction.getSaleAmount())
                .commissionRate(transaction.getCommissionRate())
                .commissionAmount(transaction.getCommissionAmount())
                .organiserEarnings(transaction.getOrganiserEarnings())
                .currency(transaction.getCurrency())
                .status(transaction.getStatus())
                .settledAt(transaction.getSettledAt())
                .payoutReference(transaction.getPayoutReference())
                .notes(transaction.getNotes())
                .createdAt(transaction.getCreatedAt())
                .updatedAt(transaction.getUpdatedAt());

        if (transaction.getPayment() != null) {
            builder.paymentId(transaction.getPayment().getId());
        }

        if (transaction.getEvent() != null) {
            builder.eventId(transaction.getEvent().getId())
                    .eventTitle(transaction.getEvent().getTitle());
        }

        if (transaction.getOrganiser() != null) {
            builder.organiserId(transaction.getOrganiser().getId())
                    .organiserName(transaction.getOrganiser().getFullName());
        }

        return builder.build();
    }
}

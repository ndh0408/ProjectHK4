package com.luma.dto.response;

import com.luma.entity.Payout;
import com.luma.entity.enums.PayoutStatus;
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
public class PayoutResponse {

    private UUID id;
    private UUID organiserId;
    private String organiserName;
    private String organiserEmail;
    private UUID eventId;
    private String eventTitle;
    private LocalDateTime eventEndTime;
    private BigDecimal grossAmount;
    private BigDecimal platformFee;
    private BigDecimal stripeFee;
    private BigDecimal netAmount;
    private BigDecimal platformFeePercent;
    private PayoutStatus status;
    private String stripeTransferId;
    private Integer ticketsSold;
    private Integer refundedTickets;
    private LocalDateTime processedAt;
    private LocalDateTime completedAt;
    private String failureReason;
    private LocalDateTime createdAt;

    public static PayoutResponse fromEntity(Payout payout) {
        return PayoutResponse.builder()
                .id(payout.getId())
                .organiserId(payout.getOrganiser().getId())
                .organiserName(payout.getOrganiser().getFullName())
                .organiserEmail(payout.getOrganiser().getEmail())
                .eventId(payout.getEvent().getId())
                .eventTitle(payout.getEvent().getTitle())
                .eventEndTime(payout.getEvent().getEndTime())
                .grossAmount(payout.getGrossAmount())
                .platformFee(payout.getPlatformFee())
                .stripeFee(payout.getStripeFee())
                .netAmount(payout.getNetAmount())
                .platformFeePercent(payout.getPlatformFeePercent())
                .status(payout.getStatus())
                .stripeTransferId(payout.getStripeTransferId())
                .ticketsSold(payout.getTicketsSold())
                .refundedTickets(payout.getRefundedTickets())
                .processedAt(payout.getProcessedAt())
                .completedAt(payout.getCompletedAt())
                .failureReason(payout.getFailureReason())
                .createdAt(payout.getCreatedAt())
                .build();
    }
}

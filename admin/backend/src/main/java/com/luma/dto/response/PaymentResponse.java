package com.luma.dto.response;

import com.luma.entity.Payment;
import com.luma.entity.enums.PaymentStatus;
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
public class PaymentResponse {
    private UUID id;
    private UUID registrationId;
    private UUID eventId;
    private String eventTitle;
    private BigDecimal amount;
    private String currency;
    private PaymentStatus status;
    private String paymentMethod;
    private String failureReason;
    private LocalDateTime paidAt;
    private LocalDateTime createdAt;

    private BigDecimal refundAmount;
    private String refundReason;
    private LocalDateTime refundedAt;

    public static PaymentResponse fromEntity(Payment payment) {
        return PaymentResponse.builder()
                .id(payment.getId())
                .registrationId(payment.getRegistration().getId())
                .eventId(payment.getEvent().getId())
                .eventTitle(payment.getEvent().getTitle())
                .amount(payment.getAmount())
                .currency(payment.getCurrency())
                .status(payment.getStatus())
                .paymentMethod(payment.getPaymentMethod())
                .failureReason(payment.getFailureReason())
                .paidAt(payment.getPaidAt())
                .createdAt(payment.getCreatedAt())
                .refundAmount(payment.getRefundAmount())
                .refundReason(payment.getRefundReason())
                .refundedAt(payment.getRefundedAt())
                .build();
    }
}

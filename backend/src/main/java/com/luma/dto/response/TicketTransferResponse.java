package com.luma.dto.response;

import com.luma.entity.TicketTransfer;
import com.luma.entity.enums.TransferStatus;
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
public class TicketTransferResponse {

    private UUID id;
    private UUID registrationId;
    private String eventTitle;
    private UUID fromUserId;
    private String fromUserName;
    private UUID toUserId;
    private String toUserName;
    private String toEmail;
    private TransferStatus status;
    private boolean isResale;
    private BigDecimal resalePrice;
    private BigDecimal originalPrice;
    private String transferCode;
    private LocalDateTime createdAt;
    private LocalDateTime respondedAt;
    private boolean requiresPayment;

    public static TicketTransferResponse fromEntity(TicketTransfer t) {
        return TicketTransferResponse.builder()
                .id(t.getId())
                .registrationId(t.getRegistration().getId())
                .eventTitle(t.getRegistration().getEvent().getTitle())
                .fromUserId(t.getFromUser().getId())
                .fromUserName(t.getFromUser().getFullName())
                .toUserId(t.getToUser() != null ? t.getToUser().getId() : null)
                .toUserName(t.getToUser() != null ? t.getToUser().getFullName() : null)
                .toEmail(t.getToEmail())
                .status(t.getStatus())
                .isResale(t.isResale())
                .resalePrice(t.getResalePrice())
                .originalPrice(t.getOriginalPrice())
                .transferCode(t.getTransferCode())
                .createdAt(t.getCreatedAt())
                .respondedAt(t.getRespondedAt())
                .build();
    }
}

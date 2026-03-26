package com.luma.dto.response;

import com.luma.entity.Registration;
import com.luma.entity.enums.RegistrationStatus;
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
public class RegistrationResponse {

    private UUID id;
    private UUID userId;
    private String userName;
    private String userEmail;
    private String userPhone;
    private String userAvatarUrl;
    private UUID eventId;
    private String eventTitle;
    private EventResponse event;
    private RegistrationStatus status;
    private String ticketCode;
    private Integer waitingListPosition;
    private LocalDateTime createdAt;
    private LocalDateTime approvedAt;
    private LocalDateTime rejectedAt;
    private String rejectionReason;
    private boolean requiresPayment;
    private Double ticketPrice;
    private LocalDateTime checkedInAt;
    private boolean eligibleForCertificate;
    private CertificateResponse certificate;

    // Ticket type fields
    private UUID ticketTypeId;
    private String ticketTypeName;
    private BigDecimal ticketTypePrice;
    private Integer quantity;

    public static RegistrationResponse fromEntity(Registration registration) {
        return fromEntity(registration, false);
    }

    public static RegistrationResponse fromEntity(Registration registration, boolean hasPaidPayment) {
        return fromEntity(registration, hasPaidPayment, null);
    }

    public static RegistrationResponse fromEntity(Registration registration, boolean hasPaidPayment, CertificateResponse certificate) {
        var event = registration.getEvent();
        var ticketType = registration.getTicketType();

        // Determine price: use ticketType price if available, otherwise event's ticketPrice
        BigDecimal actualPrice = ticketType != null
                ? ticketType.getPrice()
                : (event.getTicketPrice() != null ? event.getTicketPrice() : BigDecimal.ZERO);

        boolean isPaidEvent = actualPrice.compareTo(BigDecimal.ZERO) > 0;
        boolean requiresPayment = isPaidEvent
                && registration.getStatus() == RegistrationStatus.APPROVED
                && !hasPaidPayment;
        Double ticketPrice = actualPrice.doubleValue();

        // Check certificate eligibility: approved, checked-in, event ended
        boolean eligibleForCertificate = registration.getStatus() == RegistrationStatus.APPROVED
                && registration.getCheckedInAt() != null
                && event.getEndTime() != null
                && event.getEndTime().isBefore(LocalDateTime.now());

        RegistrationResponse.RegistrationResponseBuilder builder = RegistrationResponse.builder()
                .id(registration.getId())
                .userId(registration.getUser().getId())
                .userName(registration.getUser().getFullName())
                .userEmail(registration.getUser().getEmail())
                .userPhone(registration.getUser().getPhone())
                .userAvatarUrl(registration.getUser().getAvatarUrl())
                .eventId(registration.getEvent().getId())
                .eventTitle(registration.getEvent().getTitle())
                .event(EventResponse.fromEntity(registration.getEvent()))
                .status(registration.getStatus())
                .ticketCode(registration.getTicketCode())
                .waitingListPosition(registration.getWaitingListPosition())
                .createdAt(registration.getCreatedAt())
                .approvedAt(registration.getApprovedAt())
                .rejectedAt(registration.getRejectedAt())
                .rejectionReason(registration.getRejectionReason())
                .requiresPayment(requiresPayment)
                .ticketPrice(ticketPrice)
                .checkedInAt(registration.getCheckedInAt())
                .eligibleForCertificate(eligibleForCertificate)
                .certificate(certificate)
                .quantity(registration.getQuantity());

        // Add ticket type info if available
        if (ticketType != null) {
            builder.ticketTypeId(ticketType.getId())
                   .ticketTypeName(ticketType.getName())
                   .ticketTypePrice(ticketType.getPrice());
        }

        return builder.build();
    }
}

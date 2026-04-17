package com.luma.dto.response;

import com.luma.entity.enums.RegistrationStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RegistrationStatusResponse {

    private boolean isRegistered;
    private UUID registrationId;
    private RegistrationStatus status;
    private String statusMessage;
    private boolean requiresPayment;
    private Double ticketPrice;
    private String eventTitle;
    private Integer waitingListPosition;
    private UUID ticketTypeId;
    private String ticketTypeName;
    private Integer quantity;

    public static RegistrationStatusResponse notRegistered() {
        return RegistrationStatusResponse.builder()
                .isRegistered(false)
                .registrationId(null)
                .status(null)
                .statusMessage("Not registered")
                .requiresPayment(false)
                .ticketPrice(null)
                .eventTitle(null)
                .waitingListPosition(null)
                .quantity(1)
                .build();
    }

    public static RegistrationStatusResponse registered(UUID registrationId, RegistrationStatus status,
            boolean requiresPayment, Double ticketPrice, String eventTitle, Integer waitingListPosition) {
        return registered(registrationId, status, requiresPayment, ticketPrice, eventTitle,
                waitingListPosition, null, null, 1);
    }

    public static RegistrationStatusResponse registered(UUID registrationId, RegistrationStatus status,
            boolean requiresPayment, Double ticketPrice, String eventTitle, Integer waitingListPosition,
            UUID ticketTypeId, String ticketTypeName, Integer quantity) {
        String message = switch (status) {
            case PENDING -> requiresPayment ? "Awaiting payment" : "Registration pending approval";
            case APPROVED -> "Registration approved";
            case REJECTED -> "Registration rejected";
            case CANCELLED -> "Registration cancelled";
            case WAITING_LIST -> waitingListPosition != null
                    ? "On waiting list (Position #" + waitingListPosition + ")"
                    : "On waiting list";
        };

        return RegistrationStatusResponse.builder()
                .isRegistered(true)
                .registrationId(registrationId)
                .status(status)
                .statusMessage(message)
                .requiresPayment(requiresPayment)
                .ticketPrice(ticketPrice)
                .eventTitle(eventTitle)
                .waitingListPosition(waitingListPosition)
                .ticketTypeId(ticketTypeId)
                .ticketTypeName(ticketTypeName)
                .quantity(quantity != null ? quantity : 1)
                .build();
    }
}

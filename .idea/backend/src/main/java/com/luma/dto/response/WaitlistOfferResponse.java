package com.luma.dto.response;

import com.luma.entity.WaitlistOffer;
import com.luma.entity.enums.WaitlistOfferStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class WaitlistOfferResponse {

    private UUID id;
    private UUID registrationId;
    private UUID eventId;
    private String eventTitle;
    private UUID userId;
    private String userName;
    private WaitlistOfferStatus status;
    private LocalDateTime expiresAt;
    private long remainingMinutes;
    private Integer priorityScore;
    private LocalDateTime acceptedAt;
    private LocalDateTime declinedAt;
    private LocalDateTime createdAt;
    private boolean requiresPayment;

    public static WaitlistOfferResponse fromEntity(WaitlistOffer offer) {
        return WaitlistOfferResponse.builder()
                .id(offer.getId())
                .registrationId(offer.getRegistration().getId())
                .eventId(offer.getEvent().getId())
                .eventTitle(offer.getEvent().getTitle())
                .userId(offer.getUser().getId())
                .userName(offer.getUser().getFullName())
                .status(offer.getStatus())
                .expiresAt(offer.getExpiresAt())
                .remainingMinutes(offer.getRemainingMinutes())
                .priorityScore(offer.getPriorityScore())
                .acceptedAt(offer.getAcceptedAt())
                .declinedAt(offer.getDeclinedAt())
                .createdAt(offer.getCreatedAt())
                .build();
    }
}

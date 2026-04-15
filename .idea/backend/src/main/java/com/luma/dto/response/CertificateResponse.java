package com.luma.dto.response;

import com.luma.entity.Certificate;
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
public class CertificateResponse {

    private UUID id;
    private String certificateCode;
    private String certificateUrl;
    private LocalDateTime generatedAt;

    private UUID eventId;
    private String eventTitle;
    private LocalDateTime eventDate;
    private String eventLocation;

    private UUID userId;
    private String userName;
    private String userEmail;

    public static CertificateResponse fromEntity(Certificate certificate) {
        var registration = certificate.getRegistration();
        var event = registration.getEvent();
        var user = registration.getUser();

        return CertificateResponse.builder()
                .id(certificate.getId())
                .certificateCode(certificate.getCertificateCode())
                .certificateUrl(certificate.getCertificateUrl())
                .generatedAt(certificate.getGeneratedAt())
                .eventId(event.getId())
                .eventTitle(event.getTitle())
                .eventDate(event.getStartTime())
                .eventLocation(event.getVenue() != null ? event.getVenue() : event.getAddress())
                .userId(user.getId())
                .userName(user.getFullName())
                .userEmail(user.getEmail())
                .build();
    }
}

package com.luma.dto.response;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.luma.entity.OrganiserVerificationRequest;
import com.luma.entity.User;
import com.luma.entity.enums.VerificationAiStatus;
import com.luma.entity.enums.VerificationDocumentType;
import com.luma.entity.enums.VerificationStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import java.time.LocalDateTime;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Slf4j
public class VerificationRequestResponse {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private UUID id;
    private UUID organiserId;
    private String organiserName;
    private String organiserEmail;
    private String organiserAvatarUrl;

    private VerificationDocumentType documentType;
    private List<String> documentUrls;
    private String legalName;
    private String documentNumber;

    private boolean isApplication;
    private String organisationName;
    private String organisationBio;
    private String organisationWebsite;
    private String organisationContactEmail;
    private String organisationContactPhone;

    private VerificationStatus status;

    private VerificationAiStatus aiStatus;
    private Integer aiConfidence;
    private String aiReason;

    private String rejectReason;
    private String reviewedByName;
    private LocalDateTime reviewedAt;

    private LocalDateTime submittedAt;
    private LocalDateTime updatedAt;

    public static VerificationRequestResponse fromEntity(OrganiserVerificationRequest req) {
        User organiser = req.getOrganiser();
        User reviewer = req.getReviewedBy();

        List<String> urls = Collections.emptyList();
        if (req.getDocumentUrls() != null && !req.getDocumentUrls().isBlank()) {
            try {
                urls = MAPPER.readValue(req.getDocumentUrls(), new com.fasterxml.jackson.core.type.TypeReference<>() {});
            } catch (Exception e) {
                log.warn("Failed to parse documentUrls JSON: {}", e.getMessage());
            }
        }

        return VerificationRequestResponse.builder()
                .id(req.getId())
                .organiserId(organiser != null ? organiser.getId() : null)
                .organiserName(organiser != null ? organiser.getFullName() : null)
                .organiserEmail(organiser != null ? organiser.getEmail() : null)
                .organiserAvatarUrl(organiser != null ? organiser.getAvatarUrl() : null)
                .documentType(req.getDocumentType())
                .documentUrls(urls)
                .legalName(req.getLegalName())
                .documentNumber(req.getDocumentNumber())
                .isApplication(req.isApplication())
                .organisationName(req.getOrganisationName())
                .organisationBio(req.getOrganisationBio())
                .organisationWebsite(req.getOrganisationWebsite())
                .organisationContactEmail(req.getOrganisationContactEmail())
                .organisationContactPhone(req.getOrganisationContactPhone())
                .status(req.getStatus())
                .aiStatus(req.getAiStatus())
                .aiConfidence(req.getAiConfidence())
                .aiReason(req.getAiReason())
                .rejectReason(req.getRejectReason())
                .reviewedByName(reviewer != null ? reviewer.getFullName() : null)
                .reviewedAt(req.getReviewedAt())
                .submittedAt(req.getSubmittedAt())
                .updatedAt(req.getUpdatedAt())
                .build();
    }
}

package com.luma.dto.response;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.luma.entity.SupportRequest;
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
public class SupportRequestResponse {

    private UUID id;
    private String subject;
    private String message;
    private String category;
    private String status;

    private UUID userId;
    private String userName;
    private String userEmail;

    private UUID relatedEventId;
    private String relatedEventTitle;

    private UUID relatedRegistrationId;
    private String relatedTicketCode;

    /// Full transcript as parsed JSON so the admin UI doesn't have to parse
    /// a string twice. Null when the request had no surrounding chat.
    private JsonNode transcript;

    private String resolutionNote;
    private String resolvedByName;
    private LocalDateTime resolvedAt;

    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public static SupportRequestResponse fromEntity(SupportRequest r, ObjectMapper objectMapper) {
        SupportRequestResponseBuilder b = SupportRequestResponse.builder()
                .id(r.getId())
                .subject(r.getSubject())
                .message(r.getMessage())
                .category(r.getCategory() != null ? r.getCategory().name() : null)
                .status(r.getStatus() != null ? r.getStatus().name() : null)
                .resolutionNote(r.getResolutionNote())
                .resolvedAt(r.getResolvedAt())
                .createdAt(r.getCreatedAt())
                .updatedAt(r.getUpdatedAt());

        if (r.getUser() != null) {
            b.userId(r.getUser().getId())
                    .userName(r.getUser().getFullName())
                    .userEmail(r.getUser().getEmail());
        }
        if (r.getRelatedEvent() != null) {
            b.relatedEventId(r.getRelatedEvent().getId())
                    .relatedEventTitle(r.getRelatedEvent().getTitle());
        }
        if (r.getRelatedRegistration() != null) {
            b.relatedRegistrationId(r.getRelatedRegistration().getId())
                    .relatedTicketCode(r.getRelatedRegistration().getTicketCode());
        }
        if (r.getResolvedBy() != null) {
            b.resolvedByName(r.getResolvedBy().getFullName());
        }
        if (r.getTranscript() != null && !r.getTranscript().isBlank() && objectMapper != null) {
            try {
                b.transcript(objectMapper.readTree(r.getTranscript()));
            } catch (Exception ignored) { /* malformed transcripts are rare and non-fatal */ }
        }
        return b.build();
    }
}

package com.luma.entity;

import com.luma.entity.enums.VerificationAiStatus;
import com.luma.entity.enums.VerificationDocumentType;
import com.luma.entity.enums.VerificationStatus;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "organiser_verification_requests")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OrganiserVerificationRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "organiser_id", nullable = false)
    private User organiser;

    @Enumerated(EnumType.STRING)
    @Column(length = 40)
    private VerificationDocumentType documentType;

    @Column(columnDefinition = "NVARCHAR(MAX)")
    private String documentUrls;

    @Column(columnDefinition = "NVARCHAR(200)")
    private String legalName;

    @Column(length = 100)
    private String documentNumber;

    @Column(nullable = false)
    @Builder.Default
    private boolean isApplication = false;

    @Column(columnDefinition = "NVARCHAR(200)")
    private String organisationName;

    @Column(columnDefinition = "NVARCHAR(MAX)")
    private String organisationBio;

    @Column(length = 500)
    private String organisationWebsite;

    @Column(length = 200)
    private String organisationContactEmail;

    @Column(length = 50)
    private String organisationContactPhone;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private VerificationStatus status = VerificationStatus.PENDING;

    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    private VerificationAiStatus aiStatus;

    private Integer aiConfidence;

    @Column(columnDefinition = "NVARCHAR(MAX)")
    private String aiReason;

    @Column(columnDefinition = "NVARCHAR(MAX)")
    private String rejectReason;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reviewed_by")
    private User reviewedBy;

    private LocalDateTime reviewedAt;

    @CreationTimestamp
    private LocalDateTime submittedAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;
}

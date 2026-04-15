package com.luma.dto.response;

import com.luma.entity.ReviewReport;
import com.luma.entity.enums.ReportReason;
import com.luma.entity.enums.ReportStatus;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
public class ReviewReportResponse {
    private UUID id;
    private UUID reviewId;
    private ReviewResponse review;
    private UUID reporterId;
    private String reporterName;
    private ReportReason reason;
    private String description;
    private ReportStatus status;
    private String resolvedByName;
    private String resolutionNote;
    private LocalDateTime resolvedAt;
    private LocalDateTime createdAt;

    public static ReviewReportResponse fromEntity(ReviewReport report) {
        return ReviewReportResponse.builder()
                .id(report.getId())
                .reviewId(report.getReview().getId())
                .review(ReviewResponse.fromEntity(report.getReview()))
                .reporterId(report.getReporter().getId())
                .reporterName(report.getReporter().getFullName())
                .reason(report.getReason())
                .description(report.getDescription())
                .status(report.getStatus())
                .resolvedByName(report.getResolvedBy() != null ? report.getResolvedBy().getFullName() : null)
                .resolutionNote(report.getResolutionNote())
                .resolvedAt(report.getResolvedAt())
                .createdAt(report.getCreatedAt())
                .build();
    }
}

package com.luma.service;

import com.luma.dto.request.ReportReviewRequest;
import com.luma.dto.request.ResolveReportRequest;
import com.luma.dto.response.PageResponse;
import com.luma.dto.response.ReviewReportResponse;
import com.luma.entity.Review;
import com.luma.entity.ReviewReport;
import com.luma.entity.User;
import com.luma.entity.enums.ReportStatus;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.ReviewReportRepository;
import com.luma.repository.ReviewRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class ReviewReportService {

    private final ReviewReportRepository reportRepository;
    private final ReviewRepository reviewRepository;

    /**
     * User reports a review
     */
    @Transactional
    public ReviewReportResponse reportReview(User reporter, UUID reviewId, ReportReviewRequest request) {
        Review review = reviewRepository.findById(reviewId)
                .orElseThrow(() -> new ResourceNotFoundException("Review not found"));

        // Check if already reported by this user
        if (reportRepository.existsByReporterAndReview(reporter, review)) {
            throw new BadRequestException("You have already reported this review");
        }

        // Cannot report own review
        if (review.getUser().getId().equals(reporter.getId())) {
            throw new BadRequestException("You cannot report your own review");
        }

        ReviewReport report = ReviewReport.builder()
                .review(review)
                .reporter(reporter)
                .reason(request.getReason())
                .description(request.getDescription())
                .status(ReportStatus.PENDING)
                .build();

        report = reportRepository.save(report);
        log.info("Review {} reported by user {} for reason: {}", reviewId, reporter.getId(), request.getReason());

        return ReviewReportResponse.fromEntity(report);
    }

    /**
     * Get reports for organiser's events
     */
    public PageResponse<ReviewReportResponse> getOrganiserReports(User organiser, ReportStatus status, Pageable pageable) {
        Page<ReviewReport> reports;
        if (status != null) {
            reports = reportRepository.findByOrganiserAndStatus(organiser, status, pageable);
        } else {
            reports = reportRepository.findByOrganiser(organiser, pageable);
        }

        return PageResponse.<ReviewReportResponse>builder()
                .content(reports.map(ReviewReportResponse::fromEntity).getContent())
                .page(reports.getNumber())
                .size(reports.getSize())
                .totalElements(reports.getTotalElements())
                .totalPages(reports.getTotalPages())
                .last(reports.isLast())
                .build();
    }

    /**
     * Get pending reports count for organiser
     */
    public long getPendingReportsCount(User organiser) {
        return reportRepository.countByOrganiserAndStatus(organiser, ReportStatus.PENDING);
    }

    /**
     * Organiser resolves a report
     */
    @Transactional
    public ReviewReportResponse resolveReport(User organiser, UUID reportId, ResolveReportRequest request) {
        ReviewReport report = reportRepository.findById(reportId)
                .orElseThrow(() -> new ResourceNotFoundException("Report not found"));

        // Verify organiser owns the event
        if (!report.getReview().getEvent().getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You can only resolve reports for your own events");
        }

        // Check if already resolved
        if (report.getStatus() != ReportStatus.PENDING) {
            throw new BadRequestException("Report has already been resolved");
        }

        report.setStatus(request.getStatus());
        report.setResolutionNote(request.getNote());
        report.setResolvedBy(organiser);
        report.setResolvedAt(LocalDateTime.now());

        // If status is REMOVED, hide the review
        if (request.getStatus() == ReportStatus.REMOVED) {
            Review review = report.getReview();
            reviewRepository.delete(review);
            log.info("Review {} removed by organiser {} due to report", review.getId(), organiser.getId());
        }

        report = reportRepository.save(report);
        log.info("Report {} resolved by organiser {} with status: {}", reportId, organiser.getId(), request.getStatus());

        return ReviewReportResponse.fromEntity(report);
    }

    /**
     * Get single report detail
     */
    public ReviewReportResponse getReport(User organiser, UUID reportId) {
        ReviewReport report = reportRepository.findById(reportId)
                .orElseThrow(() -> new ResourceNotFoundException("Report not found"));

        // Verify organiser owns the event
        if (!report.getReview().getEvent().getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You can only view reports for your own events");
        }

        return ReviewReportResponse.fromEntity(report);
    }
}

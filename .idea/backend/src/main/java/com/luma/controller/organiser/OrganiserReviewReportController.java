package com.luma.controller.organiser;

import com.luma.dto.request.ResolveReportRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.PageResponse;
import com.luma.dto.response.ReviewReportResponse;
import com.luma.entity.User;
import com.luma.entity.enums.ReportStatus;
import com.luma.service.ReviewReportService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/organiser/review-reports")
@RequiredArgsConstructor
@Tag(name = "Organiser Review Reports", description = "APIs for organisers to manage review reports")
public class OrganiserReviewReportController {

    private final ReviewReportService reportService;
    private final UserService userService;

    @GetMapping
    @Operation(summary = "Get all review reports for organiser's events")
    public ResponseEntity<ApiResponse<PageResponse<ReviewReportResponse>>> getReports(
            @RequestParam(required = false) ReportStatus status,
            @PageableDefault(size = 10) Pageable pageable,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(reportService.getOrganiserReports(organiser, status, pageable)));
    }

    @GetMapping("/pending-count")
    @Operation(summary = "Get count of pending reports")
    public ResponseEntity<ApiResponse<Map<String, Long>>> getPendingCount(
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        long count = reportService.getPendingReportsCount(organiser);
        return ResponseEntity.ok(ApiResponse.success(Map.of("count", count)));
    }

    @GetMapping("/{reportId}")
    @Operation(summary = "Get report detail")
    public ResponseEntity<ApiResponse<ReviewReportResponse>> getReport(
            @PathVariable UUID reportId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(reportService.getReport(organiser, reportId)));
    }

    @PutMapping("/{reportId}/resolve")
    @Operation(summary = "Resolve a report (keep or remove review)")
    public ResponseEntity<ApiResponse<ReviewReportResponse>> resolveReport(
            @PathVariable UUID reportId,
            @Valid @RequestBody ResolveReportRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        ReviewReportResponse response = reportService.resolveReport(organiser, reportId, request);
        return ResponseEntity.ok(ApiResponse.success("Report resolved successfully", response));
    }
}

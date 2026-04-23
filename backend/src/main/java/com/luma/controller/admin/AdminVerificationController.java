package com.luma.controller.admin;

import com.luma.dto.request.ReviewVerificationRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.PageResponse;
import com.luma.dto.response.VerificationRequestResponse;
import com.luma.entity.User;
import com.luma.entity.enums.VerificationStatus;
import com.luma.service.OrganiserVerificationService;
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
@RequestMapping("/api/admin/verification-requests")
@RequiredArgsConstructor
@Tag(name = "Admin Verification", description = "Admin review of organiser verification requests")
public class AdminVerificationController {

    private final OrganiserVerificationService verificationService;
    private final UserService userService;

    @GetMapping
    @Operation(summary = "List verification requests (optionally filtered by status and type)")
    public ResponseEntity<ApiResponse<PageResponse<VerificationRequestResponse>>> list(
            @RequestParam(required = false) VerificationStatus status,
            @RequestParam(required = false) Boolean isApplication,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(
                verificationService.listRequests(status, isApplication, pageable)));
    }

    @GetMapping("/stats")
    @Operation(summary = "Verification queue stats (pending counts)")
    public ResponseEntity<ApiResponse<Map<String, Long>>> stats() {
        return ResponseEntity.ok(ApiResponse.success(Map.of(
                "pending", verificationService.countPending(),
                "pendingApplications", verificationService.countPendingApplications(),
                "pendingBadgeRequests", verificationService.countPendingBadgeRequests()
        )));
    }

    @PostMapping("/{id}/review")
    @Operation(summary = "Approve or reject a verification request")
    public ResponseEntity<ApiResponse<VerificationRequestResponse>> review(
            @PathVariable UUID id,
            @Valid @RequestBody ReviewVerificationRequest review,
            @AuthenticationPrincipal UserDetails userDetails) {
        User admin = userService.getEntityByEmail(userDetails.getUsername());
        VerificationRequestResponse response = verificationService.review(id, admin, review);
        return ResponseEntity.ok(ApiResponse.success("Verification reviewed", response));
    }
}

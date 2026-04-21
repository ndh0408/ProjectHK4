package com.luma.controller.admin;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.PageResponse;
import com.luma.dto.response.SupportRequestResponse;
import com.luma.entity.SupportRequest;
import com.luma.entity.User;
import com.luma.service.SupportRequestService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin/support-requests")
@RequiredArgsConstructor
@Tag(name = "Admin Support Requests", description = "Triage support requests escalated from the AI assistant")
public class AdminSupportRequestController {

    private final SupportRequestService supportRequestService;
    private final UserService userService;

    @GetMapping
    @Operation(summary = "List support requests, optionally filtered by status")
    public ResponseEntity<ApiResponse<PageResponse<SupportRequestResponse>>> list(
            @RequestParam(required = false, defaultValue = "OPEN") String status,
            @RequestParam(required = false, defaultValue = "0") int page,
            @RequestParam(required = false, defaultValue = "20") int size) {
        return ResponseEntity.ok(ApiResponse.success(
                supportRequestService.listForAdmin(status, page, size)));
    }

    @GetMapping("/counts")
    @Operation(summary = "Count of support requests by status (for dashboard badges)")
    public ResponseEntity<ApiResponse<Map<String, Long>>> counts() {
        return ResponseEntity.ok(ApiResponse.success(supportRequestService.getAdminCounts()));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get a support request with full transcript")
    public ResponseEntity<ApiResponse<SupportRequestResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.success(supportRequestService.getForAdmin(id)));
    }

    @PatchMapping("/{id}")
    @Operation(summary = "Update status + resolution note for a support request")
    public ResponseEntity<ApiResponse<SupportRequestResponse>> update(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserDetails userDetails) {
        String rawStatus = body.get("status");
        if (rawStatus == null || rawStatus.isBlank()) {
            throw new com.luma.exception.BadRequestException("status is required");
        }
        SupportRequest.Status newStatus;
        try {
            newStatus = SupportRequest.Status.valueOf(rawStatus.trim().toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new com.luma.exception.BadRequestException("Invalid status: " + rawStatus);
        }
        User admin = userDetails != null
                ? userService.getEntityByEmail(userDetails.getUsername())
                : null;
        return ResponseEntity.ok(ApiResponse.success(
                "Support request updated",
                supportRequestService.updateStatus(id, newStatus, body.get("resolutionNote"), admin)));
    }
}

package com.luma.controller.admin;

import com.luma.dto.request.EmailCampaignRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.EmailCampaignResponse;
import com.luma.dto.response.EmailMarketingStatsResponse;
import com.luma.entity.User;
import com.luma.entity.enums.EmailCampaignStatus;
import com.luma.service.EmailMarketingService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin/email-marketing")
@RequiredArgsConstructor
@Tag(name = "Admin - Email Marketing", description = "Email campaign management for admin")
public class AdminEmailMarketingController {

    private final EmailMarketingService emailMarketingService;
    private final UserService userService;

    @PostMapping("/campaigns")
    @Operation(summary = "Create a new email campaign")
    public ResponseEntity<ApiResponse<EmailCampaignResponse>> createCampaign(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody EmailCampaignRequest request) {
        User admin = userService.getEntityByEmail(userDetails.getUsername());
        EmailCampaignResponse response = emailMarketingService.createCampaign(admin, request);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PutMapping("/campaigns/{id}")
    @Operation(summary = "Update an email campaign")
    public ResponseEntity<ApiResponse<EmailCampaignResponse>> updateCampaign(
            @PathVariable UUID id,
            @Valid @RequestBody EmailCampaignRequest request) {
        EmailCampaignResponse response = emailMarketingService.updateCampaign(id, request);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/campaigns/{id}")
    @Operation(summary = "Get campaign by ID")
    public ResponseEntity<ApiResponse<EmailCampaignResponse>> getCampaign(@PathVariable UUID id) {
        EmailCampaignResponse response = emailMarketingService.getCampaign(id);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/campaigns")
    @Operation(summary = "Get all campaigns")
    public ResponseEntity<ApiResponse<Page<EmailCampaignResponse>>> getCampaigns(
            @PageableDefault(size = 20) Pageable pageable) {
        Page<EmailCampaignResponse> campaigns = emailMarketingService.getCampaigns(pageable);
        return ResponseEntity.ok(ApiResponse.success(campaigns));
    }

    @GetMapping("/campaigns/status/{status}")
    @Operation(summary = "Get campaigns by status")
    public ResponseEntity<ApiResponse<Page<EmailCampaignResponse>>> getCampaignsByStatus(
            @PathVariable EmailCampaignStatus status,
            @PageableDefault(size = 20) Pageable pageable) {
        Page<EmailCampaignResponse> campaigns = emailMarketingService.getCampaignsByStatus(status, pageable);
        return ResponseEntity.ok(ApiResponse.success(campaigns));
    }

    @DeleteMapping("/campaigns/{id}")
    @Operation(summary = "Delete a campaign")
    public ResponseEntity<ApiResponse<String>> deleteCampaign(@PathVariable UUID id) {
        emailMarketingService.deleteCampaign(id);
        return ResponseEntity.ok(ApiResponse.success("Campaign deleted successfully"));
    }

    @PostMapping("/campaigns/{id}/send")
    @Operation(summary = "Send campaign immediately")
    public ResponseEntity<ApiResponse<EmailCampaignResponse>> sendCampaign(@PathVariable UUID id) {
        EmailCampaignResponse response = emailMarketingService.sendCampaignNow(id);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PostMapping("/campaigns/{id}/schedule")
    @Operation(summary = "Schedule campaign for later")
    public ResponseEntity<ApiResponse<EmailCampaignResponse>> scheduleCampaign(
            @PathVariable UUID id,
            @RequestBody Map<String, String> request) {
        LocalDateTime scheduledAt = LocalDateTime.parse(request.get("scheduledAt"));
        EmailCampaignResponse response = emailMarketingService.scheduleCampaign(id, scheduledAt);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PostMapping("/campaigns/{id}/cancel")
    @Operation(summary = "Cancel a scheduled campaign")
    public ResponseEntity<ApiResponse<EmailCampaignResponse>> cancelCampaign(@PathVariable UUID id) {
        EmailCampaignResponse response = emailMarketingService.cancelCampaign(id);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/stats")
    @Operation(summary = "Get email marketing statistics")
    public ResponseEntity<ApiResponse<EmailMarketingStatsResponse>> getStats() {
        EmailMarketingStatsResponse stats = emailMarketingService.getMarketingStats();
        return ResponseEntity.ok(ApiResponse.success(stats));
    }
}

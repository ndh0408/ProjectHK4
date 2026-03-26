package com.luma.controller.admin;

import com.luma.dto.request.OrganiserCommissionRequest;
import com.luma.dto.request.PlatformConfigRequest;
import com.luma.dto.response.*;
import com.luma.entity.CommissionTransaction;
import com.luma.entity.OrganiserCommission;
import com.luma.entity.PlatformConfig;
import com.luma.entity.User;
import com.luma.service.CommissionService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin/commission")
@RequiredArgsConstructor
@Tag(name = "Admin Commission", description = "APIs for admin commission management")
public class AdminCommissionController {

    private final CommissionService commissionService;

    // ==================== Platform Config ====================

    @GetMapping("/config")
    @Operation(summary = "Get platform configuration")
    public ResponseEntity<ApiResponse<PlatformConfigResponse>> getPlatformConfig() {
        PlatformConfig config = commissionService.getPlatformConfig();
        return ResponseEntity.ok(ApiResponse.success(PlatformConfigResponse.fromEntity(config)));
    }

    @PutMapping("/config")
    @Operation(summary = "Update platform configuration")
    public ResponseEntity<ApiResponse<PlatformConfigResponse>> updatePlatformConfig(
            @Valid @RequestBody PlatformConfigRequest request,
            @AuthenticationPrincipal User admin) {
        PlatformConfig config = commissionService.updatePlatformConfig(
                request.getDefaultCommissionRate(),
                request.getMinCommissionRate(),
                request.getMaxCommissionRate(),
                request.getMinPayoutAmount(),
                admin.getId()
        );
        return ResponseEntity.ok(ApiResponse.success("Platform configuration updated successfully",
                PlatformConfigResponse.fromEntity(config)));
    }

    // ==================== Organiser Commission ====================

    @GetMapping("/organisers")
    @Operation(summary = "Get all custom organiser commissions")
    public ResponseEntity<ApiResponse<PageResponse<OrganiserCommissionResponse>>> getAllOrganiserCommissions(
            @PageableDefault(size = 20) Pageable pageable) {
        Page<OrganiserCommission> page = commissionService.getAllCustomCommissions(pageable);
        return ResponseEntity.ok(ApiResponse.success(PageResponse.from(page, OrganiserCommissionResponse::fromEntity)));
    }

    @GetMapping("/organisers/{organiserId}/rate")
    @Operation(summary = "Get commission rate for a specific organiser")
    public ResponseEntity<ApiResponse<BigDecimal>> getOrganiserCommissionRate(@PathVariable UUID organiserId) {
        BigDecimal rate = commissionService.getCommissionRateForOrganiser(organiserId);
        return ResponseEntity.ok(ApiResponse.success(rate));
    }

    @PostMapping("/organisers/custom")
    @Operation(summary = "Set custom commission rate for an organiser")
    public ResponseEntity<ApiResponse<OrganiserCommissionResponse>> setCustomCommission(
            @Valid @RequestBody OrganiserCommissionRequest request,
            @AuthenticationPrincipal User admin) {
        OrganiserCommission commission = commissionService.setCustomCommissionRate(
                request.getOrganiserId(),
                request.getCommissionRate(),
                request.getReason(),
                request.getEffectiveFrom(),
                request.getEffectiveUntil(),
                admin
        );
        return ResponseEntity.ok(ApiResponse.success("Custom commission rate set successfully",
                OrganiserCommissionResponse.fromEntity(commission)));
    }

    @DeleteMapping("/organisers/{organiserId}/custom")
    @Operation(summary = "Remove custom commission rate for an organiser (revert to platform default)")
    public ResponseEntity<ApiResponse<Void>> removeCustomCommission(@PathVariable UUID organiserId) {
        commissionService.removeCustomCommissionRate(organiserId);
        return ResponseEntity.ok(ApiResponse.success("Custom commission rate removed successfully", null));
    }

    // ==================== Commission Transactions ====================

    @GetMapping("/transactions/organiser/{organiserId}")
    @Operation(summary = "Get commission transactions for an organiser")
    public ResponseEntity<ApiResponse<PageResponse<CommissionTransactionResponse>>> getOrganiserTransactions(
            @PathVariable UUID organiserId,
            @PageableDefault(size = 20) Pageable pageable) {
        Page<CommissionTransaction> page = commissionService.getOrganiserTransactions(organiserId, pageable);
        return ResponseEntity.ok(ApiResponse.success(PageResponse.from(page, CommissionTransactionResponse::fromEntity)));
    }

    @GetMapping("/transactions/event/{eventId}")
    @Operation(summary = "Get commission transactions for an event")
    public ResponseEntity<ApiResponse<List<CommissionTransactionResponse>>> getEventTransactions(
            @PathVariable UUID eventId) {
        List<CommissionTransaction> transactions = commissionService.getEventTransactions(eventId);
        List<CommissionTransactionResponse> response = transactions.stream()
                .map(CommissionTransactionResponse::fromEntity)
                .toList();
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PostMapping("/settle/{organiserId}")
    @Operation(summary = "Settle pending commissions for an organiser (mark as paid out)")
    public ResponseEntity<ApiResponse<List<CommissionTransactionResponse>>> settleCommissions(
            @PathVariable UUID organiserId,
            @RequestParam String payoutReference) {
        List<CommissionTransaction> settled = commissionService.settleCommissions(organiserId, payoutReference);
        List<CommissionTransactionResponse> response = settled.stream()
                .map(CommissionTransactionResponse::fromEntity)
                .toList();
        return ResponseEntity.ok(ApiResponse.success(
                String.format("Settled %d transactions successfully", settled.size()),
                response));
    }

    // ==================== Statistics ====================

    @GetMapping("/stats")
    @Operation(summary = "Get platform commission statistics")
    public ResponseEntity<ApiResponse<PlatformStatsResponse>> getPlatformStats() {
        return ResponseEntity.ok(ApiResponse.success(
                PlatformStatsResponse.fromStats(commissionService.getPlatformStats())));
    }

    @GetMapping("/stats/range")
    @Operation(summary = "Get platform commission for date range")
    public ResponseEntity<ApiResponse<BigDecimal>> getPlatformCommissionInRange(
            @RequestParam LocalDateTime startDate,
            @RequestParam LocalDateTime endDate) {
        BigDecimal commission = commissionService.getPlatformCommissionInRange(startDate, endDate);
        return ResponseEntity.ok(ApiResponse.success(commission));
    }

    @GetMapping("/stats/organiser/{organiserId}")
    @Operation(summary = "Get revenue statistics for an organiser")
    public ResponseEntity<ApiResponse<OrganiserStatsResponse>> getOrganiserStats(@PathVariable UUID organiserId) {
        return ResponseEntity.ok(ApiResponse.success(
                OrganiserStatsResponse.fromStats(commissionService.getOrganiserStats(organiserId))));
    }

    @GetMapping("/stats/event/{eventId}")
    @Operation(summary = "Get revenue statistics for an event")
    public ResponseEntity<ApiResponse<EventRevenueResponse>> getEventStats(@PathVariable UUID eventId) {
        CommissionService.EventRevenueStats stats = commissionService.getEventRevenueStats(eventId);
        // Note: eventTitle would need to be fetched from EventService in real implementation
        return ResponseEntity.ok(ApiResponse.success(
                EventRevenueResponse.fromStats(stats, eventId, null)));
    }
}

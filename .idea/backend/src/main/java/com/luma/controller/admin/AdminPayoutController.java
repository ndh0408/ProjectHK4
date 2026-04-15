package com.luma.controller.admin;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.PayoutResponse;
import com.luma.dto.response.PayoutSummaryResponse;
import com.luma.entity.enums.PayoutStatus;
import com.luma.service.PayoutService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin/payouts")
@RequiredArgsConstructor
@Tag(name = "Admin - Payouts", description = "Admin payout management")
public class AdminPayoutController {

    private final PayoutService payoutService;

    @GetMapping
    @Operation(summary = "Get all payouts")
    public ResponseEntity<ApiResponse<Page<PayoutResponse>>> getAllPayouts(
            @PageableDefault(size = 20) Pageable pageable) {
        Page<PayoutResponse> payouts = payoutService.getAllPayouts(pageable);
        return ResponseEntity.ok(ApiResponse.success(payouts));
    }

    @GetMapping("/status/{status}")
    @Operation(summary = "Get payouts by status")
    public ResponseEntity<ApiResponse<Page<PayoutResponse>>> getPayoutsByStatus(
            @PathVariable PayoutStatus status,
            @PageableDefault(size = 20) Pageable pageable) {
        Page<PayoutResponse> payouts = payoutService.getPayoutsByStatus(List.of(status), pageable);
        return ResponseEntity.ok(ApiResponse.success(payouts));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get payout by ID")
    public ResponseEntity<ApiResponse<PayoutResponse>> getPayoutById(@PathVariable UUID id) {
        PayoutResponse payout = payoutService.getPayoutById(id);
        return ResponseEntity.ok(ApiResponse.success(payout));
    }

    @PostMapping("/{id}/process")
    @Operation(summary = "Manually process a payout")
    public ResponseEntity<ApiResponse<PayoutResponse>> processPayout(@PathVariable UUID id) {
        PayoutResponse payout = payoutService.manualProcessPayout(id);
        return ResponseEntity.ok(ApiResponse.success(payout));
    }

    @PostMapping("/{id}/hold")
    @Operation(summary = "Put payout on hold")
    public ResponseEntity<ApiResponse<PayoutResponse>> putPayoutOnHold(
            @PathVariable UUID id,
            @RequestBody Map<String, String> request) {
        String reason = request.get("reason");
        PayoutResponse payout = payoutService.putPayoutOnHold(id, reason);
        return ResponseEntity.ok(ApiResponse.success(payout));
    }

    @PostMapping("/{id}/release")
    @Operation(summary = "Release payout from hold")
    public ResponseEntity<ApiResponse<PayoutResponse>> releasePayoutFromHold(@PathVariable UUID id) {
        PayoutResponse payout = payoutService.releasePayoutFromHold(id);
        return ResponseEntity.ok(ApiResponse.success(payout));
    }

    @GetMapping("/summary")
    @Operation(summary = "Get admin payout summary")
    public ResponseEntity<ApiResponse<PayoutSummaryResponse>> getPayoutSummary() {
        PayoutSummaryResponse summary = payoutService.getAdminPayoutSummary();
        return ResponseEntity.ok(ApiResponse.success(summary));
    }

    @GetMapping("/organiser/{organiserId}")
    @Operation(summary = "Get payouts by organiser")
    public ResponseEntity<ApiResponse<Page<PayoutResponse>>> getPayoutsByOrganiser(
            @PathVariable UUID organiserId,
            @PageableDefault(size = 20) Pageable pageable) {
        Page<PayoutResponse> payouts = payoutService.getPayoutsByOrganiser(organiserId, pageable);
        return ResponseEntity.ok(ApiResponse.success(payouts));
    }
}

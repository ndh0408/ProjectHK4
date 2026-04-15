package com.luma.controller.admin;

import com.luma.dto.request.WithdrawalProcessRequest;
import com.luma.dto.request.WithdrawalRejectRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.PageResponse;
import com.luma.dto.response.WithdrawalResponse;
import com.luma.dto.response.WithdrawalStatsResponse;
import com.luma.entity.User;
import com.luma.entity.enums.WithdrawalStatus;
import com.luma.service.WithdrawalService;
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

import java.util.UUID;

@RestController
@RequestMapping("/api/admin/withdrawals")
@RequiredArgsConstructor
@Tag(name = "Admin Withdrawals", description = "APIs for admin to manage withdrawal requests")
public class AdminWithdrawalController {

    private final WithdrawalService withdrawalService;

    @GetMapping
    @Operation(summary = "Get all withdrawal requests")
    public ResponseEntity<ApiResponse<PageResponse<WithdrawalResponse>>> getAllWithdrawals(
            @RequestParam(required = false) WithdrawalStatus status,
            @PageableDefault(size = 20) Pageable pageable) {
        Page<WithdrawalResponse> page = withdrawalService.getAllWithdrawals(status, pageable);
        return ResponseEntity.ok(ApiResponse.success(PageResponse.from(page)));
    }

    @GetMapping("/pending")
    @Operation(summary = "Get pending withdrawal requests")
    public ResponseEntity<ApiResponse<PageResponse<WithdrawalResponse>>> getPendingWithdrawals(
            @PageableDefault(size = 20) Pageable pageable) {
        Page<WithdrawalResponse> page = withdrawalService.getPendingWithdrawals(pageable);
        return ResponseEntity.ok(ApiResponse.success(PageResponse.from(page)));
    }

    @GetMapping("/stats")
    @Operation(summary = "Get withdrawal statistics")
    public ResponseEntity<ApiResponse<WithdrawalStatsResponse>> getWithdrawalStats() {
        WithdrawalStatsResponse stats = withdrawalService.getWithdrawalStats();
        return ResponseEntity.ok(ApiResponse.success(stats));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get withdrawal request details")
    public ResponseEntity<ApiResponse<WithdrawalResponse>> getWithdrawalById(@PathVariable UUID id) {
        WithdrawalResponse response = withdrawalService.getWithdrawalById(id);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PostMapping("/{id}/approve")
    @Operation(summary = "Approve a withdrawal request")
    public ResponseEntity<ApiResponse<WithdrawalResponse>> approveWithdrawal(
            @PathVariable UUID id,
            @AuthenticationPrincipal User admin,
            @RequestBody(required = false) WithdrawalProcessRequest request) {
        String adminNote = request != null ? request.getAdminNote() : null;
        WithdrawalResponse response = withdrawalService.approveWithdrawal(id, admin, adminNote);
        return ResponseEntity.ok(ApiResponse.success("Withdrawal request approved successfully", response));
    }

    @PostMapping("/{id}/reject")
    @Operation(summary = "Reject a withdrawal request")
    public ResponseEntity<ApiResponse<WithdrawalResponse>> rejectWithdrawal(
            @PathVariable UUID id,
            @AuthenticationPrincipal User admin,
            @Valid @RequestBody WithdrawalRejectRequest request) {
        WithdrawalResponse response = withdrawalService.rejectWithdrawal(id, admin, request.getReason());
        return ResponseEntity.ok(ApiResponse.success("Withdrawal request rejected", response));
    }

    @PostMapping("/{id}/process")
    @Operation(summary = "Process an approved withdrawal (transfer money)")
    public ResponseEntity<ApiResponse<WithdrawalResponse>> processWithdrawal(
            @PathVariable UUID id,
            @AuthenticationPrincipal User admin) {
        WithdrawalResponse response = withdrawalService.processWithdrawal(id, admin);
        return ResponseEntity.ok(ApiResponse.success("Withdrawal processed successfully", response));
    }
}

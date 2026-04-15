package com.luma.controller.organiser;

import com.luma.dto.request.WithdrawalRequestDTO;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.BalanceResponse;
import com.luma.dto.response.PageResponse;
import com.luma.dto.response.WithdrawalResponse;
import com.luma.entity.User;
import com.luma.service.UserService;
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
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/organiser/withdrawals")
@RequiredArgsConstructor
@Tag(name = "Organiser Withdrawals", description = "APIs for organisers to manage withdrawals")
public class OrganiserWithdrawalController {

    private final WithdrawalService withdrawalService;
    private final UserService userService;

    @GetMapping("/balance")
    @Operation(summary = "Get current balance and withdrawal info")
    public ResponseEntity<ApiResponse<BalanceResponse>> getBalance(
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        BalanceResponse balance = withdrawalService.getOrganiserBalance(organiser);
        return ResponseEntity.ok(ApiResponse.success(balance));
    }

    @PostMapping("/request")
    @Operation(summary = "Create a new withdrawal request")
    public ResponseEntity<ApiResponse<WithdrawalResponse>> createWithdrawalRequest(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody WithdrawalRequestDTO request) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        WithdrawalResponse response = withdrawalService.createWithdrawalRequest(organiser, request);
        return ResponseEntity.ok(ApiResponse.success("Withdrawal request submitted successfully", response));
    }

    @GetMapping("/history")
    @Operation(summary = "Get withdrawal history")
    public ResponseEntity<ApiResponse<PageResponse<WithdrawalResponse>>> getWithdrawalHistory(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        Page<WithdrawalResponse> page = withdrawalService.getOrganiserWithdrawals(organiser, pageable);
        return ResponseEntity.ok(ApiResponse.success(PageResponse.from(page)));
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Cancel a pending withdrawal request")
    public ResponseEntity<ApiResponse<Void>> cancelWithdrawalRequest(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        withdrawalService.cancelWithdrawalRequest(id, organiser);
        return ResponseEntity.ok(ApiResponse.success("Withdrawal request cancelled successfully", null));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get withdrawal request details")
    public ResponseEntity<ApiResponse<WithdrawalResponse>> getWithdrawalDetails(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id) {
        WithdrawalResponse response = withdrawalService.getWithdrawalById(id);
        return ResponseEntity.ok(ApiResponse.success(response));
    }
}

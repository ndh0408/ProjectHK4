package com.luma.controller.organiser;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.OrganiserBankAccountResponse;
import com.luma.dto.response.PayoutResponse;
import com.luma.dto.response.PayoutSummaryResponse;
import com.luma.entity.User;
import com.luma.service.PayoutService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/organiser/payouts")
@RequiredArgsConstructor
@Tag(name = "Organiser - Payouts", description = "Payout management for organisers")
public class OrganiserPayoutController {

    private final PayoutService payoutService;
    private final UserService userService;

    @PostMapping("/bank-account/create")
    @Operation(summary = "Create Stripe Connect account for payouts")
    public ResponseEntity<ApiResponse<OrganiserBankAccountResponse>> createBankAccount(
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        OrganiserBankAccountResponse response = payoutService.createStripeConnectAccount(organiser);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/bank-account")
    @Operation(summary = "Get organiser's bank account details")
    public ResponseEntity<ApiResponse<OrganiserBankAccountResponse>> getBankAccount(
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        OrganiserBankAccountResponse response = payoutService.getBankAccount(organiser);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/bank-account/onboarding-link")
    @Operation(summary = "Get Stripe onboarding link")
    public ResponseEntity<ApiResponse<Map<String, String>>> getOnboardingLink(
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        String url = payoutService.getOnboardingLink(organiser);
        return ResponseEntity.ok(ApiResponse.success(Map.of("url", url)));
    }

    @PostMapping("/bank-account/refresh")
    @Operation(summary = "Refresh bank account status from Stripe")
    public ResponseEntity<ApiResponse<OrganiserBankAccountResponse>> refreshBankAccountStatus(
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        OrganiserBankAccountResponse response = payoutService.refreshAccountStatus(organiser);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping
    @Operation(summary = "Get organiser's payouts")
    public ResponseEntity<ApiResponse<Page<PayoutResponse>>> getMyPayouts(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        Page<PayoutResponse> payouts = payoutService.getPayoutsByOrganiser(organiser.getId(), pageable);
        return ResponseEntity.ok(ApiResponse.success(payouts));
    }

    @GetMapping("/summary")
    @Operation(summary = "Get payout summary for organiser")
    public ResponseEntity<ApiResponse<PayoutSummaryResponse>> getPayoutSummary(
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        PayoutSummaryResponse summary = payoutService.getOrganiserPayoutSummary(organiser.getId());
        return ResponseEntity.ok(ApiResponse.success(summary));
    }
}

package com.luma.controller.user;

import com.luma.dto.request.userboost.CreateUserBoostRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.PageResponse;
import com.luma.dto.response.userboost.UserBoostPackageInfo;
import com.luma.dto.response.userboost.UserBoostResponse;
import com.luma.entity.User;
import com.luma.entity.enums.BoostStatus;
import com.luma.service.PaymentService;
import com.luma.service.UserBoostService;
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

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/user/boost")
@RequiredArgsConstructor
@Tag(name = "User Boost", description = "APIs for user event boost")
public class UserBoostController {

    private final UserBoostService boostService;
    private final UserService userService;
    private final PaymentService paymentService;

    @GetMapping("/packages")
    @Operation(summary = "Get available mini boost packages")
    public ResponseEntity<ApiResponse<List<UserBoostPackageInfo>>> getAvailablePackages() {
        return ResponseEntity.ok(ApiResponse.success(boostService.getAvailablePackages()));
    }

    @PostMapping("/checkout")
    @Operation(summary = "Create checkout session for boost purchase")
    public ResponseEntity<ApiResponse<Map<String, String>>> createBoostCheckout(
            @Valid @RequestBody CreateUserBoostRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());

        UserBoostResponse boost = boostService.createBoost(request, user);

        String checkoutUrl = paymentService.createUserBoostCheckoutSession(
                user.getId(),
                request.getEventId(),
                request.getBoostPackage().name(),
                request.getBoostPackage().getPrice(),
                request.getBoostPackage().getDurationDays(),
                boost.getId()
        );

        return ResponseEntity.ok(ApiResponse.success(
                Map.of(
                        "checkoutUrl", checkoutUrl,
                        "boostId", boost.getId().toString(),
                        "price", request.getBoostPackage().getPrice().toString()
                )));
    }

    @PostMapping("/{boostId}/confirm-payment")
    @Operation(summary = "Confirm boost payment (called after successful payment)")
    public ResponseEntity<ApiResponse<UserBoostResponse>> confirmBoostPayment(
            @PathVariable UUID boostId,
            @AuthenticationPrincipal UserDetails userDetails) {
        UserBoostResponse boost = boostService.activateBoost(boostId, "payment_confirmed");
        return ResponseEntity.ok(ApiResponse.success("Boost activated successfully", boost));
    }

    @DeleteMapping("/{boostId}")
    @Operation(summary = "Cancel pending boost")
    public ResponseEntity<ApiResponse<Void>> cancelBoost(
            @PathVariable UUID boostId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        boostService.cancelBoost(boostId, user);
        return ResponseEntity.ok(ApiResponse.success("Boost cancelled", null));
    }

    @GetMapping
    @Operation(summary = "Get user's boosts")
    public ResponseEntity<ApiResponse<PageResponse<UserBoostResponse>>> getMyBoosts(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(required = false) BoostStatus status,
            @PageableDefault(size = 20) Pageable pageable) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        Page<UserBoostResponse> boosts = boostService.getUserBoosts(user.getId(), status, pageable);
        return ResponseEntity.ok(ApiResponse.success(PageResponse.from(boosts)));
    }

    @GetMapping("/{boostId}")
    @Operation(summary = "Get boost by ID")
    public ResponseEntity<ApiResponse<UserBoostResponse>> getBoostById(@PathVariable UUID boostId) {
        return ResponseEntity.ok(ApiResponse.success(boostService.getBoostById(boostId)));
    }

    @GetMapping("/check/{eventId}")
    @Operation(summary = "Check if event is boosted")
    public ResponseEntity<ApiResponse<Boolean>> checkEventBoosted(@PathVariable UUID eventId) {
        return ResponseEntity.ok(ApiResponse.success(boostService.isEventBoosted(eventId)));
    }

}

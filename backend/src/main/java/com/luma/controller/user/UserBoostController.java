package com.luma.controller.user;

import com.luma.dto.request.userboost.CreateUserBoostRequest;
import com.luma.dto.request.userboost.PurchaseExtraEventRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.PageResponse;
import com.luma.dto.response.userboost.UserBoostPackageInfo;
import com.luma.dto.response.userboost.UserBoostResponse;
import com.luma.dto.response.userboost.UserEventLimitResponse;
import com.luma.entity.User;
import com.luma.entity.enums.BoostStatus;
import com.luma.service.PaymentService;
import com.luma.service.UserBoostService;
import com.luma.service.UserEventLimitService;
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
@Tag(name = "User Boost", description = "APIs for user event boost and event limits")
public class UserBoostController {

    private final UserBoostService boostService;
    private final UserEventLimitService eventLimitService;
    private final UserService userService;
    private final PaymentService paymentService;

    @GetMapping("/packages")
    @Operation(summary = "Get available mini boost packages")
    public ResponseEntity<ApiResponse<List<UserBoostPackageInfo>>> getAvailablePackages() {
        return ResponseEntity.ok(ApiResponse.success(boostService.getAvailablePackages()));
    }

    @GetMapping("/event-limit")
    @Operation(summary = "Get user's event creation limit and usage")
    public ResponseEntity<ApiResponse<UserEventLimitResponse>> getEventLimit(
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(eventLimitService.getUserEventLimit(user.getId())));
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

    @PostMapping("/purchase-extra-event")
    @Operation(summary = "Purchase extra event slots")
    public ResponseEntity<ApiResponse<Map<String, String>>> purchaseExtraEvent(
            @Valid @RequestBody PurchaseExtraEventRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());

        String checkoutUrl = paymentService.createExtraEventCheckoutSession(
                user.getId(),
                request.getQuantity(),
                eventLimitService.getExtraEventPrice()
        );

        return ResponseEntity.ok(ApiResponse.success(
                Map.of(
                        "checkoutUrl", checkoutUrl,
                        "quantity", String.valueOf(request.getQuantity()),
                        "pricePerEvent", eventLimitService.getExtraEventPrice().toString(),
                        "totalPrice", eventLimitService.getExtraEventPrice()
                                .multiply(java.math.BigDecimal.valueOf(request.getQuantity())).toString()
                )));
    }

    @PostMapping("/confirm-extra-event-purchase")
    @Operation(summary = "Confirm extra event purchase (called after successful payment)")
    public ResponseEntity<ApiResponse<UserEventLimitResponse>> confirmExtraEventPurchase(
            @RequestParam int quantity,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        UserEventLimitResponse response = eventLimitService.purchaseExtraEventAfterPayment(
                user.getId(), quantity, "payment_confirmed");
        return ResponseEntity.ok(ApiResponse.success("Extra event(s) purchased successfully", response));
    }

    @GetMapping("/can-create-event")
    @Operation(summary = "Check if user can create event")
    public ResponseEntity<ApiResponse<Map<String, Object>>> canCreateEvent(
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());

        boolean canCreate = eventLimitService.canCreateEvent(user.getId());
        boolean canCreateFree = eventLimitService.canCreateFreeEvent(user.getId());
        boolean needsPurchase = eventLimitService.needsToPurchaseEvent(user.getId());

        return ResponseEntity.ok(ApiResponse.success(
                Map.of(
                        "canCreate", canCreate,
                        "canCreateFree", canCreateFree,
                        "needsPurchase", needsPurchase,
                        "extraEventPrice", eventLimitService.getExtraEventPrice().toString(),
                        "maxAttendeesPerEvent", eventLimitService.getMaxAttendeesPerEvent()
                )));
    }
}

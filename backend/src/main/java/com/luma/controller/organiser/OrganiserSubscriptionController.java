package com.luma.controller.organiser;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.subscription.OrganiserSubscriptionResponse;
import com.luma.dto.response.subscription.SubscriptionPlanInfo;
import com.luma.entity.User;
import com.luma.entity.enums.SubscriptionPlan;
import com.luma.service.OrganiserSubscriptionService;
import com.luma.service.PaymentService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/organiser/subscription")
@RequiredArgsConstructor
@Tag(name = "Organiser Subscription", description = "Subscription management for organisers")
@PreAuthorize("hasRole('ORGANISER')")
public class OrganiserSubscriptionController {

    private final OrganiserSubscriptionService subscriptionService;
    private final UserService userService;
    private final PaymentService paymentService;

    @GetMapping("/plans")
    @Operation(summary = "Get all available subscription plans")
    public ResponseEntity<ApiResponse<List<SubscriptionPlanInfo>>> getAllPlans() {
        return ResponseEntity.ok(ApiResponse.success(subscriptionService.getAllPlans()));
    }

    @GetMapping
    @Operation(summary = "Get current subscription status")
    public ResponseEntity<ApiResponse<OrganiserSubscriptionResponse>> getMySubscription(
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(
                subscriptionService.getOrCreateSubscription(organiser.getId())));
    }

    @PostMapping("/upgrade/{plan}")
    @Operation(summary = "Upgrade to a new subscription plan")
    public ResponseEntity<ApiResponse<OrganiserSubscriptionResponse>> upgradePlan(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable SubscriptionPlan plan) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(
                subscriptionService.upgradePlan(organiser.getId(), plan)));
    }

    @PostMapping("/cancel")
    @Operation(summary = "Cancel subscription (downgrade to FREE)")
    public ResponseEntity<ApiResponse<OrganiserSubscriptionResponse>> cancelSubscription(
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(
                subscriptionService.cancelSubscription(organiser.getId())));
    }

    @GetMapping("/compare/{plan}")
    @Operation(summary = "Classify a proposed plan change as SAME / UPGRADE / DOWNGRADE / CANCEL")
    public ResponseEntity<ApiResponse<Map<String, String>>> comparePlan(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable SubscriptionPlan plan) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        String action = subscriptionService.comparePlan(organiser.getId(), plan);
        return ResponseEntity.ok(ApiResponse.success(Map.of("action", action, "plan", plan.name())));
    }

    /**
     * Downgrade between paid tiers (e.g. PREMIUM → STANDARD) applied immediately without a
     * new Stripe charge. The organiser already paid for the higher tier this billing cycle,
     * so the switch is free; they simply lose higher-tier benefits starting now.
     */
    @PostMapping("/downgrade/{plan}")
    @Operation(summary = "Downgrade to a lower paid tier (no charge)")
    public ResponseEntity<ApiResponse<OrganiserSubscriptionResponse>> downgradePlan(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable SubscriptionPlan plan) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(
                subscriptionService.upgradePlan(organiser.getId(), plan)));
    }

    @GetMapping("/can-create-event")
    @Operation(summary = "Check if organiser can create more events")
    public ResponseEntity<ApiResponse<Boolean>> canCreateEvent(
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(
                subscriptionService.canCreateEvent(organiser.getId())));
    }

    @GetMapping("/boost-discount")
    @Operation(summary = "Get boost discount percentage for current plan")
    public ResponseEntity<ApiResponse<Integer>> getBoostDiscount(
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(
                subscriptionService.getBoostDiscountPercent(organiser.getId())));
    }

    @PostMapping("/checkout/{plan}")
    @Operation(summary = "Create Stripe checkout session for subscription upgrade")
    public ResponseEntity<ApiResponse<Map<String, String>>> createCheckoutSession(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable SubscriptionPlan plan) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());

        // Pull admin-edited price from config so any Subscription Plan update in admin reflects
        // immediately in what organisers are charged at checkout.
        BigDecimal amount = subscriptionService.getMonthlyPrice(plan);

        if (amount == null || amount.compareTo(BigDecimal.ZERO) == 0) {
            return ResponseEntity.badRequest().body(
                    ApiResponse.error("Cannot create checkout for FREE plan"));
        }

        String checkoutUrl = paymentService.createSubscriptionCheckoutSession(
                organiser.getId(), plan.name(), amount);

        return ResponseEntity.ok(ApiResponse.success(
                Map.of("checkoutUrl", checkoutUrl, "plan", plan.name())));
    }

    @PostMapping("/confirm-payment/{plan}")
    @Operation(summary = "Confirm subscription payment and upgrade plan")
    public ResponseEntity<ApiResponse<OrganiserSubscriptionResponse>> confirmPayment(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable SubscriptionPlan plan) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());

        OrganiserSubscriptionResponse response = subscriptionService.upgradePlan(organiser.getId(), plan);

        return ResponseEntity.ok(ApiResponse.success(response));
    }
}

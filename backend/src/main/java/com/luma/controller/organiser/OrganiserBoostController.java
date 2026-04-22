package com.luma.controller.organiser;

import com.luma.dto.request.boost.CreateBoostRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.PageResponse;
import com.luma.dto.response.boost.BoostPackageInfo;
import com.luma.dto.response.boost.BoostResponse;
import com.luma.dto.response.boost.BoostUpgradeInfo;
import com.luma.entity.User;
import com.luma.entity.enums.BoostPackage;
import com.luma.entity.enums.BoostStatus;
import com.luma.service.EventBoostService;
import com.luma.service.OrganiserSubscriptionService;
import com.luma.service.PaymentService;
import com.luma.service.UserService;
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
@RequestMapping("/api/organiser/boosts")
@RequiredArgsConstructor
public class OrganiserBoostController {

    private final EventBoostService boostService;
    private final UserService userService;
    private final PaymentService paymentService;
    private final OrganiserSubscriptionService subscriptionService;

    @GetMapping("/packages")
    public ResponseEntity<ApiResponse<List<BoostPackageInfo>>> getAvailablePackages(
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(
                boostService.getAvailablePackagesWithDiscount(organiser.getId())));
    }

    @PostMapping("/{boostId}/confirm-payment")
    public ResponseEntity<ApiResponse<BoostResponse>> confirmBoostPayment(
            @PathVariable UUID boostId,
            @RequestParam(required = false) String action,
            @RequestParam(required = false) UUID existingBoostId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        BoostResponse boost = boostService.confirmPayment(boostId, action, existingBoostId, organiser);
        String message = switch (action == null ? "" : action) {
            case "EXTEND" -> "Boost extended successfully";
            case "UPGRADE", "DOWNGRADE" -> "Boost upgraded successfully";
            default -> "Boost activated successfully";
        };
        return ResponseEntity.ok(ApiResponse.success(message, boost));
    }

    @DeleteMapping("/{boostId}")
    public ResponseEntity<ApiResponse<Void>> cancelBoost(
            @PathVariable UUID boostId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        boostService.cancelBoost(boostId, organiser);
        return ResponseEntity.ok(ApiResponse.success("Boost cancelled", null));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<BoostResponse>>> getMyBoosts(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(required = false) BoostStatus status,
            @PageableDefault(size = 20) Pageable pageable) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        Page<BoostResponse> boosts = boostService.getOrganiserBoosts(organiser.getId(), status, pageable);
        return ResponseEntity.ok(ApiResponse.success(PageResponse.from(boosts)));
    }

    /**
     * Boost subscription info proxy — returns the organiser's current subscription wrapped so the
     * boost page can show tier + discount. Declared BEFORE the {boostId} mapping so the literal
     * path wins over the UUID-typed wildcard; otherwise Spring tries to parse "subscription" as a
     * UUID and blows up the organiser portal's initial load.
     */
    @GetMapping("/subscription")
    public ResponseEntity<ApiResponse<Object>> getBoostSubscriptionInfo(
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        int discount = subscriptionService.getBoostDiscountPercent(organiser.getId());
        java.util.Map<String, Object> body = new java.util.HashMap<>();
        body.put("discountPercent", discount);
        return ResponseEntity.ok(ApiResponse.success(body));
    }

    @GetMapping("/{boostId}")
    public ResponseEntity<ApiResponse<BoostResponse>> getBoostById(@PathVariable UUID boostId) {
        return ResponseEntity.ok(ApiResponse.success(boostService.getBoostById(boostId)));
    }

    @GetMapping("/check/{eventId}")
    public ResponseEntity<ApiResponse<Boolean>> checkEventBoosted(@PathVariable UUID eventId) {
        return ResponseEntity.ok(ApiResponse.success(boostService.isEventBoosted(eventId)));
    }

    @GetMapping("/check-upgrade/{eventId}")
    public ResponseEntity<ApiResponse<BoostUpgradeInfo>> checkBoostUpgrade(
            @PathVariable UUID eventId,
            @RequestParam BoostPackage packageType,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        BoostUpgradeInfo info = boostService.checkExistingBoost(eventId, packageType, organiser.getId());
        return ResponseEntity.ok(ApiResponse.success(info));
    }

    @PostMapping("/{boostId}/extend")
    public ResponseEntity<ApiResponse<BoostResponse>> extendBoost(
            @PathVariable UUID boostId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        BoostResponse boost = boostService.extendBoost(boostId, organiser, "manual_extend");
        return ResponseEntity.ok(ApiResponse.success("Boost extended successfully", boost));
    }

    @PostMapping("/{boostId}/upgrade")
    public ResponseEntity<ApiResponse<BoostResponse>> upgradeBoost(
            @PathVariable UUID boostId,
            @RequestParam BoostPackage newPackage,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        BoostResponse boost = boostService.upgradeBoost(boostId, newPackage, organiser, "manual_upgrade");
        return ResponseEntity.ok(ApiResponse.success("Boost upgraded successfully", boost));
    }

    @PostMapping("/checkout")
    public ResponseEntity<ApiResponse<Map<String, String>>> createBoostCheckout(
            @Valid @RequestBody CreateBoostRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());

        BoostUpgradeInfo upgradeInfo = boostService.checkExistingBoost(
                request.getEventId(), request.getBoostPackage(), organiser.getId());

        java.math.BigDecimal priceToCharge;
        String action = upgradeInfo.getAction().name();
        UUID existingBoostId = upgradeInfo.getCurrentBoostId();

        UUID boostIdForCheckout;

        if (upgradeInfo.getAction() == BoostUpgradeInfo.BoostAction.NEW) {
            List<BoostPackageInfo> packages = boostService.getAvailablePackagesWithDiscount(organiser.getId());
            BoostPackageInfo selectedPackage = packages.stream()
                    .filter(p -> p.getPackageType().equals(request.getBoostPackage()))
                    .findFirst()
                    .orElseThrow(() -> new IllegalArgumentException("Invalid boost package"));
            priceToCharge = selectedPackage.getPrice();

            BoostResponse boost = boostService.createBoost(request, organiser);
            boostIdForCheckout = boost.getId();
        } else if (upgradeInfo.getAction() == BoostUpgradeInfo.BoostAction.EXTEND) {
            priceToCharge = upgradeInfo.getPrice();
            boostIdForCheckout = existingBoostId;
        } else {
            priceToCharge = upgradeInfo.getPrice();
            BoostResponse boost = boostService.createBoost(request, organiser);
            boostIdForCheckout = boost.getId();
        }

        // Pull the admin-edited duration for the Stripe checkout description so the user sees
        // the right number of days on the payment page. Actual boost activation also uses the
        // config-driven duration (EventBoostService.activateBoost).
        int chargedDays = boostService.getAvailablePackages().stream()
                .filter(p -> p.getPackageType() == request.getBoostPackage())
                .map(BoostPackageInfo::getDurationDays)
                .findFirst()
                .orElse(request.getBoostPackage().getDurationDays());

        String checkoutUrl = paymentService.createBoostCheckoutSession(
                organiser.getId(),
                request.getEventId(),
                request.getBoostPackage().name(),
                priceToCharge,
                chargedDays,
                boostIdForCheckout,
                action,
                existingBoostId
        );

        return ResponseEntity.ok(ApiResponse.success(
                Map.of(
                        "checkoutUrl", checkoutUrl,
                        "boostId", boostIdForCheckout.toString(),
                        "action", action,
                        "price", priceToCharge.toString()
                )));
    }
}

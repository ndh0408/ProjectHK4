package com.luma.controller.admin;

import com.luma.dto.request.BoostPackageConfigUpdateRequest;
import com.luma.dto.request.SubscriptionPlanConfigUpdateRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.entity.BoostPackageConfig;
import com.luma.entity.SubscriptionPlanConfig;
import com.luma.service.BoostPackageConfigService;
import com.luma.service.SubscriptionPlanConfigService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * Admin CRUD for pricing configs. Four canonical tiers seed automatically on first boot —
 * admins can tune numbers, toggle active, and add new custom tiers. Canonical tiers cannot
 * be deleted (code switches on the enum for those) but can be hidden via active=false.
 */
@RestController
@RequestMapping("/api/admin/pricing")
@RequiredArgsConstructor
@Tag(name = "Admin Pricing", description = "Manage boost and subscription pricing")
public class AdminPricingController {

    private final BoostPackageConfigService boostConfigService;
    private final SubscriptionPlanConfigService planConfigService;

    // ---------- Boost Packages ----------

    @GetMapping("/boost-packages")
    @Operation(summary = "List all boost package configs (admin)")
    public ResponseEntity<ApiResponse<List<BoostPackageConfig>>> listBoostPackages() {
        return ResponseEntity.ok(ApiResponse.success(boostConfigService.listAll()));
    }

    @GetMapping("/boost-packages/{key}")
    @Operation(summary = "Get a single boost package config")
    public ResponseEntity<ApiResponse<BoostPackageConfig>> getBoostPackage(@PathVariable String key) {
        return ResponseEntity.ok(ApiResponse.success(boostConfigService.get(key)));
    }

    @PostMapping("/boost-packages/{key}")
    @Operation(summary = "Create a new custom boost package tier")
    public ResponseEntity<ApiResponse<BoostPackageConfig>> createBoostPackage(
            @PathVariable String key,
            @Valid @RequestBody BoostPackageConfigUpdateRequest request) {
        return ResponseEntity.ok(ApiResponse.success(
                "Boost package created",
                boostConfigService.create(key, request)));
    }

    @PutMapping("/boost-packages/{key}")
    @Operation(summary = "Update a boost package")
    public ResponseEntity<ApiResponse<BoostPackageConfig>> updateBoostPackage(
            @PathVariable String key,
            @Valid @RequestBody BoostPackageConfigUpdateRequest request) {
        return ResponseEntity.ok(ApiResponse.success(
                "Boost package updated",
                boostConfigService.update(key, request)));
    }

    @DeleteMapping("/boost-packages/{key}")
    @Operation(summary = "Delete a custom boost package (canonical tiers cannot be deleted)")
    public ResponseEntity<ApiResponse<Void>> deleteBoostPackage(@PathVariable String key) {
        boostConfigService.delete(key);
        return ResponseEntity.ok(ApiResponse.success("Boost package deleted", null));
    }

    // ---------- Subscription Plans ----------

    @GetMapping("/subscription-plans")
    @Operation(summary = "List all subscription plan configs (admin)")
    public ResponseEntity<ApiResponse<List<SubscriptionPlanConfig>>> listSubscriptionPlans() {
        return ResponseEntity.ok(ApiResponse.success(planConfigService.listAll()));
    }

    @GetMapping("/subscription-plans/{key}")
    @Operation(summary = "Get a single subscription plan config")
    public ResponseEntity<ApiResponse<SubscriptionPlanConfig>> getSubscriptionPlan(
            @PathVariable String key) {
        return ResponseEntity.ok(ApiResponse.success(planConfigService.get(key)));
    }

    @PostMapping("/subscription-plans/{key}")
    @Operation(summary = "Create a new custom subscription plan")
    public ResponseEntity<ApiResponse<SubscriptionPlanConfig>> createSubscriptionPlan(
            @PathVariable String key,
            @Valid @RequestBody SubscriptionPlanConfigUpdateRequest request) {
        return ResponseEntity.ok(ApiResponse.success(
                "Subscription plan created",
                planConfigService.create(key, request)));
    }

    @PutMapping("/subscription-plans/{key}")
    @Operation(summary = "Update a subscription plan")
    public ResponseEntity<ApiResponse<SubscriptionPlanConfig>> updateSubscriptionPlan(
            @PathVariable String key,
            @Valid @RequestBody SubscriptionPlanConfigUpdateRequest request) {
        return ResponseEntity.ok(ApiResponse.success(
                "Subscription plan updated",
                planConfigService.update(key, request)));
    }

    @DeleteMapping("/subscription-plans/{key}")
    @Operation(summary = "Delete a custom subscription plan")
    public ResponseEntity<ApiResponse<Void>> deleteSubscriptionPlan(@PathVariable String key) {
        planConfigService.delete(key);
        return ResponseEntity.ok(ApiResponse.success("Subscription plan deleted", null));
    }
}

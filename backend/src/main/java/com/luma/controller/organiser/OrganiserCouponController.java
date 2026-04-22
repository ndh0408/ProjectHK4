package com.luma.controller.organiser;

import com.luma.dto.request.CreateCouponRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.CouponResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.User;
import com.luma.service.AIService;
import com.luma.service.CouponService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/organiser/coupons")
@RequiredArgsConstructor
@Slf4j
@Tag(name = "Organiser Coupons", description = "APIs for managing coupons")
public class OrganiserCouponController {

    private final CouponService couponService;
    private final UserService userService;
    private final AIService aiService;

    @PostMapping
    @Operation(summary = "Create a coupon")
    public ResponseEntity<ApiResponse<CouponResponse>> createCoupon(
            @Valid @RequestBody CreateCouponRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        CouponResponse response = couponService.createCoupon(request, user);
        return ResponseEntity.ok(ApiResponse.success("Coupon created", response));
    }

    @GetMapping
    @Operation(summary = "Get organiser coupons")
    public ResponseEntity<ApiResponse<PageResponse<CouponResponse>>> getCoupons(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(couponService.getOrganiserCoupons(user, pageable)));
    }

    @PostMapping("/{couponId}/disable")
    @Operation(summary = "Disable a coupon")
    public ResponseEntity<ApiResponse<CouponResponse>> disableCoupon(
            @PathVariable UUID couponId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success("Coupon disabled", couponService.disableCoupon(couponId, user)));
    }

    @PostMapping("/ai/generate")
    @Operation(summary = "Generate coupon using AI")
    public ResponseEntity<ApiResponse<Map<String, Object>>> generateCouponAI(
            @RequestBody Map<String, Object> request,
            @AuthenticationPrincipal UserDetails userDetails) {
        try {
            log.debug("generateCouponAI called for user {}", userDetails.getUsername());

            User user = userService.getEntityByEmail(userDetails.getUsername());

            String description = (String) request.get("description");
            String discountType = (String) request.get("discountType");
            BigDecimal discountValue = request.get("discountValue") != null && !request.get("discountValue").toString().isEmpty() ?
                    new BigDecimal(request.get("discountValue").toString()) : null;
            BigDecimal maxDiscountAmount = request.get("maxDiscountAmount") != null && !request.get("maxDiscountAmount").toString().isEmpty() ?
                    new BigDecimal(request.get("maxDiscountAmount").toString()) : null;
            BigDecimal minOrderAmount = request.get("minOrderAmount") != null && !request.get("minOrderAmount").toString().isEmpty() ?
                    new BigDecimal(request.get("minOrderAmount").toString()) : null;
            Integer maxUsageCount = request.get("maxUsageCount") != null && !request.get("maxUsageCount").toString().isEmpty() ?
                    Integer.parseInt(request.get("maxUsageCount").toString()) : null;
            Integer maxUsagePerUser = request.get("maxUsagePerUser") != null && !request.get("maxUsagePerUser").toString().isEmpty() ?
                    Integer.parseInt(request.get("maxUsagePerUser").toString()) : null;
            LocalDateTime validFrom = request.get("validFrom") != null && !request.get("validFrom").toString().isEmpty() ?
                    parseDateTime((String) request.get("validFrom")) : null;
            LocalDateTime validUntil = request.get("validUntil") != null && !request.get("validUntil").toString().isEmpty() ?
                    parseDateTime((String) request.get("validUntil")) : null;
            String eventName = (String) request.get("eventName");
            String language = (String) request.getOrDefault("language", "vi");

            String result = aiService.generateCoupon(description, discountType, discountValue,
                    maxDiscountAmount, minOrderAmount, maxUsageCount, maxUsagePerUser,
                    validFrom, validUntil, eventName, language);

            try {
                com.fasterxml.jackson.databind.ObjectMapper mapper = new com.fasterxml.jackson.databind.ObjectMapper();
                Map<String, Object> jsonResult = mapper.readValue(result, Map.class);
                return ResponseEntity.ok(ApiResponse.success("Coupon generated", jsonResult));
            } catch (Exception e) {
                return ResponseEntity.ok(ApiResponse.success("Coupon generated", Map.of("rawResponse", result)));
            }
        } catch (RuntimeException e) {
            log.error("AI coupon generation failed", e);
            String errorMsg = e.getMessage();
            if (errorMsg == null || errorMsg.isBlank()) {
                errorMsg = "Unknown error: " + e.getClass().getName();
            }

            if (errorMsg.contains("API key") || errorMsg.contains("authentication failed")) {
                return ResponseEntity
                        .status(500)
                        .body(ApiResponse.error("OPENAI API not configured: " + errorMsg));
            }
            return ResponseEntity
                    .status(500)
                    .body(ApiResponse.error("Failed to generate coupon: " + errorMsg));
        } catch (Exception e) {
            log.error("AI coupon generation unexpected error", e);
            String errorMsg = e.getMessage() != null ? e.getMessage() : e.getClass().getSimpleName();
            return ResponseEntity
                    .status(500)
                    .body(ApiResponse.error("Internal server error: " + errorMsg));
        }
    }

    private LocalDateTime parseDateTime(String dateTimeStr) {
        if (dateTimeStr == null || dateTimeStr.isEmpty()) {
            return null;
        }
        try {
            // Handle ISO 8601 format with timezone (e.g., 2026-05-01T02:16:00.000Z)
            if (dateTimeStr.endsWith("Z")) {
                Instant instant = Instant.parse(dateTimeStr);
                return instant.atZone(ZoneId.systemDefault()).toLocalDateTime();
            }
            // Handle format without timezone (e.g., 2026-05-01T02:16:00)
            return LocalDateTime.parse(dateTimeStr);
        } catch (Exception e) {
            // Try parsing as offset datetime (e.g., 2026-05-01T02:16:00+00:00)
            try {
                return java.time.OffsetDateTime.parse(dateTimeStr).toLocalDateTime();
            } catch (Exception ex) {
                throw new IllegalArgumentException("Invalid date format: " + dateTimeStr, ex);
            }
        }
    }
}

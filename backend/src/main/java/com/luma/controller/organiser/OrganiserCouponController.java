package com.luma.controller.organiser;

import com.luma.dto.request.CreateCouponRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.CouponResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.User;
import com.luma.service.CouponService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/organiser/coupons")
@RequiredArgsConstructor
@Tag(name = "Organiser Coupons", description = "APIs for managing coupons")
public class OrganiserCouponController {

    private final CouponService couponService;
    private final UserService userService;

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
}

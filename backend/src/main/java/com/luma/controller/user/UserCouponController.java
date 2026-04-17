package com.luma.controller.user;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.CouponResponse;
import com.luma.dto.response.CouponValidationResponse;
import com.luma.entity.Registration;
import com.luma.entity.User;
import com.luma.service.CouponService;
import com.luma.service.RegistrationService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/user/coupons")
@RequiredArgsConstructor
@Tag(name = "User Coupons", description = "APIs for validating coupons")
public class UserCouponController {

    private final CouponService couponService;
    private final UserService userService;
    private final RegistrationService registrationService;

    @GetMapping("/validate")
    @Operation(summary = "Validate a coupon code")
    public ResponseEntity<ApiResponse<CouponValidationResponse>> validateCoupon(
            @RequestParam String code,
            @RequestParam BigDecimal amount,
            @RequestParam(required = false) UUID eventId,
            @RequestParam(required = false) UUID registrationId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());

        UUID resolvedEventId = eventId;
        if (resolvedEventId == null && registrationId != null) {
            Registration reg = registrationService.getEntityById(registrationId);
            resolvedEventId = reg.getEvent().getId();
        }
        if (resolvedEventId == null) {
            throw new com.luma.exception.BadRequestException("Either eventId or registrationId is required");
        }

        CouponValidationResponse response = couponService.validateCoupon(code, amount, user, resolvedEventId);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping
    @Operation(summary = "Get available coupons for user",
            description = "Accepts either eventId or registrationId. If registrationId is " +
                    "provided the event is resolved automatically. When neither is provided " +
                    "only global coupons are returned.")
    public ResponseEntity<ApiResponse<List<CouponResponse>>> getAvailableCoupons(
            @RequestParam(required = false) UUID eventId,
            @RequestParam(required = false) UUID registrationId,
            @AuthenticationPrincipal UserDetails userDetails) {
        userService.getEntityByEmail(userDetails.getUsername());

        UUID resolvedEventId = eventId;
        if (resolvedEventId == null && registrationId != null) {
            Registration reg = registrationService.getEntityById(registrationId);
            resolvedEventId = reg.getEvent().getId();
        }

        List<CouponResponse> coupons = couponService.getAvailableCouponsForUser(resolvedEventId);
        return ResponseEntity.ok(ApiResponse.success(coupons));
    }
}

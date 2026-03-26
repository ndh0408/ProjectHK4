package com.luma.controller.user;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.PaymentIntentResponse;
import com.luma.dto.response.PaymentResponse;
import com.luma.entity.User;
import com.luma.service.PaymentService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/user/payments")
@RequiredArgsConstructor
@Tag(name = "User Payments", description = "Payment APIs for users")
public class UserPaymentController {

    private final PaymentService paymentService;
    private final UserService userService;

    @PostMapping("/registrations/{registrationId}/payment-intent")
    @Operation(summary = "Create payment intent for a registration")
    public ResponseEntity<ApiResponse<PaymentIntentResponse>> createPaymentIntent(
            @PathVariable UUID registrationId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        PaymentIntentResponse response = paymentService.createPaymentIntent(registrationId, user);
        return ResponseEntity.ok(ApiResponse.success("Payment intent created", response));
    }

    @PostMapping("/registrations/{registrationId}/confirm-payment")
    @Operation(summary = "Confirm payment for a registration")
    public ResponseEntity<ApiResponse<PaymentResponse>> confirmPayment(
            @PathVariable UUID registrationId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        PaymentResponse response = paymentService.confirmPayment(registrationId, user);
        return ResponseEntity.ok(ApiResponse.success("Payment confirmed", response));
    }

    @GetMapping("/registrations/{registrationId}/payment-status")
    @Operation(summary = "Get payment status for a registration")
    public ResponseEntity<ApiResponse<PaymentResponse>> getPaymentStatus(
            @PathVariable UUID registrationId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        PaymentResponse response = paymentService.getPaymentByRegistrationId(registrationId, user);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PostMapping("/registrations/{registrationId}/checkout-session")
    @Operation(summary = "Create Stripe Checkout Session for web payment")
    public ResponseEntity<ApiResponse<PaymentIntentResponse>> createCheckoutSession(
            @PathVariable UUID registrationId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        PaymentIntentResponse response = paymentService.createCheckoutSession(registrationId, user);
        return ResponseEntity.ok(ApiResponse.success("Checkout session created", response));
    }
}

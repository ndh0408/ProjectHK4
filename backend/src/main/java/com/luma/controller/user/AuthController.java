package com.luma.controller.user;

import com.luma.dto.request.GoogleAuthRequest;
import com.luma.dto.request.LoginRequest;
import com.luma.dto.request.RefreshTokenRequest;
import com.luma.dto.request.RegisterRequest;
import com.luma.dto.request.ResendOtpRequest;
import com.luma.dto.request.VerifyOtpRequest;
import com.luma.dto.request.ApproveQrLoginRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.AuthResponse;
import com.luma.dto.response.PendingVerificationResponse;
import com.luma.dto.response.QrLoginChallengeResponse;
import com.luma.dto.response.QrLoginStatusResponse;
import com.luma.entity.User;
import com.luma.exception.BadRequestException;
import com.luma.service.QrLoginService;
import com.luma.service.AuthService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
@Tag(name = "Authentication", description = "APIs for user authentication")
public class AuthController {

    private final AuthService authService;
    private final UserService userService;
    private final QrLoginService qrLoginService;

    @PostMapping("/register")
    @Operation(summary = "Register a new user; emails a 6-digit OTP if an email is provided")
    public ResponseEntity<ApiResponse<Object>> register(@Valid @RequestBody RegisterRequest request) {
        Object response = authService.register(request);
        String message = (response instanceof PendingVerificationResponse)
                ? "Verification code sent to your email"
                : "Registration successful";
        return ResponseEntity.ok(ApiResponse.success(message, response));
    }

    @PostMapping("/verify-otp")
    @Operation(summary = "Verify email OTP and issue a session token")
    public ResponseEntity<ApiResponse<AuthResponse>> verifyOtp(@Valid @RequestBody VerifyOtpRequest request) {
        AuthResponse response = authService.verifyOtp(request.getEmail(), request.getOtp());
        return ResponseEntity.ok(ApiResponse.success("Email verified successfully", response));
    }

    @PostMapping("/resend-otp")
    @Operation(summary = "Resend a new OTP to the user's email (rate-limited)")
    public ResponseEntity<ApiResponse<Void>> resendOtp(@Valid @RequestBody ResendOtpRequest request) {
        authService.resendOtp(request.getEmail());
        return ResponseEntity.ok(ApiResponse.success("A new verification code has been sent", null));
    }

    @PostMapping("/login")
    @Operation(summary = "Login with email/phone and password; if the email is unverified, returns a PendingVerificationResponse instead of a token")
    public ResponseEntity<ApiResponse<Object>> login(@Valid @RequestBody LoginRequest request) {
        Object response = authService.login(request);
        String message = (response instanceof AuthResponse) ? "Login successful" : "Email verification required";
        return ResponseEntity.ok(ApiResponse.success(message, response));
    }

    @PostMapping("/google")
    @Operation(summary = "Authenticate with Google")
    public ResponseEntity<ApiResponse<AuthResponse>> googleAuth(@Valid @RequestBody GoogleAuthRequest request) {
        AuthResponse response = authService.googleAuth(request);
        return ResponseEntity.ok(ApiResponse.success("Google authentication successful", response));
    }

    @PostMapping("/refresh")
    @Operation(summary = "Refresh access token")
    public ResponseEntity<ApiResponse<AuthResponse>> refreshToken(@Valid @RequestBody RefreshTokenRequest request) {
        AuthResponse response = authService.refreshToken(request.getRefreshToken());
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PostMapping("/qr-login/challenge")
    @Operation(summary = "Create a temporary QR login challenge for Flutter web")
    public ResponseEntity<ApiResponse<QrLoginChallengeResponse>> createQrLoginChallenge() {
        QrLoginChallengeResponse response = qrLoginService.createChallenge();
        return ResponseEntity.ok(ApiResponse.success("QR login challenge created", response));
    }

    @GetMapping("/qr-login/challenge/{challengeId}")
    @Operation(summary = "Get the current status of a QR login challenge")
    public ResponseEntity<ApiResponse<QrLoginStatusResponse>> getQrLoginChallengeStatus(
            @PathVariable String challengeId,
            @RequestParam String pollingToken) {
        QrLoginStatusResponse response = qrLoginService.getStatus(parseUuid(challengeId), pollingToken);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PostMapping("/qr-login/approve")
    @Operation(summary = "Approve a QR login challenge from the authenticated Flutter mobile app")
    public ResponseEntity<ApiResponse<Void>> approveQrLogin(
            @Valid @RequestBody ApproveQrLoginRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        if (userDetails == null) {
            throw new com.luma.exception.UnauthorizedException("Please sign in on the mobile app before approving web login.");
        }

        User user = userService.getEntityByEmail(userDetails.getUsername());
        qrLoginService.approveChallenge(
                parseUuid(request.getChallengeId()),
                request.getApprovalCode(),
                user
        );
        return ResponseEntity.ok(ApiResponse.success("Web login approved", null));
    }

    @PostMapping("/qr-login/challenge/{challengeId}/exchange")
    @Operation(summary = "Exchange an approved QR login challenge for a session")
    public ResponseEntity<ApiResponse<AuthResponse>> exchangeQrLoginChallenge(
            @PathVariable String challengeId,
            @RequestParam String pollingToken) {
        java.util.UUID userId = qrLoginService.consumeApprovedChallenge(
                parseUuid(challengeId),
                pollingToken
        );
        AuthResponse response = authService.issueSessionForUserId(userId);
        return ResponseEntity.ok(ApiResponse.success("QR login successful", response));
    }

    @PostMapping("/logout")
    @Operation(summary = "Logout current user")
    public ResponseEntity<ApiResponse<Void>> logout(@AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        authService.logout(user);
        return ResponseEntity.ok(ApiResponse.success("Logout successful", null));
    }

    private java.util.UUID parseUuid(String raw) {
        try {
            return java.util.UUID.fromString(raw);
        } catch (IllegalArgumentException e) {
            throw new BadRequestException("Invalid QR login challenge ID");
        }
    }
}

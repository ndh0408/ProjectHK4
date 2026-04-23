package com.luma.controller.user;

import com.luma.dto.request.DeviceTokenRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.entity.User;
import com.luma.service.DeviceTokenService;
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
@RequestMapping("/api/user/device-tokens")
@RequiredArgsConstructor
@Tag(name = "Device Tokens", description = "Register FCM tokens for push notifications")
public class UserDeviceTokenController {

    private final DeviceTokenService deviceTokenService;
    private final UserService userService;

    @PostMapping
    @Operation(summary = "Register or refresh an FCM device token for the current user")
    public ResponseEntity<ApiResponse<Void>> register(
            @Valid @RequestBody DeviceTokenRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        deviceTokenService.upsert(user, request);
        return ResponseEntity.ok(ApiResponse.success("Device token registered", null));
    }

    @DeleteMapping
    @Operation(summary = "Remove an FCM device token (e.g. on logout)")
    public ResponseEntity<ApiResponse<Void>> unregister(
            @RequestParam String token,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        deviceTokenService.unregister(user.getId(), token);
        return ResponseEntity.ok(ApiResponse.success("Device token removed", null));
    }
}

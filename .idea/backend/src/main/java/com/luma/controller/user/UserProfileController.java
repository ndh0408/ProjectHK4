package com.luma.controller.user;

import com.luma.dto.request.ChangePasswordRequest;
import com.luma.dto.request.UpdateProfileRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.UserResponse;
import com.luma.entity.User;
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
@RequestMapping("/api/user/profile")
@RequiredArgsConstructor
@Tag(name = "User Profile", description = "APIs for user profile management")
public class UserProfileController {

    private final UserService userService;

    @GetMapping
    @Operation(summary = "Get current user profile")
    public ResponseEntity<ApiResponse<UserResponse>> getProfile(@AuthenticationPrincipal UserDetails userDetails) {
        UserResponse response = userService.getUserByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PutMapping
    @Operation(summary = "Update current user profile")
    public ResponseEntity<ApiResponse<UserResponse>> updateProfile(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody UpdateProfileRequest request) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        UserResponse response = userService.updateProfile(user.getId(), request);
        return ResponseEntity.ok(ApiResponse.success("Profile updated successfully", response));
    }

    @PostMapping("/change-password")
    @Operation(summary = "Change password")
    public ResponseEntity<ApiResponse<Void>> changePassword(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody ChangePasswordRequest request) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        userService.changePassword(user.getId(), request);
        return ResponseEntity.ok(ApiResponse.success("Password changed successfully", null));
    }
}

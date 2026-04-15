package com.luma.controller.admin;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.PageResponse;
import com.luma.dto.response.UserResponse;
import com.luma.entity.enums.UserRole;
import com.luma.entity.enums.UserStatus;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/admin/users")
@RequiredArgsConstructor
@Tag(name = "Admin Users", description = "APIs for admin user management")
public class AdminUserController {

    private final UserService userService;

    @GetMapping
    @Operation(summary = "Get all users")
    public ResponseEntity<ApiResponse<PageResponse<UserResponse>>> getAllUsers(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) UserRole role,
            @RequestParam(required = false) UserStatus status,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(userService.searchUsers(q, role, status, pageable)));
    }

    @GetMapping("/{userId}")
    @Operation(summary = "Get user by ID")
    public ResponseEntity<ApiResponse<UserResponse>> getUserById(@PathVariable UUID userId) {
        return ResponseEntity.ok(ApiResponse.success(userService.getUserById(userId)));
    }

    @PutMapping("/{userId}/role")
    @Operation(summary = "Update user role")
    public ResponseEntity<ApiResponse<UserResponse>> updateRole(
            @PathVariable UUID userId,
            @RequestParam UserRole role) {
        return ResponseEntity.ok(ApiResponse.success("Role updated successfully", userService.updateUserRole(userId, role)));
    }

    @PutMapping("/{userId}/status")
    @Operation(summary = "Update user status")
    public ResponseEntity<ApiResponse<UserResponse>> updateStatus(
            @PathVariable UUID userId,
            @RequestParam UserStatus status) {
        return ResponseEntity.ok(ApiResponse.success("Status updated successfully", userService.updateUserStatus(userId, status)));
    }

    @PatchMapping("/{userId}/lock")
    @Operation(summary = "Lock user account")
    public ResponseEntity<ApiResponse<UserResponse>> lockUser(@PathVariable UUID userId) {
        return ResponseEntity.ok(ApiResponse.success("Account locked successfully", userService.lockUser(userId)));
    }

    @PatchMapping("/{userId}/unlock")
    @Operation(summary = "Unlock user account")
    public ResponseEntity<ApiResponse<UserResponse>> unlockUser(@PathVariable UUID userId) {
        return ResponseEntity.ok(ApiResponse.success("Account unlocked successfully", userService.unlockUser(userId)));
    }

    @DeleteMapping("/{userId}")
    @Operation(summary = "Delete user")
    public ResponseEntity<ApiResponse<Void>> deleteUser(@PathVariable UUID userId) {
        userService.deleteUser(userId);
        return ResponseEntity.ok(ApiResponse.success("User deleted successfully", null));
    }
}

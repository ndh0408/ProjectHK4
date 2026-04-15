package com.luma.controller.admin;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.OrganiserResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.enums.UserStatus;
import com.luma.service.OrganiserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/admin/organisers")
@RequiredArgsConstructor
@Tag(name = "Admin Organisers", description = "APIs for admin organiser management")
public class AdminOrganiserController {

    private final OrganiserService organiserService;

    @GetMapping
    @Operation(summary = "Get all organiser profiles")
    public ResponseEntity<ApiResponse<PageResponse<OrganiserResponse>>> getAllOrganisers(
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(organiserService.getAllOrganiserProfiles(pageable)));
    }

    @GetMapping("/{userId}")
    @Operation(summary = "Get organiser profile by user ID")
    public ResponseEntity<ApiResponse<OrganiserResponse>> getOrganiserProfile(@PathVariable UUID userId) {
        return ResponseEntity.ok(ApiResponse.success(organiserService.getOrganiserProfile(userId)));
    }

    @PostMapping("/{userId}/verify")
    @Operation(summary = "Verify an organiser")
    public ResponseEntity<ApiResponse<OrganiserResponse>> verifyOrganiser(@PathVariable UUID userId) {
        return ResponseEntity.ok(ApiResponse.success("Organiser verified successfully", organiserService.verifyOrganiser(userId)));
    }

    @PostMapping("/{userId}/unverify")
    @Operation(summary = "Remove organiser verification")
    public ResponseEntity<ApiResponse<OrganiserResponse>> unverifyOrganiser(@PathVariable UUID userId) {
        return ResponseEntity.ok(ApiResponse.success("Organiser verification removed", organiserService.unverifyOrganiser(userId)));
    }

    @PutMapping("/{userId}/status")
    @Operation(summary = "Update organiser account status")
    public ResponseEntity<ApiResponse<OrganiserResponse>> updateOrganiserStatus(
            @PathVariable UUID userId,
            @RequestParam UserStatus status) {
        return ResponseEntity.ok(ApiResponse.success("Status updated successfully", organiserService.updateOrganiserStatus(userId, status)));
    }
}

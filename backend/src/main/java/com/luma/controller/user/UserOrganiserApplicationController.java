package com.luma.controller.user;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.VerificationRequestResponse;
import com.luma.entity.User;
import com.luma.service.OrganiserVerificationService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Authenticated endpoint any USER can hit to discover their latest organiser
 * application status. Used by the admin-web Login page to show rejected
 * applicants the reason and a reapply link.
 */
@RestController
@RequestMapping("/api/user/organiser-application")
@RequiredArgsConstructor
@Tag(name = "User Organiser Application", description = "View own organiser application status")
public class UserOrganiserApplicationController {

    private final OrganiserVerificationService verificationService;
    private final UserService userService;

    @GetMapping("/status")
    @Operation(summary = "Get my latest organiser application / verification request")
    public ResponseEntity<ApiResponse<VerificationRequestResponse>> myStatus(
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(verificationService.getMyLatest(user)));
    }
}

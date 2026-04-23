package com.luma.controller.organiser;

import com.luma.dto.request.SubmitVerificationRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.VerificationRequestResponse;
import com.luma.entity.User;
import com.luma.service.OrganiserVerificationService;
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
@RequestMapping("/api/organiser/verification")
@RequiredArgsConstructor
@Tag(name = "Organiser Verification", description = "Organiser identity verification APIs")
public class OrganiserVerificationController {

    private final OrganiserVerificationService verificationService;
    private final UserService userService;

    @GetMapping
    @Operation(summary = "Get my latest verification request")
    public ResponseEntity<ApiResponse<VerificationRequestResponse>> getMyLatest(
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(verificationService.getMyLatest(user)));
    }

    @PostMapping
    @Operation(summary = "Submit verification documents for admin review")
    public ResponseEntity<ApiResponse<VerificationRequestResponse>> submit(
            @Valid @RequestBody SubmitVerificationRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        VerificationRequestResponse response = verificationService.submit(user, request);
        return ResponseEntity.ok(ApiResponse.success("Verification request submitted", response));
    }
}

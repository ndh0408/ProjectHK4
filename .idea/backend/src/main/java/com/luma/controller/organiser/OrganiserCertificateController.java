package com.luma.controller.organiser;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.CertificateResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.User;
import com.luma.service.CertificateService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/organiser/certificates")
@RequiredArgsConstructor
@Tag(name = "Organiser Certificates", description = "APIs for organiser to view certificates issued for their events")
public class OrganiserCertificateController {

    private final CertificateService certificateService;
    private final UserService userService;

    @GetMapping
    @Operation(summary = "Get all certificates issued for organiser's events")
    public ResponseEntity<ApiResponse<PageResponse<CertificateResponse>>> getAllCertificates(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(certificateService.getOrganiserCertificates(organiser, pageable)));
    }

    @GetMapping("/event/{eventId}")
    @Operation(summary = "Get certificates for a specific event")
    public ResponseEntity<ApiResponse<PageResponse<CertificateResponse>>> getEventCertificates(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(certificateService.getEventCertificates(eventId, organiser, pageable)));
    }
}

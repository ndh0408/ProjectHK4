package com.luma.controller.user;

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
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/user/certificates")
@RequiredArgsConstructor
@Tag(name = "User Certificates", description = "APIs for user certificate operations")
public class UserCertificateController {

    private final CertificateService certificateService;
    private final UserService userService;

    @GetMapping
    @Operation(summary = "Get all certificates for current user")
    public ResponseEntity<ApiResponse<PageResponse<CertificateResponse>>> getMyCertificates(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(certificateService.getUserCertificates(user, pageable)));
    }

    @GetMapping("/registration/{registrationId}")
    @Operation(summary = "Get certificate by registration ID")
    public ResponseEntity<ApiResponse<CertificateResponse>> getCertificateByRegistration(
            @PathVariable UUID registrationId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        CertificateResponse response = certificateService.getCertificateByRegistration(registrationId, user);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/{certificateId}/download")
    @Operation(summary = "Download certificate PDF")
    public ResponseEntity<byte[]> downloadCertificate(
            @PathVariable UUID certificateId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        byte[] pdfBytes = certificateService.downloadCertificate(certificateId, user);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_PDF);
        headers.setContentDispositionFormData("attachment", "certificate.pdf");

        return ResponseEntity.ok()
                .headers(headers)
                .body(pdfBytes);
    }

    @PostMapping("/registration/{registrationId}/send-email")
    @Operation(summary = "Send certificate to user's email")
    public ResponseEntity<ApiResponse<CertificateResponse>> sendCertificateByEmail(
            @PathVariable UUID registrationId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        CertificateResponse response = certificateService.sendCertificateByEmail(registrationId, user);
        return ResponseEntity.ok(ApiResponse.success("Certificate sent to your email", response));
    }
}

package com.luma.controller;

import com.luma.dto.request.ApplyOrganiserRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.VerificationRequestResponse;
import com.luma.service.CloudinaryService;
import com.luma.service.OrganiserVerificationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;

@RestController
@RequestMapping("/api/public/organiser-application")
@RequiredArgsConstructor
@Tag(name = "Public Organiser Application", description = "Public endpoints to apply as an event organiser")
public class PublicOrganiserApplicationController {

    private final OrganiserVerificationService verificationService;
    private final CloudinaryService cloudinaryService;

    @PostMapping
    @Operation(summary = "Submit an application to become an organiser")
    public ResponseEntity<ApiResponse<VerificationRequestResponse>> apply(
            @Valid @RequestBody ApplyOrganiserRequest request) {
        VerificationRequestResponse response = verificationService.applyAsOrganiser(request);
        return ResponseEntity.ok(ApiResponse.success(
                "Application submitted. We will email you once an admin reviews your request.",
                response));
    }

    @PostMapping(value = "/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Upload a Citizen ID image for an organiser application (public)")
    public ResponseEntity<ApiResponse<Map<String, String>>> uploadDocument(
            @RequestParam("file") MultipartFile file) {
        String url = cloudinaryService.uploadImage(file, "luma/organisers/verification");
        return ResponseEntity.ok(ApiResponse.success(Map.of("url", url)));
    }
}

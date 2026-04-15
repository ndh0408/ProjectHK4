package com.luma.controller.organiser;

import com.luma.dto.request.OrganiserProfileRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.OrganiserResponse;
import com.luma.entity.User;
import com.luma.service.AIService;
import com.luma.service.CloudinaryService;
import com.luma.service.OrganiserService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/organiser/profile")
@RequiredArgsConstructor
@Tag(name = "Organiser Profile", description = "APIs for organiser profile management")
public class OrganiserProfileController {

    private final OrganiserService organiserService;
    private final UserService userService;
    private final CloudinaryService cloudinaryService;
    private final AIService aiService;

    @GetMapping
    @Operation(summary = "Get organiser profile")
    public ResponseEntity<ApiResponse<OrganiserResponse>> getProfile(
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(organiserService.getOrganiserProfileByUser(user)));
    }

    @PostMapping
    @Operation(summary = "Create organiser profile")
    public ResponseEntity<ApiResponse<OrganiserResponse>> createProfile(
            @Valid @RequestBody OrganiserProfileRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        OrganiserResponse response = organiserService.createOrganiserProfile(user, request);
        return ResponseEntity.ok(ApiResponse.success("Profile created successfully", response));
    }

    @PutMapping
    @Operation(summary = "Update organiser profile")
    public ResponseEntity<ApiResponse<OrganiserResponse>> updateProfile(
            @Valid @RequestBody OrganiserProfileRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        OrganiserResponse response = organiserService.updateOrganiserProfile(user, request);
        return ResponseEntity.ok(ApiResponse.success("Profile updated successfully", response));
    }

    @PostMapping("/avatar")
    @Operation(summary = "Upload organiser avatar/logo")
    public ResponseEntity<ApiResponse<OrganiserResponse>> uploadAvatar(
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        String avatarUrl = cloudinaryService.uploadImage(file, "luma/organisers/avatars");
        OrganiserResponse response = organiserService.updateOrganiserLogo(user, avatarUrl);
        return ResponseEntity.ok(ApiResponse.success("Avatar uploaded successfully", response));
    }

    @PostMapping("/cover")
    @Operation(summary = "Upload organiser cover image")
    public ResponseEntity<ApiResponse<OrganiserResponse>> uploadCover(
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        String coverUrl = cloudinaryService.uploadImage(file, "luma/organisers/covers");
        OrganiserResponse response = organiserService.updateOrganiserCover(user, coverUrl);
        return ResponseEntity.ok(ApiResponse.success("Cover uploaded successfully", response));
    }

    @PostMapping("/signature")
    @Operation(summary = "Upload organiser signature for certificates")
    public ResponseEntity<ApiResponse<OrganiserResponse>> uploadSignature(
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        String signatureUrl = cloudinaryService.uploadImage(file, "luma/organisers/signatures");
        OrganiserResponse response = organiserService.updateOrganiserSignature(user, signatureUrl);
        return ResponseEntity.ok(ApiResponse.success("Signature uploaded successfully", response));
    }

    @PostMapping("/ai/generate-bio")
    @Operation(summary = "Generate organiser bio using AI")
    public ResponseEntity<ApiResponse<String>> generateBio(
            @RequestBody java.util.Map<String, String> request,
            @AuthenticationPrincipal UserDetails userDetails) {
        String organizationName = request.get("organizationName");
        String eventTypes = request.get("eventTypes");
        String targetAudience = request.get("targetAudience");
        String additionalInfo = request.get("additionalInfo");

        String bio = aiService.generateOrganiserBio(organizationName, eventTypes, targetAudience, additionalInfo);
        return ResponseEntity.ok(ApiResponse.success("Bio generated successfully", bio));
    }
}

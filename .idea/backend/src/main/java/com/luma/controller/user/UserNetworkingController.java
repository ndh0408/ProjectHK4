package com.luma.controller.user;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.ConnectionResponse;
import com.luma.dto.response.NetworkingProfileResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.User;
import com.luma.service.NetworkingService;
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

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/user/networking")
@RequiredArgsConstructor
@Tag(name = "User Networking", description = "APIs for networking and matchmaking")
public class UserNetworkingController {

    private final NetworkingService networkingService;
    private final UserService userService;

    @GetMapping("/discover")
    @Operation(summary = "Get matched profiles based on compatibility")
    public ResponseEntity<ApiResponse<List<NetworkingProfileResponse>>> discoverProfiles(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        List<NetworkingProfileResponse> profiles = networkingService.getMatchedProfiles(user, pageable);
        return ResponseEntity.ok(ApiResponse.success(profiles));
    }

    @PostMapping("/connect/{userId}")
    @Operation(summary = "Send a connection request")
    public ResponseEntity<ApiResponse<ConnectionResponse>> sendConnectionRequest(
            @PathVariable UUID userId,
            @RequestBody(required = false) Map<String, String> body,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        String message = body != null ? body.get("message") : null;
        ConnectionResponse response = networkingService.sendConnectionRequest(user, userId, message);
        return ResponseEntity.ok(ApiResponse.success("Connection request sent", response));
    }

    @PostMapping("/requests/{requestId}/accept")
    @Operation(summary = "Accept a connection request")
    public ResponseEntity<ApiResponse<ConnectionResponse>> acceptRequest(
            @PathVariable UUID requestId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        ConnectionResponse response = networkingService.acceptRequest(requestId, user);
        return ResponseEntity.ok(ApiResponse.success("Connection accepted", response));
    }

    @PostMapping("/requests/{requestId}/decline")
    @Operation(summary = "Decline a connection request")
    public ResponseEntity<ApiResponse<ConnectionResponse>> declineRequest(
            @PathVariable UUID requestId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        ConnectionResponse response = networkingService.declineRequest(requestId, user);
        return ResponseEntity.ok(ApiResponse.success("Connection declined", response));
    }

    @GetMapping("/requests/pending")
    @Operation(summary = "Get pending connection requests")
    public ResponseEntity<ApiResponse<PageResponse<ConnectionResponse>>> getPendingRequests(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        PageResponse<ConnectionResponse> response = networkingService.getPendingRequests(user, pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/connections")
    @Operation(summary = "Get accepted connections")
    public ResponseEntity<ApiResponse<PageResponse<ConnectionResponse>>> getConnections(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        PageResponse<ConnectionResponse> response = networkingService.getConnections(user, pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }
}

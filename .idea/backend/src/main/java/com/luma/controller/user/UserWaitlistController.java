package com.luma.controller.user;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.WaitlistOfferResponse;
import com.luma.entity.User;
import com.luma.service.UserService;
import com.luma.service.WaitlistService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/user/waitlist")
@RequiredArgsConstructor
@Tag(name = "User Waitlist", description = "APIs for managing waitlist offers")
public class UserWaitlistController {

    private final WaitlistService waitlistService;
    private final UserService userService;

    @GetMapping("/offers")
    @Operation(summary = "Get pending waitlist offers for current user")
    public ResponseEntity<ApiResponse<List<WaitlistOfferResponse>>> getPendingOffers(
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        List<WaitlistOfferResponse> offers = waitlistService.getPendingOffersForUser(user.getId());
        return ResponseEntity.ok(ApiResponse.success(offers));
    }

    @PostMapping("/offers/{offerId}/accept")
    @Operation(summary = "Accept a waitlist offer")
    public ResponseEntity<ApiResponse<WaitlistOfferResponse>> acceptOffer(
            @PathVariable UUID offerId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        WaitlistOfferResponse response = waitlistService.acceptOffer(offerId, user);
        return ResponseEntity.ok(ApiResponse.success("Offer accepted! You are now registered.", response));
    }

    @PostMapping("/offers/{offerId}/decline")
    @Operation(summary = "Decline a waitlist offer")
    public ResponseEntity<ApiResponse<WaitlistOfferResponse>> declineOffer(
            @PathVariable UUID offerId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        WaitlistOfferResponse response = waitlistService.declineOffer(offerId, user);
        return ResponseEntity.ok(ApiResponse.success("Offer declined.", response));
    }
}

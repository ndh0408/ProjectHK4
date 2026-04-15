package com.luma.controller.user;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.OrganiserResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.User;
import com.luma.service.FollowService;
import com.luma.service.OrganiserService;
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
import java.util.UUID;

@RestController
@RequestMapping("/api/user/follow")
@RequiredArgsConstructor
@Tag(name = "User Follow", description = "APIs for following organisers")
public class UserFollowController {

    private final FollowService followService;
    private final OrganiserService organiserService;
    private final UserService userService;

    @PostMapping("/{organiserId}")
    @Operation(summary = "Follow an organiser")
    public ResponseEntity<ApiResponse<Void>> followOrganiser(
            @PathVariable UUID organiserId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        followService.followOrganiser(user, organiserId);
        return ResponseEntity.ok(ApiResponse.success("Followed successfully", null));
    }

    @DeleteMapping("/{organiserId}")
    @Operation(summary = "Unfollow an organiser")
    public ResponseEntity<ApiResponse<Void>> unfollowOrganiser(
            @PathVariable UUID organiserId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        followService.unfollowOrganiser(user, organiserId);
        return ResponseEntity.ok(ApiResponse.success("Unfollowed successfully", null));
    }

    @GetMapping("/following")
    @Operation(summary = "Get list of followed organisers")
    public ResponseEntity<ApiResponse<PageResponse<OrganiserResponse>>> getFollowing(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(followService.getFollowing(user, pageable)));
    }

    @GetMapping("/check/{organiserId}")
    @Operation(summary = "Check if following an organiser")
    public ResponseEntity<ApiResponse<Boolean>> isFollowing(
            @PathVariable UUID organiserId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(followService.isFollowing(user, organiserId)));
    }

    @GetMapping("/featured")
    @Operation(summary = "Get featured organisers")
    public ResponseEntity<ApiResponse<List<OrganiserResponse>>> getFeaturedOrganisers() {
        return ResponseEntity.ok(ApiResponse.success(organiserService.getFeaturedOrganisers()));
    }
}

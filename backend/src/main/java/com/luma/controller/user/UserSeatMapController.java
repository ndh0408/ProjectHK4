package com.luma.controller.user;

import com.luma.dto.response.ApiResponse;
import com.luma.entity.User;
import com.luma.service.SeatMapService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/user/seat-map")
@RequiredArgsConstructor
@Tag(name = "Seat Map", description = "APIs for seat selection")
public class UserSeatMapController {

    private final SeatMapService seatMapService;
    private final UserService userService;

    @GetMapping("/event/{eventId}")
    @Operation(summary = "Get seat map for an event")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getSeatMap(@PathVariable UUID eventId) {
        return ResponseEntity.ok(ApiResponse.success(seatMapService.getSeatMap(eventId)));
    }

    @PostMapping("/lock")
    @Operation(summary = "Lock seats temporarily (5 min)")
    public ResponseEntity<ApiResponse<Map<String, Object>>> lockSeats(
            @RequestBody Map<String, List<UUID>> body,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        List<UUID> seatIds = body != null ? body.get("seatIds") : null;
        if (seatIds == null || seatIds.isEmpty()) {
            throw new com.luma.exception.BadRequestException("At least one seat must be selected");
        }
        if (seatIds.size() > 10) {
            throw new com.luma.exception.BadRequestException("Maximum 10 seats per lock");
        }
        return ResponseEntity.ok(ApiResponse.success(seatMapService.lockSeats(seatIds, user)));
    }

    @PostMapping("/confirm")
    @Operation(summary = "Confirm locked seats after payment")
    public ResponseEntity<ApiResponse<Void>> confirmSeats(
            @RequestBody Map<String, Object> body,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        if (body == null || body.get("registrationId") == null || body.get("seatIds") == null) {
            throw new com.luma.exception.BadRequestException("registrationId and seatIds are required");
        }
        UUID registrationId = UUID.fromString(body.get("registrationId").toString());
        @SuppressWarnings("unchecked")
        List<String> seatIdStrings = (List<String>) body.get("seatIds");
        List<UUID> seatIds = seatIdStrings.stream().map(UUID::fromString).toList();

        com.luma.entity.Registration registration = seatMapService.getRegistrationForConfirm(registrationId, user);
        seatMapService.confirmSeats(seatIds, registration);
        return ResponseEntity.ok(ApiResponse.success("Seats confirmed", null));
    }
}

package com.luma.controller.organiser;

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
@RequestMapping("/api/organiser/seat-map")
@RequiredArgsConstructor
@Tag(name = "Organiser Seat Map", description = "APIs for managing seat maps")
public class OrganiserSeatMapController {

    private final SeatMapService seatMapService;
    private final UserService userService;

    @PostMapping("/event/{eventId}")
    @Operation(summary = "Create seat map for an event")
    public ResponseEntity<ApiResponse<Map<String, Object>>> createSeatMap(
            @PathVariable UUID eventId,
            @RequestBody List<Map<String, Object>> zones,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success("Seat map created", seatMapService.createSeatMap(eventId, zones, user)));
    }

    @GetMapping("/event/{eventId}")
    @Operation(summary = "Get seat map for an event")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getSeatMap(@PathVariable UUID eventId) {
        return ResponseEntity.ok(ApiResponse.success(seatMapService.getSeatMap(eventId)));
    }
}

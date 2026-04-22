package com.luma.controller.admin;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.PageResponse;
import com.luma.dto.response.boost.BoostResponse;
import com.luma.entity.enums.BoostStatus;
import com.luma.service.EventBoostService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin/boosts")
@RequiredArgsConstructor
public class AdminBoostController {

    private final EventBoostService boostService;

    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<BoostResponse>>> getAllBoosts(
            @RequestParam(required = false) BoostStatus status,
            @PageableDefault(size = 20) Pageable pageable) {
        Page<BoostResponse> boosts = boostService.getAllBoosts(status, pageable);
        return ResponseEntity.ok(ApiResponse.success(PageResponse.from(boosts)));
    }

    @GetMapping("/{boostId}")
    public ResponseEntity<ApiResponse<BoostResponse>> getBoostById(@PathVariable UUID boostId) {
        return ResponseEntity.ok(ApiResponse.success(boostService.getBoostById(boostId)));
    }

    @GetMapping("/stats")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getBoostStats() {
        Map<String, Object> stats = new HashMap<>();
        stats.put("totalActive", boostService.getBoostedEventIds().size());
        stats.put("totalFeatured", boostService.getFeaturedEvents().size());
        stats.put("totalHomeBanner", boostService.getHomeBannerEvents().size());
        return ResponseEntity.ok(ApiResponse.success(stats));
    }

    /**
     * Force-expire an active boost — used for moderation (e.g. policy violation, refund granted).
     * Flips status to EXPIRED and clamps endTime to now so it stops surfacing immediately.
     */
    @PostMapping("/{boostId}/force-expire")
    public ResponseEntity<ApiResponse<BoostResponse>> forceExpireBoost(@PathVariable UUID boostId) {
        BoostResponse response = boostService.forceExpireBoost(boostId);
        return ResponseEntity.ok(ApiResponse.success("Boost force-expired", response));
    }
}

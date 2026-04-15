package com.luma.controller.admin;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.RevenueStatsResponse;
import com.luma.service.RevenueService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/revenue")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminRevenueController {

    private final RevenueService revenueService;

    @GetMapping("/stats")
    public ResponseEntity<ApiResponse<RevenueStatsResponse>> getRevenueStats() {
        return ResponseEntity.ok(ApiResponse.success(revenueService.getRevenueStats()));
    }
}

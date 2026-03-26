package com.luma.controller.admin;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.analytics.*;
import com.luma.service.AnalyticsService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/admin/analytics")
@RequiredArgsConstructor
@Tag(name = "Admin - Analytics", description = "Advanced analytics for admin dashboard")
public class AdminAnalyticsController {

    private final AnalyticsService analyticsService;

    @GetMapping("/dashboard")
    @Operation(summary = "Get comprehensive dashboard analytics")
    public ResponseEntity<ApiResponse<DashboardAnalyticsResponse>> getDashboardAnalytics() {
        DashboardAnalyticsResponse analytics = analyticsService.getDashboardAnalytics();
        return ResponseEntity.ok(ApiResponse.success(analytics));
    }

    @GetMapping("/users/growth")
    @Operation(summary = "Get user growth chart data")
    public ResponseEntity<ApiResponse<List<TimeSeriesData>>> getUserGrowthChart(
            @RequestParam(defaultValue = "6") int months) {
        List<TimeSeriesData> data = analyticsService.getUserGrowthChart(months);
        return ResponseEntity.ok(ApiResponse.success(data));
    }

    @GetMapping("/events/growth")
    @Operation(summary = "Get event growth chart data")
    public ResponseEntity<ApiResponse<List<TimeSeriesData>>> getEventGrowthChart(
            @RequestParam(defaultValue = "6") int months) {
        List<TimeSeriesData> data = analyticsService.getEventGrowthChart(months);
        return ResponseEntity.ok(ApiResponse.success(data));
    }

    @GetMapping("/registrations/growth")
    @Operation(summary = "Get registration growth chart data")
    public ResponseEntity<ApiResponse<List<TimeSeriesData>>> getRegistrationGrowthChart(
            @RequestParam(defaultValue = "6") int months) {
        List<TimeSeriesData> data = analyticsService.getRegistrationGrowthChart(months);
        return ResponseEntity.ok(ApiResponse.success(data));
    }

    @GetMapping("/revenue/chart")
    @Operation(summary = "Get revenue chart data")
    public ResponseEntity<ApiResponse<List<TimeSeriesData>>> getRevenueChart(
            @RequestParam(defaultValue = "6") int months) {
        List<TimeSeriesData> data = analyticsService.getRevenueChart(months);
        return ResponseEntity.ok(ApiResponse.success(data));
    }

    @GetMapping("/events/by-category")
    @Operation(summary = "Get events distribution by category")
    public ResponseEntity<ApiResponse<List<CategoryDistribution>>> getEventsByCategory() {
        List<CategoryDistribution> data = analyticsService.getEventsByCategory();
        return ResponseEntity.ok(ApiResponse.success(data));
    }

    @GetMapping("/events/by-city")
    @Operation(summary = "Get events distribution by city")
    public ResponseEntity<ApiResponse<List<CityDistribution>>> getEventsByCity(
            @RequestParam(defaultValue = "10") int limit) {
        List<CityDistribution> data = analyticsService.getEventsByCity(limit);
        return ResponseEntity.ok(ApiResponse.success(data));
    }

    @GetMapping("/events/by-status")
    @Operation(summary = "Get events distribution by status")
    public ResponseEntity<ApiResponse<List<StatusDistribution>>> getEventsByStatus() {
        List<StatusDistribution> data = analyticsService.getEventsByStatus();
        return ResponseEntity.ok(ApiResponse.success(data));
    }

    @GetMapping("/top-organisers")
    @Operation(summary = "Get top organisers by registrations")
    public ResponseEntity<ApiResponse<List<TopOrganiser>>> getTopOrganisers(
            @RequestParam(defaultValue = "10") int limit) {
        List<TopOrganiser> data = analyticsService.getTopOrganisers(limit);
        return ResponseEntity.ok(ApiResponse.success(data));
    }

    @GetMapping("/top-events")
    @Operation(summary = "Get top events by registrations")
    public ResponseEntity<ApiResponse<List<TopEvent>>> getTopEvents(
            @RequestParam(defaultValue = "10") int limit) {
        List<TopEvent> data = analyticsService.getTopEvents(limit);
        return ResponseEntity.ok(ApiResponse.success(data));
    }
}

package com.luma.controller.admin;

import com.luma.dto.response.ActivityLogResponse;
import com.luma.dto.response.AdminStatsResponse;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.enums.EventStatus;
import com.luma.entity.enums.UserRole;
import com.luma.entity.enums.UserStatus;
import com.luma.repository.*;
import com.luma.service.ActivityLogService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin/reports")
@RequiredArgsConstructor
@Tag(name = "Admin Reports", description = "APIs for admin reports and statistics")
public class AdminReportController {

    private final UserRepository userRepository;
    private final EventRepository eventRepository;
    private final RegistrationRepository registrationRepository;
    private final CityRepository cityRepository;
    private final CategoryRepository categoryRepository;
    private final ActivityLogService activityLogService;

    @GetMapping("/stats")
    @Operation(summary = "Get system-wide statistics")
    public ResponseEntity<ApiResponse<AdminStatsResponse>> getSystemStats() {
        long totalUsers = userRepository.countByRole(UserRole.USER);
        long totalOrganisers = userRepository.countByRole(UserRole.ORGANISER);
        long totalAdmins = userRepository.countByRole(UserRole.ADMIN);
        long activeUsers = userRepository.countByStatus(UserStatus.ACTIVE);
        long lockedUsers = userRepository.countByStatus(UserStatus.LOCKED);

        long totalEvents = eventRepository.count();
        long publishedEvents = eventRepository.countByStatus(EventStatus.PUBLISHED);

        long totalRegistrations = registrationRepository.countAll();

        long totalCities = cityRepository.count();
        long totalCategories = categoryRepository.count();

        LocalDateTime startDate = LocalDateTime.now().minusMonths(12);
        List<Object[]> userGrowthData = userRepository.countNewUsersPerMonth(startDate);
        List<AdminStatsResponse.MonthlyStats> newUsersPerMonth = new ArrayList<>();
        for (Object[] row : userGrowthData) {
            newUsersPerMonth.add(AdminStatsResponse.MonthlyStats.builder()
                    .year(((Number) row[0]).intValue())
                    .month(((Number) row[1]).intValue())
                    .count(((Number) row[2]).longValue())
                    .build());
        }

        List<Object[]> eventGrowthData = eventRepository.countNewEventsPerMonth(startDate);
        List<AdminStatsResponse.MonthlyStats> newEventsPerMonth = new ArrayList<>();
        for (Object[] row : eventGrowthData) {
            newEventsPerMonth.add(AdminStatsResponse.MonthlyStats.builder()
                    .year(((Number) row[0]).intValue())
                    .month(((Number) row[1]).intValue())
                    .count(((Number) row[2]).longValue())
                    .build());
        }

        List<Object[]> cityData = eventRepository.countEventsByCity();
        List<AdminStatsResponse.CityEventStats> eventsByCity = new ArrayList<>();
        for (Object[] row : cityData) {
            if (row[0] != null) {
                eventsByCity.add(AdminStatsResponse.CityEventStats.builder()
                        .cityId(((Number) row[0]).longValue())
                        .cityName((String) row[1])
                        .eventCount(((Number) row[2]).longValue())
                        .build());
            }
        }

        List<Object[]> categoryData = eventRepository.countEventsByCategory();
        List<AdminStatsResponse.CategoryEventStats> eventsByCategory = new ArrayList<>();
        for (Object[] row : categoryData) {
            if (row[0] != null) {
                eventsByCategory.add(AdminStatsResponse.CategoryEventStats.builder()
                        .categoryId(((Number) row[0]).longValue())
                        .categoryName((String) row[1])
                        .eventCount(((Number) row[2]).longValue())
                        .build());
            }
        }

        AdminStatsResponse response = AdminStatsResponse.builder()
                .totalUsers(totalUsers)
                .totalOrganisers(totalOrganisers)
                .totalAdmins(totalAdmins)
                .activeUsers(activeUsers)
                .lockedUsers(lockedUsers)
                .totalEvents(totalEvents)
                .publishedEvents(publishedEvents)
                .totalRegistrations(totalRegistrations)
                .totalCities(totalCities)
                .totalCategories(totalCategories)
                .newUsersPerMonth(newUsersPerMonth)
                .newEventsPerMonth(newEventsPerMonth)
                .eventsByCity(eventsByCity)
                .eventsByCategory(eventsByCategory)
                .build();

        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/user-growth")
    @Operation(summary = "Get user growth statistics")
    public ResponseEntity<ApiResponse<List<AdminStatsResponse.MonthlyStats>>> getUserGrowth(
            @RequestParam(defaultValue = "6") int months) {
        LocalDateTime startDate = LocalDateTime.now().minusMonths(months);
        List<Object[]> data = userRepository.countNewUsersPerMonth(startDate);
        List<AdminStatsResponse.MonthlyStats> result = new ArrayList<>();
        for (Object[] row : data) {
            result.add(AdminStatsResponse.MonthlyStats.builder()
                    .year(((Number) row[0]).intValue())
                    .month(((Number) row[1]).intValue())
                    .count(((Number) row[2]).longValue())
                    .build());
        }
        return ResponseEntity.ok(ApiResponse.success(result));
    }

    @GetMapping("/events-by-city")
    @Operation(summary = "Get events count by city")
    public ResponseEntity<ApiResponse<List<AdminStatsResponse.CityEventStats>>> getEventsByCity() {
        List<Object[]> data = eventRepository.countEventsByCity();
        List<AdminStatsResponse.CityEventStats> result = new ArrayList<>();
        for (Object[] row : data) {
            if (row[0] != null) {
                result.add(AdminStatsResponse.CityEventStats.builder()
                        .cityId(((Number) row[0]).longValue())
                        .cityName((String) row[1])
                        .eventCount(((Number) row[2]).longValue())
                        .build());
            }
        }
        return ResponseEntity.ok(ApiResponse.success(result));
    }

    @GetMapping("/events-by-category")
    @Operation(summary = "Get events count by category")
    public ResponseEntity<ApiResponse<List<AdminStatsResponse.CategoryEventStats>>> getEventsByCategory() {
        List<Object[]> data = eventRepository.countEventsByCategory();
        List<AdminStatsResponse.CategoryEventStats> result = new ArrayList<>();
        for (Object[] row : data) {
            if (row[0] != null) {
                result.add(AdminStatsResponse.CategoryEventStats.builder()
                        .categoryId(((Number) row[0]).longValue())
                        .categoryName((String) row[1])
                        .eventCount(((Number) row[2]).longValue())
                        .build());
            }
        }
        return ResponseEntity.ok(ApiResponse.success(result));
    }

    @GetMapping("/activity-logs")
    @Operation(summary = "Get activity logs for a user")
    public ResponseEntity<ApiResponse<PageResponse<ActivityLogResponse>>> getUserActivityLogs(
            @RequestParam UUID userId,
            @PageableDefault(size = 50) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(activityLogService.getActivityLogsByUser(userId, pageable)));
    }

    @GetMapping("/activity-logs/by-date")
    @Operation(summary = "Get activity logs by date range")
    public ResponseEntity<ApiResponse<PageResponse<ActivityLogResponse>>> getActivityLogsByDateRange(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime endDate,
            @PageableDefault(size = 50) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(activityLogService.getActivityLogsByDateRange(startDate, endDate, pageable)));
    }
}

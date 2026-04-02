package com.luma.controller.organiser;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.luma.dto.response.AIInsightsResponse;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.DashboardStatsResponse;
import com.luma.dto.response.UserResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.Event;
import com.luma.entity.User;
import com.luma.entity.enums.EventStatus;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.repository.EventRepository;
import com.luma.repository.RegistrationRepository;
import com.luma.repository.FollowRepository;
import com.luma.service.AIQueryService;
import com.luma.service.AIService;
import com.luma.service.FollowService;
import com.luma.service.UserService;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/organiser/dashboard")
@RequiredArgsConstructor
@Slf4j
@Tag(name = "Organiser Dashboard", description = "APIs for organiser dashboard statistics")
public class OrganiserDashboardController {

    private final UserService userService;
    private final EventRepository eventRepository;
    private final RegistrationRepository registrationRepository;
    private final FollowRepository followRepository;
    private final FollowService followService;
    private final AIService aiService;
    private final AIQueryService aiQueryService;
    private final ObjectMapper objectMapper;

    @GetMapping({"", "/stats"})
    @Operation(summary = "Get dashboard statistics")
    public ResponseEntity<ApiResponse<DashboardStatsResponse>> getDashboardStats(
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());

        long totalEvents = eventRepository.countByOrganiser(organiser);
        long publishedEvents = eventRepository.countByOrganiserAndStatus(organiser, EventStatus.PUBLISHED);
        long draftEvents = eventRepository.countByOrganiserAndStatus(organiser, EventStatus.DRAFT);
        long completedEvents = eventRepository.countByOrganiserAndStatus(organiser, EventStatus.COMPLETED);
        long cancelledEvents = eventRepository.countByOrganiserAndStatus(organiser, EventStatus.CANCELLED);

        long totalRegistrations = registrationRepository.countAllByOrganiser(organiser);
        long approvedRegistrations = registrationRepository.countByOrganiserAndStatus(organiser, RegistrationStatus.APPROVED);
        long pendingRegistrations = registrationRepository.countByOrganiserAndStatus(organiser, RegistrationStatus.PENDING);

        long totalFollowers = followRepository.countByOrganiser(organiser);

        BigDecimal totalRevenue = registrationRepository.calculateTotalRevenueByOrganiser(organiser);
        if (totalRevenue == null) {
            totalRevenue = BigDecimal.ZERO;
        }

        LocalDateTime startDate = LocalDateTime.now().minusDays(30);
        List<Object[]> growthData = registrationRepository.getRegistrationGrowthByOrganiser(organiser.getId(), startDate);
        List<DashboardStatsResponse.RegistrationGrowthData> registrationGrowth = new ArrayList<>();
        for (Object[] row : growthData) {
            registrationGrowth.add(DashboardStatsResponse.RegistrationGrowthData.builder()
                    .date(row[0].toString())
                    .count(((Number) row[1]).longValue())
                    .build());
        }

        List<Event> recentEventsList = eventRepository.findByOrganiserOrderByCreatedAtDesc(
                organiser, PageRequest.of(0, 5)).getContent();
        List<DashboardStatsResponse.RecentEventData> recentEvents = new ArrayList<>();
        for (Event event : recentEventsList) {
            recentEvents.add(DashboardStatsResponse.RecentEventData.builder()
                    .id(event.getId().toString())
                    .title(event.getTitle())
                    .status(event.getStatus().name())
                    .imageUrl(event.getImageUrl())
                    .currentRegistrations(event.getApprovedCount())
                    .capacity(event.getCapacity() != null ? event.getCapacity() : 0)
                    .build());
        }

        DashboardStatsResponse response = DashboardStatsResponse.builder()
                .totalEvents(totalEvents)
                .publishedEvents(publishedEvents)
                .draftEvents(draftEvents)
                .completedEvents(completedEvents)
                .cancelledEvents(cancelledEvents)
                .totalRegistrations(totalRegistrations)
                .approvedRegistrations(approvedRegistrations)
                .pendingRegistrations(pendingRegistrations)
                .totalFollowers(totalFollowers)
                .totalRevenue(totalRevenue)
                .registrationGrowth(registrationGrowth)
                .recentEvents(recentEvents)
                .build();

        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/followers")
    @Operation(summary = "Get list of followers")
    public ResponseEntity<ApiResponse<PageResponse<UserResponse>>> getFollowers(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(followService.getFollowers(organiser, pageable)));
    }

    @GetMapping("/ai-insights")
    @Operation(summary = "Get AI-powered insights and recommendations")
    public ResponseEntity<ApiResponse<AIInsightsResponse>> getAIInsights(
            @AuthenticationPrincipal UserDetails userDetails) {

        User organiser = userService.getEntityByEmail(userDetails.getUsername());

        long totalEvents = eventRepository.countByOrganiser(organiser);
        long publishedEvents = eventRepository.countByOrganiserAndStatus(organiser, EventStatus.PUBLISHED);
        long draftEvents = eventRepository.countByOrganiserAndStatus(organiser, EventStatus.DRAFT);

        long totalRegistrations = registrationRepository.countAllByOrganiser(organiser);
        long approvedRegistrations = registrationRepository.countByOrganiserAndStatus(organiser, RegistrationStatus.APPROVED);
        long pendingRegistrations = registrationRepository.countByOrganiserAndStatus(organiser, RegistrationStatus.PENDING);

        long totalFollowers = followRepository.countByOrganiser(organiser);

        BigDecimal totalRevenue = registrationRepository.calculateTotalRevenueByOrganiser(organiser);
        double revenue = totalRevenue != null ? totalRevenue.doubleValue() : 0;

        try {
            StringBuilder recentEventsInfo = new StringBuilder();
            List<Event> recentEvents = eventRepository.findByOrganiserOrderByCreatedAtDesc(
                    organiser, PageRequest.of(0, 5)).getContent();
            for (Event event : recentEvents) {
                recentEventsInfo.append("- ").append(event.getTitle())
                        .append(" (").append(event.getStatus()).append(")")
                        .append(", Registrations: ").append(event.getApprovedCount())
                        .append("/").append(event.getCapacity() != null ? event.getCapacity() : "unlimited")
                        .append("\n");
            }

            LocalDateTime startDate = LocalDateTime.now().minusDays(30);
            List<Object[]> growthData = registrationRepository.getRegistrationGrowthByOrganiser(organiser.getId(), startDate);
            StringBuilder registrationTrend = new StringBuilder();
            for (Object[] row : growthData) {
                registrationTrend.append(row[0].toString()).append(": ").append(row[1]).append(" registrations\n");
            }

            log.info("Calling AI service for dashboard insights...");
            String aiResponse = aiService.generateDashboardInsights(
                    totalEvents, publishedEvents, draftEvents,
                    totalRegistrations, approvedRegistrations, pendingRegistrations,
                    totalFollowers, revenue,
                    recentEventsInfo.toString(), registrationTrend.toString()
            );
            log.info("AI Response received: {}", aiResponse);

            String cleanJson = aiResponse.trim();
            if (cleanJson.startsWith("```json")) {
                cleanJson = cleanJson.substring(7);
            }
            if (cleanJson.startsWith("```")) {
                cleanJson = cleanJson.substring(3);
            }
            if (cleanJson.endsWith("```")) {
                cleanJson = cleanJson.substring(0, cleanJson.length() - 3);
            }
            cleanJson = cleanJson.trim();
            log.info("Clean JSON to parse: {}", cleanJson);

            AIInsightsResponse response = objectMapper.readValue(cleanJson, AIInsightsResponse.class);
            log.info("Successfully parsed AI response");
            return ResponseEntity.ok(ApiResponse.success("AI insights generated", response));

        } catch (Exception e) {
            log.error("AI Insights error: ", e);
            AIInsightsResponse fallback = AIInsightsResponse.builder()
                    .summary("Phan tich du lieu co ban cua ban.")
                    .insights(List.of(
                            AIInsightsResponse.Insight.builder()
                                    .type("info")
                                    .title("Tong quan su kien")
                                    .description("Ban co " + totalEvents + " su kien voi " + totalRegistrations + " dang ky.")
                                    .build(),
                            AIInsightsResponse.Insight.builder()
                                    .type(pendingRegistrations > 0 ? "warning" : "success")
                                    .title("Dang ky cho duyet")
                                    .description(pendingRegistrations > 0
                                            ? "Ban co " + pendingRegistrations + " dang ky dang cho duyet."
                                            : "Tat ca dang ky da duoc xu ly.")
                                    .actionText(pendingRegistrations > 0 ? "Xem ngay" : null)
                                    .build(),
                            AIInsightsResponse.Insight.builder()
                                    .type("info")
                                    .title("Nguoi theo doi")
                                    .description("Ban co " + totalFollowers + " nguoi theo doi.")
                                    .build()
                    ))
                    .build();
            return ResponseEntity.ok(ApiResponse.success("Basic insights", fallback));
        }
    }

    @GetMapping("/smart-insights")
    @Operation(summary = "Get smart AI insights with full database context and benchmarking")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getSmartInsights(
            @AuthenticationPrincipal UserDetails userDetails) {

        User organiser = userService.getEntityByEmail(userDetails.getUsername());

        try {
            Map<String, Object> insights = aiQueryService.generateSmartOrganiserInsights(organiser);
            return ResponseEntity.ok(ApiResponse.success("Smart AI insights generated with database context", insights));
        } catch (Exception e) {
            log.error("Smart insights error: ", e);
            return ResponseEntity.ok(ApiResponse.error("Failed to generate smart insights: " + e.getMessage()));
        }
    }
}

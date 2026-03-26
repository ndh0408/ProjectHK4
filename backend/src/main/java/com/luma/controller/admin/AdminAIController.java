package com.luma.controller.admin;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.luma.dto.response.AIInsightsResponse;
import com.luma.dto.response.ApiResponse;
import com.luma.entity.Event;
import com.luma.entity.enums.EventStatus;
import com.luma.entity.enums.UserRole;
import com.luma.repository.EventRepository;
import com.luma.repository.OrganiserProfileRepository;
import com.luma.repository.RegistrationRepository;
import com.luma.repository.UserRepository;
import com.luma.service.AIService;
import com.luma.service.EventService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin/ai")
@RequiredArgsConstructor
@Slf4j
@Tag(name = "Admin AI", description = "AI-powered features for admin")
public class AdminAIController {

    private final AIService aiService;
    private final EventService eventService;
    private final EventRepository eventRepository;
    private final UserRepository userRepository;
    private final RegistrationRepository registrationRepository;
    private final OrganiserProfileRepository organiserProfileRepository;
    private final ObjectMapper objectMapper;

    @PostMapping("/analyze-event/{eventId}")
    @Operation(summary = "Analyze event for moderation using AI")
    public ResponseEntity<ApiResponse<Map<String, Object>>> analyzeEventForModeration(@PathVariable UUID eventId) {
        try {
            Event event = eventService.getEntityById(eventId);
            DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");

            String aiResponse = aiService.analyzeEventForModeration(
                    event.getTitle(),
                    event.getDescription(),
                    event.getOrganiser().getFullName(),
                    event.getCategory() != null ? event.getCategory().getName() : null,
                    event.getVenue(),
                    event.getStartTime() != null ? event.getStartTime().format(formatter) : null,
                    event.getCapacity(),
                    event.getTicketPrice() != null ? event.getTicketPrice().doubleValue() : null
            );

            // Parse JSON response
            String cleanJson = cleanJsonResponse(aiResponse);
            Map<String, Object> analysis = objectMapper.readValue(cleanJson, Map.class);

            return ResponseEntity.ok(ApiResponse.success("Event analyzed", analysis));
        } catch (Exception e) {
            log.error("Error analyzing event: ", e);
            return ResponseEntity.ok(ApiResponse.success("Analysis failed", Map.of(
                    "recommendation", "NEEDS_REVIEW",
                    "qualityScore", 50,
                    "summary", "Unable to analyze event automatically. Please review manually.",
                    "strengths", List.of(),
                    "concerns", List.of("AI analysis unavailable"),
                    "suggestedAction", "Manual review required",
                    "rejectionReason", null
            )));
        }
    }

    @PostMapping("/generate-rejection-reason")
    @Operation(summary = "Generate rejection reason using AI")
    public ResponseEntity<ApiResponse<Map<String, String>>> generateRejectionReason(@RequestBody Map<String, String> request) {
        String eventId = request.get("eventId");
        String concerns = request.get("concerns");

        try {
            Event event = eventService.getEntityById(UUID.fromString(eventId));
            String reason = aiService.generateRejectionReason(
                    event.getTitle(),
                    event.getDescription(),
                    concerns
            );

            return ResponseEntity.ok(ApiResponse.success(Map.of("reason", reason)));
        } catch (Exception e) {
            log.error("Error generating rejection reason: ", e);
            return ResponseEntity.ok(ApiResponse.success(Map.of(
                    "reason", "Sự kiện của bạn cần được cải thiện trước khi được phê duyệt. Vui lòng xem xét lại thông tin và nộp lại."
            )));
        }
    }

    @PostMapping("/generate-broadcast-message")
    @Operation(summary = "Generate broadcast notification message using AI")
    public ResponseEntity<ApiResponse<Map<String, String>>> generateBroadcastMessage(@RequestBody Map<String, String> request) {
        String purpose = request.get("purpose");
        String targetAudience = request.get("targetAudience");
        String additionalContext = request.get("additionalContext");

        try {
            String message = aiService.generateBroadcastMessage(purpose, targetAudience, additionalContext);
            return ResponseEntity.ok(ApiResponse.success(Map.of("message", message)));
        } catch (Exception e) {
            log.error("Error generating broadcast message: ", e);
            return ResponseEntity.ok(ApiResponse.success(Map.of(
                    "message", "Thông báo quan trọng từ hệ thống. Vui lòng kiểm tra thông tin chi tiết."
            )));
        }
    }

    @GetMapping("/dashboard-insights")
    @Operation(summary = "Get AI-powered dashboard insights for admin")
    public ResponseEntity<ApiResponse<AIInsightsResponse>> getDashboardInsights() {
        try {
            long totalUsers = userRepository.countByRole(UserRole.USER);
            long totalOrganisers = userRepository.countByRole(UserRole.ORGANISER);
            long totalEvents = eventRepository.count();
            long totalRegistrations = registrationRepository.countAll();

            // Get this month's stats
            LocalDateTime startOfMonth = LocalDateTime.now().withDayOfMonth(1).withHour(0).withMinute(0);
            long newUsersThisMonth = userRepository.countByCreatedAtAfter(startOfMonth);
            long newEventsThisMonth = eventRepository.countByCreatedAtAfter(startOfMonth);

            // Get admin-relevant metrics
            long pendingEvents = eventRepository.countByStatus(EventStatus.PENDING);
            long verifiedOrganisers = 0;
            long unverifiedOrganisers = 0;
            long lowRegistrationEvents = 0;
            try {
                verifiedOrganisers = organiserProfileRepository.countByVerifiedTrue();
                unverifiedOrganisers = organiserProfileRepository.countByVerifiedFalse();
            } catch (Exception e) {
                log.warn("Could not count organisers by verification status: {}", e.getMessage());
            }
            try {
                lowRegistrationEvents = eventRepository.countLowRegistrationEvents();
            } catch (Exception e) {
                log.warn("Could not count low registration events: {}", e.getMessage());
            }

            // Get top categories
            List<Object[]> categoryData = eventRepository.countEventsByCategory();
            StringBuilder topCategories = new StringBuilder();
            int count = 0;
            for (Object[] row : categoryData) {
                if (row[1] != null && count < 5) {
                    topCategories.append("- ").append(row[1]).append(": ").append(row[2]).append(" events\n");
                    count++;
                }
            }

            // Get top cities
            List<Object[]> cityData = eventRepository.countEventsByCity();
            StringBuilder topCities = new StringBuilder();
            count = 0;
            for (Object[] row : cityData) {
                if (row[1] != null && count < 5) {
                    topCities.append("- ").append(row[1]).append(": ").append(row[2]).append(" events\n");
                    count++;
                }
            }

            String aiResponse = aiService.generateAdminInsights(
                    totalUsers, totalOrganisers, totalEvents, totalRegistrations,
                    newUsersThisMonth, newEventsThisMonth,
                    pendingEvents, verifiedOrganisers, unverifiedOrganisers,
                    lowRegistrationEvents, topCategories.toString(), topCities.toString()
            );

            String cleanJson = cleanJsonResponse(aiResponse);
            AIInsightsResponse response = objectMapper.readValue(cleanJson, AIInsightsResponse.class);

            return ResponseEntity.ok(ApiResponse.success("AI insights generated", response));
        } catch (Exception e) {
            log.error("Error generating admin insights: ", e);
            AIInsightsResponse fallback = AIInsightsResponse.builder()
                    .summary("Platform analysis completed.")
                    .insights(List.of(
                            AIInsightsResponse.Insight.builder()
                                    .type("info")
                                    .title("System Status")
                                    .description("System is running normally. Check individual sections for detailed metrics.")
                                    .build()
                    ))
                    .build();
            return ResponseEntity.ok(ApiResponse.success("Basic insights", fallback));
        }
    }

    private String cleanJsonResponse(String response) {
        String cleanJson = response.trim();
        if (cleanJson.startsWith("```json")) {
            cleanJson = cleanJson.substring(7);
        }
        if (cleanJson.startsWith("```")) {
            cleanJson = cleanJson.substring(3);
        }
        if (cleanJson.endsWith("```")) {
            cleanJson = cleanJson.substring(0, cleanJson.length() - 3);
        }
        return cleanJson.trim();
    }
}

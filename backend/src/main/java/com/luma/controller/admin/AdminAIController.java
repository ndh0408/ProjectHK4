package com.luma.controller.admin;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.luma.dto.response.AIInsightsResponse;
import com.luma.dto.response.ApiResponse;
import com.luma.entity.Event;
import com.luma.entity.OrganiserProfile;
import com.luma.entity.OrganiserVerificationRequest;
import com.luma.entity.User;
import com.luma.entity.enums.EventStatus;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.entity.enums.UserRole;
import com.luma.entity.enums.VerificationStatus;
import com.luma.repository.EventRepository;
import com.luma.repository.OrganiserProfileRepository;
import com.luma.repository.OrganiserVerificationRequestRepository;
import com.luma.repository.RegistrationRepository;
import com.luma.repository.ReviewRepository;
import com.luma.repository.UserRepository;
import com.luma.service.AIService;
import com.luma.service.EventService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Duration;
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
    private final OrganiserVerificationRequestRepository verificationRequestRepository;
    private final ReviewRepository reviewRepository;
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

            LocalDateTime startOfMonth = LocalDateTime.now().withDayOfMonth(1).withHour(0).withMinute(0);
            long newUsersThisMonth = userRepository.countByCreatedAtAfter(startOfMonth);
            long newEventsThisMonth = eventRepository.countByCreatedAtAfter(startOfMonth);

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

            List<Object[]> categoryData = eventRepository.countEventsByCategory();
            StringBuilder topCategories = new StringBuilder();
            int count = 0;
            for (Object[] row : categoryData) {
                if (row[1] != null && count < 5) {
                    topCategories.append("- ").append(row[1]).append(": ").append(row[2]).append(" events\n");
                    count++;
                }
            }

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

    @PostMapping("/organiser-review/{userId}")
    @Operation(summary = "AI organiser verification review (English only)")
    public ResponseEntity<ApiResponse<Map<String, Object>>> aiReviewOrganiser(@PathVariable UUID userId) {
        try {
            User organiser = userRepository.findById(userId)
                    .orElseThrow(() -> new RuntimeException("User not found"));

            OrganiserProfile profile = organiserProfileRepository.findByUser(organiser).orElse(null);
            OrganiserVerificationRequest latest = verificationRequestRepository
                    .findTopByOrganiserOrderBySubmittedAtDesc(organiser).orElse(null);
            boolean hasValidDocument = latest != null
                    && latest.getStatus() == VerificationStatus.APPROVED;

            long accountAgeDays = organiser.getCreatedAt() != null
                    ? Duration.between(organiser.getCreatedAt(), LocalDateTime.now()).toDays()
                    : 0;

            long approvedEvents = eventRepository.countByOrganiserIdAndStatus(userId, EventStatus.PUBLISHED);
            long pendingEvents = eventRepository.countByOrganiserIdAndStatus(userId, EventStatus.PENDING);
            long rejectedEvents = eventRepository.countByOrganiserIdAndStatus(userId, EventStatus.REJECTED);
            long totalRegistrations = registrationRepository.countByEventOrganiserId(userId);
            Double averageRating = reviewRepository.getAverageRatingForOrganiser(userId);
            long reviewCount = reviewRepository.countByOrganiserId(userId);

            String displayName = profile != null ? profile.getDisplayName() : organiser.getFullName();
            String bio = profile != null ? profile.getBio() : null;
            String website = profile != null ? profile.getWebsite() : null;
            String contactEmail = profile != null ? profile.getContactEmail() : null;
            String contactPhone = profile != null ? profile.getContactPhone() : null;
            boolean verified = profile != null && profile.isVerified();
            int totalEvents = profile != null ? profile.getTotalEvents() : 0;
            int totalFollowers = profile != null ? profile.getTotalFollowers() : 0;

            String aiResponse = aiService.analyzeOrganiserVerification(
                    displayName, organiser.getEmail(), bio, website,
                    contactEmail, contactPhone, verified,
                    totalEvents, totalFollowers,
                    approvedEvents, pendingEvents, rejectedEvents,
                    totalRegistrations, averageRating, reviewCount,
                    accountAgeDays, hasValidDocument);

            String cleanJson = cleanJsonResponse(aiResponse);
            Map<String, Object> analysis = objectMapper.readValue(cleanJson, Map.class);
            return ResponseEntity.ok(ApiResponse.success("Organiser analysed", analysis));
        } catch (Exception e) {
            log.error("Error analysing organiser: ", e);
            return ResponseEntity.ok(ApiResponse.success("Analysis failed", Map.of(
                    "trust", "MEDIUM",
                    "trustworthy", false,
                    "decision", "REVIEW",
                    "confidence", 40,
                    "summary", "Unable to analyse organiser automatically. Please review manually.",
                    "strengths", List.of(),
                    "missingInfo", List.of(),
                    "riskSignals", List.of("AI analysis unavailable"),
                    "recommendation", "Manual admin review required."
            )));
        }
    }

    @PostMapping("/user-risk/{userId}")
    @Operation(summary = "AI user risk analysis (English only)")
    public ResponseEntity<ApiResponse<Map<String, Object>>> aiAnalyseUser(@PathVariable UUID userId) {
        try {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new RuntimeException("User not found"));

            long accountAgeDays = user.getCreatedAt() != null
                    ? Duration.between(user.getCreatedAt(), LocalDateTime.now()).toDays()
                    : 0;

            long totalRegistrations = registrationRepository.findByUserOrderByCreatedAtDesc(user,
                    org.springframework.data.domain.Pageable.unpaged()).getTotalElements();
            long approvedRegistrations = registrationRepository.countApprovedByUser(user);
            long checkedInCount = registrationRepository.countByUserAndCheckedInAtIsNotNull(user);
            long reviewCount = reviewRepository.findByUserOrderByCreatedAtDesc(user,
                    org.springframework.data.domain.Pageable.unpaged()).getTotalElements();

            String role = user.getRole() != null ? user.getRole().name() : "USER";
            String status = user.getStatus() != null ? user.getStatus().name() : "ACTIVE";

            String aiResponse = aiService.analyzeUserRisk(
                    user.getFullName(), user.getEmail(), role, status,
                    user.isEmailVerified(), user.isPhoneVerified(),
                    accountAgeDays,
                    totalRegistrations, approvedRegistrations,
                    checkedInCount, reviewCount,
                    0, 0);

            String cleanJson = cleanJsonResponse(aiResponse);
            Map<String, Object> analysis = objectMapper.readValue(cleanJson, Map.class);
            return ResponseEntity.ok(ApiResponse.success("User analysed", analysis));
        } catch (Exception e) {
            log.error("Error analysing user: ", e);
            return ResponseEntity.ok(ApiResponse.success("Analysis failed", Map.of(
                    "risk", "LOW",
                    "action", "KEEP",
                    "confidence", 40,
                    "behaviorSummary", "Unable to analyse automatically.",
                    "reasons", List.of("AI analysis unavailable"),
                    "recommendation", "Manual admin review required."
            )));
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

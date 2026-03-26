package com.luma.controller.organiser;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.luma.dto.request.AIGenerateDescriptionRequest;
import com.luma.dto.request.AIGenerateNotificationRequest;
import com.luma.dto.request.AIGenerateQuestionsRequest;
import com.luma.dto.request.AIGenerateSpeakerBioRequest;
import com.luma.dto.request.AIImproveDescriptionRequest;
import com.luma.dto.request.EventCreateRequest;
import com.luma.dto.request.EventUpdateRequest;
import com.luma.dto.response.AIDescriptionResponse;
import com.luma.dto.response.AINotificationResponse;
import com.luma.dto.response.AIQuestionsResponse;
import com.luma.dto.response.AISpeakerBioResponse;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.EventResponse;
import com.luma.dto.response.PageResponse;
import java.util.List;
import com.luma.entity.User;
import com.luma.entity.enums.EventStatus;
import com.luma.service.AIService;
import com.luma.service.EventService;
import com.luma.service.ExcelExportService;
import com.luma.service.OrganiserSubscriptionService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.util.UUID;

@RestController
@RequestMapping("/api/organiser/events")
@RequiredArgsConstructor
@Tag(name = "Organiser Events", description = "APIs for organiser event management")
public class OrganiserEventController {

    private final EventService eventService;
    private final UserService userService;
    private final ExcelExportService excelExportService;
    private final AIService aiService;
    private final OrganiserSubscriptionService subscriptionService;

    @GetMapping
    @Operation(summary = "Get all events by organiser")
    public ResponseEntity<ApiResponse<PageResponse<EventResponse>>> getMyEvents(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(required = false) EventStatus status,
            @PageableDefault(size = 20) Pageable pageable) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        PageResponse<EventResponse> response;
        if (status != null) {
            response = eventService.getEventsByOrganiserAndStatus(user, status, pageable);
        } else {
            response = eventService.getEventsByOrganiser(user, pageable);
        }
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/{eventId}")
    @Operation(summary = "Get event details")
    public ResponseEntity<ApiResponse<EventResponse>> getEventDetails(@PathVariable UUID eventId) {
        return ResponseEntity.ok(ApiResponse.success(eventService.getEventById(eventId)));
    }

    @PostMapping
    @Operation(summary = "Create a new event")
    public ResponseEntity<ApiResponse<EventResponse>> createEvent(
            @Valid @RequestBody EventCreateRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        EventResponse response = eventService.createEvent(user, request);
        return ResponseEntity.ok(ApiResponse.success("Event created successfully", response));
    }

    @PutMapping("/{eventId}")
    @Operation(summary = "Update an event")
    public ResponseEntity<ApiResponse<EventResponse>> updateEvent(
            @PathVariable UUID eventId,
            @Valid @RequestBody EventUpdateRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        EventResponse response = eventService.updateEvent(eventId, user, request);
        return ResponseEntity.ok(ApiResponse.success("Event updated successfully", response));
    }

    @PostMapping("/{eventId}/publish")
    @Operation(summary = "Publish an event")
    public ResponseEntity<ApiResponse<EventResponse>> publishEvent(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        EventResponse response = eventService.publishEvent(eventId, user);
        return ResponseEntity.ok(ApiResponse.success("Event published successfully", response));
    }

    @PostMapping("/{eventId}/cancel")
    @Operation(summary = "Cancel an event")
    public ResponseEntity<ApiResponse<EventResponse>> cancelEvent(
            @PathVariable UUID eventId,
            @RequestParam(required = false) String reason,
            @RequestParam(required = false, defaultValue = "false") boolean cancelSeries,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        EventResponse response = eventService.cancelEvent(eventId, user, reason, cancelSeries);
        return ResponseEntity.ok(ApiResponse.success("Event cancelled successfully", response));
    }

    @DeleteMapping("/{eventId}")
    @Operation(summary = "Delete an event")
    public ResponseEntity<ApiResponse<Void>> deleteEvent(
            @PathVariable UUID eventId,
            @RequestParam(required = false, defaultValue = "false") boolean deleteSeries,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        eventService.deleteEventByOrganiser(eventId, user, deleteSeries);
        return ResponseEntity.ok(ApiResponse.success("Event deleted successfully", null));
    }

    @GetMapping("/{eventId}/export")
    @Operation(summary = "Export attendee list to Excel")
    public ResponseEntity<byte[]> exportAttendees(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails) throws IOException {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        subscriptionService.validateExcelExport(user.getId());

        byte[] excelData = excelExportService.exportEventRegistrations(eventId);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_OCTET_STREAM);
        headers.setContentDispositionFormData("attachment", "attendees_" + eventId + ".xlsx");

        return ResponseEntity.ok().headers(headers).body(excelData);
    }

    @PostMapping("/ai/generate-description")
    @Operation(summary = "Generate event description using AI")
    public ResponseEntity<ApiResponse<AIDescriptionResponse>> generateDescription(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody AIGenerateDescriptionRequest request) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        subscriptionService.validateAIUsage(user.getId());

        String description = aiService.generateEventDescription(
                request.getTitle(),
                request.getCategory(),
                request.getVenue(),
                request.getAddress(),
                request.getStartTime(),
                request.getEndTime()
        );

        subscriptionService.incrementAIUsage(user.getId());
        AIDescriptionResponse response = AIDescriptionResponse.builder()
                .description(description)
                .build();
        return ResponseEntity.ok(ApiResponse.success("Description generated", response));
    }

    @PostMapping("/ai/improve-description")
    @Operation(summary = "Improve event description using AI")
    public ResponseEntity<ApiResponse<AIDescriptionResponse>> improveDescription(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody AIImproveDescriptionRequest request) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        subscriptionService.validateAIUsage(user.getId());

        String description = aiService.improveEventDescription(
                request.getTitle(),
                request.getDescription()
        );

        subscriptionService.incrementAIUsage(user.getId());
        AIDescriptionResponse response = AIDescriptionResponse.builder()
                .description(description)
                .build();
        return ResponseEntity.ok(ApiResponse.success("Description improved", response));
    }

    @PostMapping("/ai/generate-speaker-bio")
    @Operation(summary = "Generate speaker bio using AI")
    public ResponseEntity<ApiResponse<AISpeakerBioResponse>> generateSpeakerBio(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody AIGenerateSpeakerBioRequest request) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        subscriptionService.validateAIUsage(user.getId());

        String bio = aiService.generateSpeakerBio(
                request.getName(),
                request.getTitle(),
                request.getEventTitle()
        );

        subscriptionService.incrementAIUsage(user.getId());
        AISpeakerBioResponse response = AISpeakerBioResponse.builder()
                .bio(bio)
                .build();
        return ResponseEntity.ok(ApiResponse.success("Speaker bio generated", response));
    }

    @PostMapping("/ai/generate-notification")
    @Operation(summary = "Generate notification message using AI")
    public ResponseEntity<ApiResponse<AINotificationResponse>> generateNotification(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody AIGenerateNotificationRequest request) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        subscriptionService.validateAIUsage(user.getId());

        String message = aiService.generateNotificationMessage(
                request.getEventTitle(),
                request.getNotificationType(),
                request.getAdditionalContext()
        );

        subscriptionService.incrementAIUsage(user.getId());
        AINotificationResponse response = AINotificationResponse.builder()
                .message(message)
                .build();
        return ResponseEntity.ok(ApiResponse.success("Notification generated", response));
    }

    @PostMapping("/ai/suggest-questions")
    @Operation(summary = "Suggest registration questions using AI")
    public ResponseEntity<ApiResponse<AIQuestionsResponse>> suggestQuestions(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody AIGenerateQuestionsRequest request) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        subscriptionService.validateAIUsage(user.getId());

        String jsonResponse = aiService.suggestRegistrationQuestions(
                request.getEventTitle(),
                request.getEventCategory(),
                request.getEventDescription(),
                request.getNumberOfQuestions()
        );

        subscriptionService.incrementAIUsage(user.getId());

        // Parse the JSON response
        try {
            ObjectMapper mapper = new ObjectMapper();
            // Clean up the response in case AI adds extra text
            String cleanJson = jsonResponse.trim();
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

            List<AIQuestionsResponse.SuggestedQuestion> questions = mapper.readValue(
                    cleanJson,
                    new TypeReference<List<AIQuestionsResponse.SuggestedQuestion>>() {}
            );

            AIQuestionsResponse response = AIQuestionsResponse.builder()
                    .questions(questions)
                    .build();
            return ResponseEntity.ok(ApiResponse.success("Questions suggested", response));
        } catch (Exception e) {
            throw new RuntimeException("Failed to parse AI response: " + e.getMessage());
        }
    }
}

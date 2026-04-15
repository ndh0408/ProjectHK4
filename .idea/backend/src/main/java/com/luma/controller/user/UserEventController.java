package com.luma.controller.user;

import com.luma.dto.request.QuestionRequest;
import com.luma.dto.request.RegistrationWithAnswersRequest;
import com.luma.dto.response.*;
import com.luma.entity.User;
import com.luma.service.*;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/user/events")
@RequiredArgsConstructor
@Tag(name = "User Events", description = "APIs for user event operations")
public class UserEventController {

    private final EventService eventService;
    private final RegistrationService registrationService;
    private final QuestionService questionService;
    private final UserService userService;
    private final CategoryService categoryService;
    private final CityService cityService;
    private final RegistrationQuestionService registrationQuestionService;
    private final FunnelAnalyticsService funnelAnalyticsService;

    @GetMapping("/upcoming")
    @Operation(summary = "Get upcoming events (next month)")
    public ResponseEntity<ApiResponse<PageResponse<EventResponse>>> getUpcomingEvents(
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(eventService.getUpcomingEvents(pageable)));
    }

    @GetMapping("/search")
    @Operation(summary = "Search events")
    public ResponseEntity<ApiResponse<PageResponse<EventResponse>>> searchEvents(
            @RequestParam String q,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(eventService.searchEvents(q, pageable)));
    }

    @GetMapping("/by-city/{cityId}")
    @Operation(summary = "Get events by city")
    public ResponseEntity<ApiResponse<PageResponse<EventResponse>>> getEventsByCity(
            @PathVariable Long cityId,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(eventService.getEventsByCity(cityId, pageable)));
    }

    @GetMapping("/by-category/{categoryId}")
    @Operation(summary = "Get events by category")
    public ResponseEntity<ApiResponse<PageResponse<EventResponse>>> getEventsByCategory(
            @PathVariable Long categoryId,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(eventService.getEventsByCategory(categoryId, pageable)));
    }

    @GetMapping("/by-country/{country}")
    @Operation(summary = "Get events by country (e.g., Vietnam)")
    public ResponseEntity<ApiResponse<PageResponse<EventResponse>>> getEventsByCountry(
            @PathVariable String country,
            @PageableDefault(size = 50) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(eventService.getEventsByCountry(country, pageable)));
    }

    @GetMapping("/by-speaker")
    @Operation(summary = "Get events by speaker name")
    public ResponseEntity<ApiResponse<PageResponse<EventResponse>>> getEventsBySpeaker(
            @RequestParam String name,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(eventService.getEventsBySpeaker(name, pageable)));
    }

    @GetMapping("/{eventId}")
    @Operation(summary = "Get event details")
    public ResponseEntity<ApiResponse<EventResponse>> getEventDetails(@PathVariable UUID eventId) {
        return ResponseEntity.ok(ApiResponse.success(eventService.getEventById(eventId)));
    }

    @GetMapping("/{eventId}/registration-questions")
    @Operation(summary = "Get registration questions for an event")
    public ResponseEntity<ApiResponse<List<RegistrationQuestionResponse>>> getRegistrationQuestions(
            @PathVariable UUID eventId) {
        List<RegistrationQuestionResponse> questions = registrationQuestionService.getQuestionsByEventId(eventId);
        return ResponseEntity.ok(ApiResponse.success(questions));
    }

    @GetMapping("/{eventId}/registration-status")
    @Operation(summary = "Check if user is registered for an event")
    public ResponseEntity<ApiResponse<RegistrationStatusResponse>> getRegistrationStatus(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        RegistrationStatusResponse response = registrationService.getRegistrationStatus(user, eventId);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/categories")
    @Operation(summary = "Get all categories")
    public ResponseEntity<ApiResponse<List<CategoryResponse>>> getCategories() {
        return ResponseEntity.ok(ApiResponse.success(categoryService.getAllCategories()));
    }

    @GetMapping("/cities")
    @Operation(summary = "Get cities with events")
    public ResponseEntity<ApiResponse<List<CityResponse>>> getCitiesWithEvents() {
        return ResponseEntity.ok(ApiResponse.success(cityService.getCitiesWithEvents()));
    }

    @PostMapping("/{eventId}/register")
    @Operation(summary = "Register for an event (without questions)")
    public ResponseEntity<ApiResponse<RegistrationResponse>> registerForEvent(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        RegistrationResponse response = registrationService.registerForEvent(user, eventId);
        return ResponseEntity.ok(ApiResponse.success("Registration successful", response));
    }

    @PostMapping("/{eventId}/register-with-answers")
    @Operation(summary = "Register for an event with question answers")
    public ResponseEntity<ApiResponse<RegistrationResponse>> registerForEventWithAnswers(
            @PathVariable UUID eventId,
            @RequestBody RegistrationWithAnswersRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        RegistrationResponse response = registrationService.registerForEventWithAnswers(user, eventId, request.getAnswers());
        return ResponseEntity.ok(ApiResponse.success("Registration successful", response));
    }

    @DeleteMapping("/registrations/{registrationId}")
    @Operation(summary = "Cancel registration")
    public ResponseEntity<ApiResponse<RegistrationResponse>> cancelRegistration(
            @PathVariable UUID registrationId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        RegistrationResponse response = registrationService.cancelRegistration(registrationId, user);
        return ResponseEntity.ok(ApiResponse.success("Registration cancelled successfully", response));
    }

    @GetMapping("/my-registrations/upcoming")
    @Operation(summary = "Get user upcoming registrations")
    public ResponseEntity<ApiResponse<PageResponse<RegistrationResponse>>> getUpcomingRegistrations(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(registrationService.getUserUpcomingRegistrations(user, pageable)));
    }

    @GetMapping("/my-registrations/past")
    @Operation(summary = "Get user past registrations")
    public ResponseEntity<ApiResponse<PageResponse<RegistrationResponse>>> getPastRegistrations(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(registrationService.getUserPastRegistrations(user, pageable)));
    }

    @PostMapping("/{eventId}/questions")
    @Operation(summary = "Ask a question about an event")
    public ResponseEntity<ApiResponse<QuestionResponse>> askQuestion(
            @PathVariable UUID eventId,
            @Valid @RequestBody QuestionRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        QuestionResponse response = questionService.createQuestion(user, eventId, request);
        return ResponseEntity.ok(ApiResponse.success("Question submitted successfully", response));
    }

    @GetMapping("/my-questions")
    @Operation(summary = "Get user questions")
    public ResponseEntity<ApiResponse<PageResponse<QuestionResponse>>> getMyQuestions(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(questionService.getUserQuestions(user, pageable)));
    }

    @PostMapping("/{eventId}/track-view")
    @Operation(summary = "Track event view for funnel analytics")
    public ResponseEntity<ApiResponse<Void>> trackEventView(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(required = false) String sessionId) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        com.luma.entity.Event event = eventService.getEntityById(eventId);
        funnelAnalyticsService.trackEventView(event, user, sessionId);
        return ResponseEntity.ok(ApiResponse.success("View tracked", null));
    }

}

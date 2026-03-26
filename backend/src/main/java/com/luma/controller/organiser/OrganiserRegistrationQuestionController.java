package com.luma.controller.organiser;

import com.luma.dto.request.RegistrationQuestionRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.RegistrationQuestionResponse;
import com.luma.entity.User;
import com.luma.service.RegistrationQuestionService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/organiser/events/{eventId}/registration-questions")
@RequiredArgsConstructor
@Tag(name = "Organiser Registration Questions", description = "APIs for managing event registration form questions")
public class OrganiserRegistrationQuestionController {

    private final RegistrationQuestionService questionService;
    private final UserService userService;

    @GetMapping
    @Operation(summary = "Get all registration questions for an event")
    public ResponseEntity<ApiResponse<List<RegistrationQuestionResponse>>> getQuestions(
            @PathVariable UUID eventId) {
        List<RegistrationQuestionResponse> questions = questionService.getQuestionsByEventId(eventId);
        return ResponseEntity.ok(ApiResponse.success(questions));
    }

    @PostMapping
    @Operation(summary = "Add a registration question to an event")
    public ResponseEntity<ApiResponse<RegistrationQuestionResponse>> addQuestion(
            @PathVariable UUID eventId,
            @Valid @RequestBody RegistrationQuestionRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        RegistrationQuestionResponse response = questionService.addQuestion(eventId, request, organiser);
        return ResponseEntity.ok(ApiResponse.success("Question added successfully", response));
    }

    @PostMapping("/batch")
    @Operation(summary = "Save all registration questions for an event (replaces existing)")
    public ResponseEntity<ApiResponse<List<RegistrationQuestionResponse>>> saveQuestions(
            @PathVariable UUID eventId,
            @Valid @RequestBody List<RegistrationQuestionRequest> requests,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        List<RegistrationQuestionResponse> questions = questionService.saveQuestions(eventId, requests, organiser);
        return ResponseEntity.ok(ApiResponse.success("Questions saved successfully", questions));
    }

    @PutMapping("/{questionId}")
    @Operation(summary = "Update a registration question")
    public ResponseEntity<ApiResponse<RegistrationQuestionResponse>> updateQuestion(
            @PathVariable UUID eventId,
            @PathVariable UUID questionId,
            @Valid @RequestBody RegistrationQuestionRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        RegistrationQuestionResponse response = questionService.updateQuestion(questionId, request, organiser);
        return ResponseEntity.ok(ApiResponse.success("Question updated successfully", response));
    }

    @DeleteMapping("/{questionId}")
    @Operation(summary = "Delete a registration question")
    public ResponseEntity<ApiResponse<Void>> deleteQuestion(
            @PathVariable UUID eventId,
            @PathVariable UUID questionId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        questionService.deleteQuestion(questionId, organiser);
        return ResponseEntity.ok(ApiResponse.success("Question deleted successfully", null));
    }
}

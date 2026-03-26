package com.luma.controller.organiser;

import com.luma.dto.request.AnswerRequest;
import com.luma.dto.response.AISuggestionResponse;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.PageResponse;
import com.luma.dto.response.QuestionResponse;
import com.luma.dto.response.SmartAnswerResponse;
import com.luma.entity.Question;
import com.luma.entity.User;
import com.luma.service.AIQueryService;
import com.luma.service.AIService;
import com.luma.service.QuestionService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/organiser/questions")
@RequiredArgsConstructor
@Tag(name = "Organiser Questions", description = "APIs for managing event questions")
public class OrganiserQuestionController {

    private final QuestionService questionService;
    private final UserService userService;
    private final AIService aiService;
    private final AIQueryService aiQueryService;

    @GetMapping("/event/{eventId}")
    @Operation(summary = "Get all questions for an event")
    public ResponseEntity<ApiResponse<PageResponse<QuestionResponse>>> getQuestionsByEvent(
            @PathVariable UUID eventId,
            @PageableDefault(size = 20) Pageable pageable) {
        PageResponse<QuestionResponse> response = questionService.getQuestionsByEvent(eventId, pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping
    @Operation(summary = "Get all questions for organiser's events")
    public ResponseEntity<ApiResponse<PageResponse<QuestionResponse>>> getMyQuestions(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        PageResponse<QuestionResponse> response = questionService.getQuestionsByOrganiser(organiser, pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/unanswered")
    @Operation(summary = "Get unanswered questions for organiser's events")
    public ResponseEntity<ApiResponse<PageResponse<QuestionResponse>>> getUnansweredQuestions(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        PageResponse<QuestionResponse> response = questionService.getUnansweredQuestionsByOrganiser(organiser, pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/answered")
    @Operation(summary = "Get answered questions for organiser's events")
    public ResponseEntity<ApiResponse<PageResponse<QuestionResponse>>> getAnsweredQuestions(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        PageResponse<QuestionResponse> response = questionService.getAnsweredQuestionsByOrganiser(organiser, pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/stats")
    @Operation(summary = "Get question statistics for organiser")
    public ResponseEntity<ApiResponse<java.util.Map<String, Long>>> getQuestionStats(
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        java.util.Map<String, Long> stats = new java.util.HashMap<>();
        stats.put("total", questionService.countQuestionsByOrganiser(organiser));
        stats.put("unanswered", questionService.countUnansweredByOrganiser(organiser));
        stats.put("answered", questionService.countAnsweredByOrganiser(organiser));
        return ResponseEntity.ok(ApiResponse.success(stats));
    }

    @PostMapping("/{questionId}/answer")
    @Operation(summary = "Answer a question")
    public ResponseEntity<ApiResponse<QuestionResponse>> answerQuestion(
            @PathVariable UUID questionId,
            @RequestBody AnswerRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        QuestionResponse response = questionService.answerQuestion(questionId, organiser, request);
        return ResponseEntity.ok(ApiResponse.success("Answer submitted successfully", response));
    }

    @GetMapping("/{questionId}/ai-suggest")
    @Operation(summary = "Get AI-suggested answer for a question (basic)")
    public ResponseEntity<ApiResponse<AISuggestionResponse>> getAISuggestion(
            @PathVariable UUID questionId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        Question question = questionService.getEntityByIdWithEventAndUser(questionId);

        if (!question.getEvent().getOrganiser().getId().equals(organiser.getId())) {
            return ResponseEntity.badRequest()
                    .body(ApiResponse.error("You do not have permission to access this question"));
        }

        String suggestedAnswer = aiService.suggestAnswer(question);

        AISuggestionResponse response = AISuggestionResponse.builder()
                .questionId(questionId.toString())
                .suggestedAnswer(suggestedAnswer)
                .build();

        return ResponseEntity.ok(ApiResponse.success("AI suggestion generated", response));
    }

    @GetMapping("/{questionId}/smart-suggest")
    @Operation(summary = "Get smart AI-suggested answer with FAQ context from database")
    public ResponseEntity<ApiResponse<SmartAnswerResponse>> getSmartAISuggestion(
            @PathVariable UUID questionId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        Question question = questionService.getEntityByIdWithEventAndUser(questionId);

        if (!question.getEvent().getOrganiser().getId().equals(organiser.getId())) {
            return ResponseEntity.badRequest()
                    .body(ApiResponse.error("You do not have permission to access this question"));
        }

        java.util.Map<String, Object> result = aiQueryService.suggestAnswerWithContext(question);

        SmartAnswerResponse response = SmartAnswerResponse.builder()
                .questionId(questionId.toString())
                .suggestedAnswer((String) result.get("suggestedAnswer"))
                .similarQuestionsFound((Integer) result.getOrDefault("similarQuestionsFound", 0))
                .eventFAQsCount((Integer) result.getOrDefault("eventFAQsCount", 0))
                .contextUsed((Boolean) result.getOrDefault("contextUsed", false))
                .build();

        // Add similar questions if available
        if (result.containsKey("similarQuestions")) {
            java.util.List<java.util.Map<String, String>> similar =
                    (java.util.List<java.util.Map<String, String>>) result.get("similarQuestions");
            java.util.List<SmartAnswerResponse.SimilarQuestion> similarList = similar.stream()
                    .map(sq -> SmartAnswerResponse.SimilarQuestion.builder()
                            .question(sq.get("question"))
                            .answer(sq.get("answer"))
                            .build())
                    .collect(java.util.stream.Collectors.toList());
            response.setSimilarQuestions(similarList);
        }

        return ResponseEntity.ok(ApiResponse.success("Smart AI suggestion generated with FAQ context", response));
    }

    @DeleteMapping("/{questionId}")
    @Operation(summary = "Delete a question")
    public ResponseEntity<ApiResponse<Void>> deleteQuestion(
            @PathVariable UUID questionId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        questionService.deleteQuestion(questionId, organiser);
        return ResponseEntity.ok(ApiResponse.success("Question deleted successfully", null));
    }
}

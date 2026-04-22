package com.luma.controller.organiser;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.luma.dto.request.CreatePollRequest;
import com.luma.dto.request.GeneratePollRequest;
import com.luma.dto.response.AIGeneratedPollResponse;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.PollResponse;
import com.luma.entity.User;
import com.luma.service.AIService;
import com.luma.service.PollService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/organiser/polls")
@RequiredArgsConstructor
@Tag(name = "Organiser Polls", description = "APIs for managing event polls")
@Slf4j
public class OrganiserPollController {

    private final PollService pollService;
    private final UserService userService;
    private final AIService aiService;

    @PostMapping("/event/{eventId}")
    @Operation(summary = "Create a poll for an event")
    public ResponseEntity<ApiResponse<PollResponse>> createPoll(
            @PathVariable UUID eventId,
            @Valid @RequestBody CreatePollRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        log.info("=== Creating poll for event: {} ===", eventId);
        log.info("Poll request: question='{}', type={}", request.getQuestion(), request.getType());
        User user = userService.getEntityByEmail(userDetails.getUsername());
        log.info("User: {}", user.getEmail());
        PollResponse response = pollService.createPoll(eventId, request, user);
        log.info("=== Poll created successfully: {} ===", response.getId());
        return ResponseEntity.ok(ApiResponse.success("Poll created successfully", response));
    }

    @GetMapping("/event/{eventId}")
    @Operation(summary = "Get all polls for an event")
    public ResponseEntity<ApiResponse<List<PollResponse>>> getEventPolls(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails) {
        log.info("=== Getting polls for event: {} ===", eventId);
        User user = userService.getEntityByEmail(userDetails.getUsername());
        List<PollResponse> polls = pollService.getEventPolls(eventId, user);
        log.info("=== Found {} polls for event {} ===", polls.size(), eventId);
        return ResponseEntity.ok(ApiResponse.success(polls));
    }

    @PutMapping("/{pollId}")
    @Operation(summary = "Update a poll")
    public ResponseEntity<ApiResponse<PollResponse>> updatePoll(
            @PathVariable UUID pollId,
            @Valid @RequestBody CreatePollRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        PollResponse response = pollService.updatePoll(pollId, request, user);
        return ResponseEntity.ok(ApiResponse.success("Poll updated successfully", response));
    }

    @DeleteMapping("/{pollId}")
    @Operation(summary = "Delete a poll")
    public ResponseEntity<ApiResponse<Void>> deletePoll(
            @PathVariable UUID pollId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        pollService.deletePoll(pollId, user);
        return ResponseEntity.ok(ApiResponse.success("Poll deleted successfully", null));
    }

    @PostMapping("/{pollId}/publish")
    @Operation(summary = "Publish a draft poll (DRAFT → SCHEDULED/ACTIVE)")
    public ResponseEntity<ApiResponse<PollResponse>> publishPoll(
            @PathVariable UUID pollId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        PollResponse response = pollService.publishPoll(pollId, user);
        return ResponseEntity.ok(ApiResponse.success("Poll published successfully", response));
    }

    @PostMapping("/{pollId}/schedule")
    @Operation(summary = "Schedule poll to open at specific time (DRAFT → SCHEDULED)")
    public ResponseEntity<ApiResponse<PollResponse>> schedulePoll(
            @PathVariable UUID pollId,
            @RequestParam String openAt,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        LocalDateTime scheduledTime = LocalDateTime.parse(openAt);
        PollResponse response = pollService.schedulePoll(pollId, scheduledTime, user);
        return ResponseEntity.ok(ApiResponse.success("Poll scheduled successfully", response));
    }

    @PostMapping("/{pollId}/open")
    @Operation(summary = "Open a scheduled poll immediately (SCHEDULED → ACTIVE)")
    public ResponseEntity<ApiResponse<PollResponse>> openPoll(
            @PathVariable UUID pollId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        PollResponse response = pollService.openPoll(pollId, user);
        return ResponseEntity.ok(ApiResponse.success("Poll opened", response));
    }

    @PostMapping("/{pollId}/close")
    @Operation(summary = "Close an active poll (ACTIVE → CLOSED)")
    public ResponseEntity<ApiResponse<PollResponse>> closePoll(
            @PathVariable UUID pollId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        PollResponse response = pollService.closePoll(pollId, user);
        return ResponseEntity.ok(ApiResponse.success("Poll closed", response));
    }

    @PostMapping("/{pollId}/reopen")
    @Operation(summary = "Reopen a closed poll (CLOSED → ACTIVE)")
    public ResponseEntity<ApiResponse<PollResponse>> reopenPoll(
            @PathVariable UUID pollId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        PollResponse response = pollService.reopenPoll(pollId, user);
        return ResponseEntity.ok(ApiResponse.success("Poll reopened", response));
    }

    @PostMapping("/{pollId}/cancel")
    @Operation(summary = "Cancel a draft or scheduled poll")
    public ResponseEntity<ApiResponse<PollResponse>> cancelPoll(
            @PathVariable UUID pollId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        PollResponse response = pollService.cancelPoll(pollId, user);
        return ResponseEntity.ok(ApiResponse.success("Poll cancelled", response));
    }

    @PostMapping("/{pollId}/extend")
    @Operation(summary = "Extend poll closing time")
    public ResponseEntity<ApiResponse<PollResponse>> extendPoll(
            @PathVariable UUID pollId,
            @RequestParam(required = false) Integer hours,
            @RequestParam(required = false) Integer days,
            @RequestParam(required = false) String customTime,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        PollResponse response = pollService.extendPoll(pollId, hours, days, customTime, user);
        return ResponseEntity.ok(ApiResponse.success("Poll extended successfully", response));
    }

    @PostMapping("/ai/generate")
    @Operation(summary = "Generate poll questions using AI (OpenAI ChatGPT)")
    public ResponseEntity<ApiResponse<Object>> generatePoll(
            @Valid @RequestBody GeneratePollRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        try {
            User user = userService.getEntityByEmail(userDetails.getUsername());

            log.info("Generating poll with topic: {} for user: {}", request.getTopic(), user.getEmail());

            // Validate request
            if (request.getTopic() == null || request.getTopic().trim().isEmpty()) {
                return ResponseEntity.badRequest()
                    .body(ApiResponse.error("Topic is required"));
            }

            // Set defaults
            Integer numOptions = request.getNumOptions() != null ? request.getNumOptions() : 4;
            String pollType = request.getPollType() != null ? request.getPollType() : "SINGLE_CHOICE";
            Integer maxRating = request.getMaxRating() != null ? request.getMaxRating() : 5;
            Integer numberOfQuestions = request.getNumberOfQuestions() != null ? request.getNumberOfQuestions() : 1;
            String language = request.getLanguage() != null ? request.getLanguage() : "English";

            // Validate values
            if (numOptions < 2 || numOptions > 10) {
                return ResponseEntity.badRequest()
                    .body(ApiResponse.error("Number of options must be between 2 and 10"));
            }

            if (numberOfQuestions < 1 || numberOfQuestions > 5) {
                return ResponseEntity.badRequest()
                    .body(ApiResponse.error("Number of questions must be between 1 and 5"));
            }

            // Call AI service
            String aiResponse = aiService.generatePoll(
                request.getTopic(),
                numOptions,
                pollType,
                maxRating,
                numberOfQuestions,
                language,
                request.getAdditionalContext()
            );

            log.info("AI generated poll successfully");

            // Parse JSON response from AI
            ObjectMapper objectMapper = new ObjectMapper();
            Object parsedResponse;
            try {
                // Clean up the response - remove markdown code blocks if present
                String cleanedResponse = aiResponse
                    .replaceAll("```json\\n?", "")
                    .replaceAll("\\n?```", "")
                    .trim();

                JsonNode jsonNode = objectMapper.readTree(cleanedResponse);

                // If it's an array, convert to List of AIGeneratedPollResponse
                if (jsonNode.isArray()) {
                    List<AIGeneratedPollResponse> polls = new ArrayList<>();
                    for (JsonNode node : jsonNode) {
                        AIGeneratedPollResponse poll = objectMapper.treeToValue(node, AIGeneratedPollResponse.class);
                        polls.add(poll);
                    }
                    parsedResponse = polls;
                } else {
                    // Single object response
                    parsedResponse = objectMapper.treeToValue(jsonNode, AIGeneratedPollResponse.class);
                }
            } catch (Exception e) {
                log.error("Failed to parse AI response: {}", aiResponse, e);
                return ResponseEntity.internalServerError()
                    .body(ApiResponse.error("Failed to parse AI response: " + e.getMessage()));
            }

            // Return parsed response
            return ResponseEntity.ok(ApiResponse.success("Poll generated successfully",
                parsedResponse));

        } catch (Exception e) {
            log.error("Error generating poll with AI", e);
            return ResponseEntity.internalServerError()
                .body(ApiResponse.error("Failed to generate poll: " + e.getMessage()));
        }
    }
}

package com.luma.controller.organiser;

import com.luma.dto.response.ApiResponse;
import com.luma.exception.BadRequestException;
import com.luma.service.AISmartContentService;
import com.luma.service.AISmartPricingService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/organiser/ai-smart")
@RequiredArgsConstructor
@Tag(name = "Organiser Smart AI", description = "RAG-enhanced AI features with internal data")
public class OrganiserAISmartController {

    private final AISmartContentService smartContentService;
    private final AISmartPricingService smartPricingService;
    private final UserService userService;

    @PostMapping("/description-rag")
    @Operation(summary = "Generate event description using RAG (learn from top events)")
    public ResponseEntity<ApiResponse<Map<String, Object>>> generateDescriptionRAG(
            @RequestBody Map<String, Object> body,
            @AuthenticationPrincipal UserDetails userDetails) {
        requireAuth(userDetails);
        requireBody(body);

        String title = getString(body, "title");
        if (title == null || title.isBlank()) {
            throw new BadRequestException("title is required");
        }
        Long categoryId = getLong(body, "categoryId");
        String venue = getString(body, "venue");
        String address = getString(body, "address");
        String startTime = getString(body, "startTime");
        String endTime = getString(body, "endTime");
        String currentDescription = getString(body, "currentDescription");

        Map<String, Object> result = smartContentService.generateEventDescriptionWithRAG(
                title, categoryId, venue, address, startTime, endTime, currentDescription);
        return ResponseEntity.ok(ApiResponse.success(result));
    }

    @PostMapping("/questions-rag")
    @Operation(summary = "Suggest registration questions using RAG (learn from similar events)")
    public ResponseEntity<ApiResponse<Map<String, Object>>> suggestQuestionsRAG(
            @RequestBody Map<String, Object> body,
            @AuthenticationPrincipal UserDetails userDetails) {
        requireAuth(userDetails);
        requireBody(body);

        String eventTitle = getString(body, "eventTitle");
        if (eventTitle == null || eventTitle.isBlank()) {
            throw new BadRequestException("eventTitle is required");
        }
        Long categoryId = getLong(body, "categoryId");
        String description = getString(body, "eventDescription");
        Integer numberOfQuestions = getInteger(body, "numberOfQuestions");
        if (numberOfQuestions == null || numberOfQuestions <= 0) numberOfQuestions = 5;
        if (numberOfQuestions > 20) numberOfQuestions = 20;

        Map<String, Object> result = smartContentService.suggestRegistrationQuestionsWithRAG(
                eventTitle, categoryId, description, numberOfQuestions);
        return ResponseEntity.ok(ApiResponse.success(result));
    }

    @PostMapping("/pricing-suggestion")
    @Operation(summary = "AI Smart Pricing — analyze similar events to suggest optimal pricing")
    public ResponseEntity<ApiResponse<Map<String, Object>>> suggestPricing(
            @RequestBody Map<String, Object> body,
            @AuthenticationPrincipal UserDetails userDetails) {
        requireAuth(userDetails);
        requireBody(body);

        Long categoryId = getLong(body, "categoryId");
        if (categoryId == null) {
            throw new BadRequestException("categoryId is required for pricing analysis");
        }
        Integer capacity = getInteger(body, "capacity");
        String eventType = getString(body, "eventType");

        Map<String, Object> result = smartPricingService.suggestPricing(categoryId, capacity, eventType);
        return ResponseEntity.ok(ApiResponse.success(result));
    }

    private void requireAuth(UserDetails userDetails) {
        if (userDetails == null || userDetails.getUsername() == null) {
            throw new BadRequestException("Authentication required");
        }
        userService.getEntityByEmail(userDetails.getUsername());
    }

    private void requireBody(Map<String, Object> body) {
        if (body == null) {
            throw new BadRequestException("Request body is required");
        }
    }

    private String getString(Map<String, Object> body, String key) {
        Object v = body.get(key);
        return v != null ? v.toString() : null;
    }

    private Long getLong(Map<String, Object> body, String key) {
        Object v = body.get(key);
        if (v == null) return null;
        if (v instanceof Number n) return n.longValue();
        try {
            return Long.valueOf(v.toString());
        } catch (NumberFormatException e) {
            throw new BadRequestException(key + " must be a valid number");
        }
    }

    private Integer getInteger(Map<String, Object> body, String key) {
        Object v = body.get(key);
        if (v == null) return null;
        if (v instanceof Number n) return n.intValue();
        try {
            return Integer.valueOf(v.toString());
        } catch (NumberFormatException e) {
            throw new BadRequestException(key + " must be a valid integer");
        }
    }
}

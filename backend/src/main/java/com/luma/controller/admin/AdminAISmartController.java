package com.luma.controller.admin;

import com.luma.dto.response.ApiResponse;
import com.luma.entity.Event;
import com.luma.repository.EventRepository;
import com.luma.service.AISmartContentService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin/ai-smart")
@RequiredArgsConstructor
@Tag(name = "Admin Smart AI", description = "RAG-enhanced AI moderation with historical data")
public class AdminAISmartController {

    private final AISmartContentService smartContentService;
    private final EventRepository eventRepository;

    @PostMapping("/moderate-event-rag/{eventId}")
    @Operation(summary = "AI moderation with RAG (compares with past approved/rejected events)")
    @Transactional(readOnly = true)
    public ResponseEntity<ApiResponse<Map<String, Object>>> moderateEventRAG(
            @PathVariable UUID eventId) {
        Event event = eventRepository.findByIdWithBasicRelationships(eventId)
                .orElseThrow(() -> new com.luma.exception.ResourceNotFoundException("Event not found"));

        String organiserName = event.getOrganiser() != null ? event.getOrganiser().getFullName() : "Unknown";
        String categoryName = event.getCategory() != null ? event.getCategory().getName() : null;
        Long categoryId = event.getCategory() != null ? event.getCategory().getId() : null;

        Map<String, Object> result = smartContentService.analyzeEventForModerationWithRAG(
                event.getTitle(),
                event.getDescription(),
                organiserName,
                categoryName,
                categoryId,
                event.getVenue(),
                event.getStartTime() != null ? event.getStartTime().toString() : null,
                event.getCapacity(),
                event.getTicketPrice()
        );
        return ResponseEntity.ok(ApiResponse.success(result));
    }
}

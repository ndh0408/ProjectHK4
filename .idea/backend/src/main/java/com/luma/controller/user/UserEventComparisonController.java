package com.luma.controller.user;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.EventComparisonResponse;
import com.luma.service.EventComparisonService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/user/event-comparison")
@RequiredArgsConstructor
@Tag(name = "Event Comparison", description = "Compare multiple events")
public class UserEventComparisonController {

    private final EventComparisonService comparisonService;

    @GetMapping("/compare")
    @Operation(summary = "Compare 2-4 events side by side")
    public ResponseEntity<ApiResponse<EventComparisonResponse>> compareEvents(
            @RequestParam List<UUID> eventIds) {
        EventComparisonResponse response = comparisonService.compareEvents(eventIds);
        return ResponseEntity.ok(ApiResponse.success(response));
    }
}

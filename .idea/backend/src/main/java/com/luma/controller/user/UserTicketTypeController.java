package com.luma.controller.user;

import com.luma.dto.response.TicketTypeResponse;
import com.luma.service.TicketTypeService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/user/events/{eventId}/ticket-types")
@RequiredArgsConstructor
@Tag(name = "User - Ticket Types", description = "APIs for users to view available ticket types")
public class UserTicketTypeController {

    private final TicketTypeService ticketTypeService;

    @GetMapping
    @Operation(summary = "Get available ticket types for an event")
    public ResponseEntity<List<TicketTypeResponse>> getAvailableTicketTypes(@PathVariable UUID eventId) {
        List<TicketTypeResponse> ticketTypes = ticketTypeService.getAvailableTicketTypesByEventId(eventId);
        return ResponseEntity.ok(ticketTypes);
    }

    @GetMapping("/{ticketTypeId}")
    @Operation(summary = "Get ticket type details")
    public ResponseEntity<TicketTypeResponse> getTicketType(
            @PathVariable UUID eventId,
            @PathVariable UUID ticketTypeId) {
        TicketTypeResponse ticketType = ticketTypeService.getTicketTypeById(ticketTypeId);
        return ResponseEntity.ok(ticketType);
    }
}

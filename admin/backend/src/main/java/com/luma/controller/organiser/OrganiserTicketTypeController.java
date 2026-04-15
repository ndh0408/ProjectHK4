package com.luma.controller.organiser;

import com.luma.dto.request.TicketTypeRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.TicketTypeResponse;
import com.luma.entity.User;
import com.luma.service.TicketTypeService;
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
@RequestMapping("/api/organiser/events/{eventId}/ticket-types")
@RequiredArgsConstructor
@Tag(name = "Organiser Ticket Types", description = "APIs for managing event ticket types")
public class OrganiserTicketTypeController {

    private final TicketTypeService ticketTypeService;
    private final UserService userService;

    @GetMapping
    @Operation(summary = "Get all ticket types for an event")
    public ResponseEntity<ApiResponse<List<TicketTypeResponse>>> getTicketTypes(
            @PathVariable UUID eventId) {
        List<TicketTypeResponse> ticketTypes = ticketTypeService.getTicketTypesByEventId(eventId);
        return ResponseEntity.ok(ApiResponse.success(ticketTypes));
    }

    @GetMapping("/{ticketTypeId}")
    @Operation(summary = "Get a specific ticket type")
    public ResponseEntity<ApiResponse<TicketTypeResponse>> getTicketType(
            @PathVariable UUID eventId,
            @PathVariable UUID ticketTypeId) {
        TicketTypeResponse ticketType = ticketTypeService.getTicketTypeById(ticketTypeId);
        return ResponseEntity.ok(ApiResponse.success(ticketType));
    }

    @PostMapping
    @Operation(summary = "Create a new ticket type for an event")
    public ResponseEntity<ApiResponse<TicketTypeResponse>> createTicketType(
            @PathVariable UUID eventId,
            @Valid @RequestBody TicketTypeRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        TicketTypeResponse response = ticketTypeService.createTicketType(eventId, request, organiser);
        return ResponseEntity.ok(ApiResponse.success("Ticket type created successfully", response));
    }

    @PutMapping("/{ticketTypeId}")
    @Operation(summary = "Update a ticket type")
    public ResponseEntity<ApiResponse<TicketTypeResponse>> updateTicketType(
            @PathVariable UUID eventId,
            @PathVariable UUID ticketTypeId,
            @Valid @RequestBody TicketTypeRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        TicketTypeResponse response = ticketTypeService.updateTicketType(ticketTypeId, request, organiser);
        return ResponseEntity.ok(ApiResponse.success("Ticket type updated successfully", response));
    }

    @DeleteMapping("/{ticketTypeId}")
    @Operation(summary = "Delete a ticket type")
    public ResponseEntity<ApiResponse<Void>> deleteTicketType(
            @PathVariable UUID eventId,
            @PathVariable UUID ticketTypeId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        ticketTypeService.deleteTicketType(ticketTypeId, organiser);
        return ResponseEntity.ok(ApiResponse.success("Ticket type deleted successfully", null));
    }

    @PatchMapping("/{ticketTypeId}/toggle-visibility")
    @Operation(summary = "Toggle visibility of a ticket type")
    public ResponseEntity<ApiResponse<TicketTypeResponse>> toggleVisibility(
            @PathVariable UUID eventId,
            @PathVariable UUID ticketTypeId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        TicketTypeResponse response = ticketTypeService.toggleVisibility(ticketTypeId, organiser);
        return ResponseEntity.ok(ApiResponse.success("Visibility toggled successfully", response));
    }

    @PutMapping("/reorder")
    @Operation(summary = "Reorder ticket types for an event")
    public ResponseEntity<ApiResponse<List<TicketTypeResponse>>> reorderTicketTypes(
            @PathVariable UUID eventId,
            @RequestBody List<UUID> ticketTypeIds,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        List<TicketTypeResponse> response = ticketTypeService.reorderTicketTypes(eventId, ticketTypeIds, organiser);
        return ResponseEntity.ok(ApiResponse.success("Ticket types reordered successfully", response));
    }

    @GetMapping("/stats")
    @Operation(summary = "Get ticket type statistics for an event")
    public ResponseEntity<ApiResponse<TicketTypeService.TicketTypeStats>> getStats(
            @PathVariable UUID eventId) {
        TicketTypeService.TicketTypeStats stats = ticketTypeService.getTicketTypeStats(eventId);
        return ResponseEntity.ok(ApiResponse.success(stats));
    }
}

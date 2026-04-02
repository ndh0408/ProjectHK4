package com.luma.controller.organiser;

import com.luma.dto.response.*;
import com.luma.entity.CommissionTransaction;
import com.luma.entity.Event;
import com.luma.entity.User;
import com.luma.exception.BadRequestException;
import com.luma.repository.EventRepository;
import com.luma.service.CommissionService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/organiser/revenue")
@RequiredArgsConstructor
@Tag(name = "Organiser Revenue", description = "APIs for organiser revenue and commission tracking")
public class OrganiserRevenueController {

    private final CommissionService commissionService;
    private final UserService userService;
    private final EventRepository eventRepository;

    @GetMapping("/stats")
    @Operation(summary = "Get revenue statistics for current organiser")
    public ResponseEntity<ApiResponse<OrganiserStatsResponse>> getRevenueStats(
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        CommissionService.OrganiserRevenueStats stats = commissionService.getOrganiserStats(organiser.getId());
        return ResponseEntity.ok(ApiResponse.success(OrganiserStatsResponse.fromStats(stats)));
    }

    @GetMapping("/commission-rate")
    @Operation(summary = "Get current commission rate for organiser")
    public ResponseEntity<ApiResponse<BigDecimal>> getCurrentCommissionRate(
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        BigDecimal rate = commissionService.getCommissionRateForOrganiser(organiser.getId());
        return ResponseEntity.ok(ApiResponse.success(rate));
    }

    @GetMapping("/transactions")
    @Operation(summary = "Get commission transactions for current organiser")
    public ResponseEntity<ApiResponse<PageResponse<CommissionTransactionResponse>>> getTransactions(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        Page<CommissionTransaction> page = commissionService.getOrganiserTransactions(organiser.getId(), pageable);
        return ResponseEntity.ok(ApiResponse.success(PageResponse.from(page, CommissionTransactionResponse::fromEntity)));
    }

    @GetMapping("/event/{eventId}")
    @Operation(summary = "Get revenue statistics for a specific event")
    public ResponseEntity<ApiResponse<EventRevenueResponse>> getEventRevenue(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID eventId) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());

        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new BadRequestException("Event not found"));

        if (!event.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You don't have permission to view this event's revenue");
        }

        CommissionService.EventRevenueStats stats = commissionService.getEventRevenueStats(eventId);
        return ResponseEntity.ok(ApiResponse.success(
                EventRevenueResponse.fromStats(stats, eventId, event.getTitle())));
    }

    @GetMapping("/event/{eventId}/transactions")
    @Operation(summary = "Get commission transactions for a specific event")
    public ResponseEntity<ApiResponse<List<CommissionTransactionResponse>>> getEventTransactions(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID eventId) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());

        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new BadRequestException("Event not found"));

        if (!event.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You don't have permission to view this event's transactions");
        }

        List<CommissionTransaction> transactions = commissionService.getEventTransactions(eventId);
        List<CommissionTransactionResponse> response = transactions.stream()
                .map(CommissionTransactionResponse::fromEntity)
                .toList();
        return ResponseEntity.ok(ApiResponse.success(response));
    }
}

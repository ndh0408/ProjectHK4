package com.luma.controller.user;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.PageResponse;
import com.luma.dto.response.TicketTransferResponse;
import com.luma.entity.User;
import com.luma.service.TicketTransferService;
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

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/user/transfers")
@RequiredArgsConstructor
@Tag(name = "Ticket Transfer", description = "APIs for ticket transfer and resale")
public class UserTicketTransferController {

    private final TicketTransferService transferService;
    private final UserService userService;

    @PostMapping("/{registrationId}/transfer")
    @Operation(summary = "Transfer ticket to another user")
    public ResponseEntity<ApiResponse<TicketTransferResponse>> transferTicket(
            @PathVariable UUID registrationId,
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        String toEmail = body != null ? body.get("toEmail") : null;
        if (toEmail == null || toEmail.isBlank()) {
            throw new com.luma.exception.BadRequestException("Recipient email is required");
        }
        return ResponseEntity.ok(ApiResponse.success("Transfer initiated",
                transferService.initiateTransfer(registrationId, toEmail, user)));
    }

    @PostMapping("/{registrationId}/resale")
    @Operation(summary = "List ticket for resale")
    public ResponseEntity<ApiResponse<TicketTransferResponse>> listForResale(
            @PathVariable UUID registrationId,
            @RequestBody Map<String, Object> body,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        if (body == null || body.get("resalePrice") == null) {
            throw new com.luma.exception.BadRequestException("Resale price is required");
        }
        BigDecimal price = new BigDecimal(body.get("resalePrice").toString());
        return ResponseEntity.ok(ApiResponse.success("Listed for resale",
                transferService.listForResale(registrationId, price, user)));
    }

    @PostMapping("/{transferId}/accept")
    @Operation(summary = "Accept a transfer or buy resale ticket")
    public ResponseEntity<ApiResponse<TicketTransferResponse>> acceptTransfer(
            @PathVariable UUID transferId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success("Transfer accepted",
                transferService.acceptTransfer(transferId, user)));
    }

    @PostMapping("/{transferId}/decline")
    @Operation(summary = "Decline a transfer")
    public ResponseEntity<ApiResponse<TicketTransferResponse>> declineTransfer(
            @PathVariable UUID transferId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success("Transfer declined",
                transferService.declineTransfer(transferId, user)));
    }

    @GetMapping("/event/{eventId}/resale")
    @Operation(summary = "Get resale listings for an event")
    public ResponseEntity<ApiResponse<List<TicketTransferResponse>>> getResaleListings(
            @PathVariable UUID eventId) {
        return ResponseEntity.ok(ApiResponse.success(transferService.getResaleListings(eventId)));
    }

    @GetMapping("/my-transfers")
    @Operation(summary = "Get my transfer history")
    public ResponseEntity<ApiResponse<PageResponse<TicketTransferResponse>>> getMyTransfers(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(transferService.getMyTransfers(user, pageable)));
    }
}

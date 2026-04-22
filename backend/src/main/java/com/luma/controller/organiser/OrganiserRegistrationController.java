package com.luma.controller.organiser;

import com.luma.dto.request.RefundRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.PageResponse;
import com.luma.dto.response.PaymentResponse;
import com.luma.dto.response.RegistrationAnswerResponse;
import com.luma.dto.response.RegistrationResponse;
import com.luma.entity.Event;
import com.luma.entity.Registration;
import com.luma.entity.RegistrationAnswer;
import com.luma.entity.User;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.repository.RegistrationAnswerRepository;
import com.luma.repository.RegistrationRepository;
import com.luma.dto.response.WaitlistOfferResponse;
import com.luma.service.EventService;
import com.luma.service.ExcelExportService;
import com.luma.service.PaymentService;
import com.luma.service.RegistrationService;
import com.luma.service.UserService;
import com.luma.service.WaitlistService;
import com.luma.service.RegistrationReviewService;
import jakarta.validation.Valid;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/organiser")
@RequiredArgsConstructor
@Tag(name = "Organiser Registrations", description = "APIs for managing event registrations")
public class OrganiserRegistrationController {

    private final RegistrationService registrationService;
    private final EventService eventService;
    private final UserService userService;
    private final ExcelExportService excelExportService;
    private final PaymentService paymentService;
    private final RegistrationAnswerRepository registrationAnswerRepository;
    private final WaitlistService waitlistService;
    private final RegistrationReviewService registrationReviewService;
    private final RegistrationRepository registrationRepository;

    @GetMapping("/registrations/event/{eventId}")
    @Operation(summary = "Get all registrations for an event")
    public ResponseEntity<ApiResponse<PageResponse<RegistrationResponse>>> getRegistrationsByEvent(
            @PathVariable UUID eventId,
            @RequestParam(required = false) RegistrationStatus status,
            @PageableDefault(size = 20) Pageable pageable) {
        Event event = eventService.getEntityById(eventId);
        PageResponse<RegistrationResponse> response;
        if (status != null) {
            response = registrationService.getRegistrationsByEventAndStatus(event, status, pageable);
        } else {
            response = registrationService.getRegistrationsByEvent(event, pageable);
        }
        // Enrich registrations with review data (score, warnings, etc.)
        var enrichedContent = response.getContent().stream()
                .map(reg -> {
                    Registration fullReg = registrationRepository.findById(reg.getId()).orElse(null);
                    return registrationReviewService.enrichWithReviewData(reg, fullReg);
                })
                .toList();
        var enrichedResponse = PageResponse.of(enrichedContent, response.getPage(), response.getSize(), response.getTotalElements());
        return ResponseEntity.ok(ApiResponse.success(enrichedResponse));
    }

    @GetMapping("/events/{eventId}/registrations")
    @Operation(summary = "Get all registrations for an event (alternative)")
    public ResponseEntity<ApiResponse<PageResponse<RegistrationResponse>>> getRegistrations(
            @PathVariable UUID eventId,
            @RequestParam(required = false) RegistrationStatus status,
            @PageableDefault(size = 20) Pageable pageable) {
        return getRegistrationsByEvent(eventId, status, pageable);
    }

    @GetMapping("/events/{eventId}/registrations/waiting-list")
    @Operation(summary = "Get waiting list for an event")
    public ResponseEntity<ApiResponse<List<RegistrationResponse>>> getWaitingList(@PathVariable UUID eventId) {
        Event event = eventService.getEntityById(eventId);
        List<RegistrationResponse> waitingList = registrationService.getWaitingList(event);
        // Enrich with review data
        var enrichedList = waitingList.stream()
                .map(reg -> {
                    Registration fullReg = registrationRepository.findById(reg.getId()).orElse(null);
                    return registrationReviewService.enrichWithReviewData(reg, fullReg);
                })
                .toList();
        return ResponseEntity.ok(ApiResponse.success(enrichedList));
    }

    @PutMapping("/registrations/{registrationId}/approve")
    @Operation(summary = "Approve a registration")
    public ResponseEntity<ApiResponse<RegistrationResponse>> approveRegistration(
            @PathVariable UUID registrationId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        RegistrationResponse response = registrationService.approveRegistration(registrationId, user);
        // Enrich with review data
        Registration fullReg = registrationRepository.findById(registrationId).orElse(null);
        RegistrationResponse enrichedResponse = registrationReviewService.enrichWithReviewData(response, fullReg);
        return ResponseEntity.ok(ApiResponse.success("Registration approved successfully", enrichedResponse));
    }

    @PutMapping("/registrations/{registrationId}/reject")
    @Operation(summary = "Reject a registration")
    public ResponseEntity<ApiResponse<RegistrationResponse>> rejectRegistration(
            @PathVariable UUID registrationId,
            @RequestParam(required = false) String reason,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        RegistrationResponse response = registrationService.rejectRegistration(registrationId, user, reason);
        return ResponseEntity.ok(ApiResponse.success("Registration rejected successfully", response));
    }

    @PutMapping("/registrations/{registrationId}/check-in")
    @Operation(summary = "Check in a registration")
    public ResponseEntity<ApiResponse<RegistrationResponse>> checkInRegistration(
            @PathVariable UUID registrationId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        RegistrationResponse response = registrationService.checkInRegistration(registrationId, user);
        return ResponseEntity.ok(ApiResponse.success("Check-in successful", response));
    }

    @PostMapping("/registrations/event/{eventId}/check-in-by-code")
    @Operation(summary = "Check in a registration by scanning ticket code")
    public ResponseEntity<ApiResponse<RegistrationResponse>> checkInByCode(
            @PathVariable UUID eventId,
            @RequestParam String ticketCode,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        RegistrationResponse response = registrationService.checkInByTicketCode(eventId, ticketCode, user);
        return ResponseEntity.ok(ApiResponse.success("Check-in successful", response));
    }

    @DeleteMapping("/registrations/{registrationId}")
    @Operation(summary = "Delete a registration")
    public ResponseEntity<ApiResponse<Void>> deleteRegistration(
            @PathVariable UUID registrationId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        registrationService.deleteRegistration(registrationId, user);
        return ResponseEntity.ok(ApiResponse.success("Registration deleted successfully", null));
    }

    @GetMapping("/registrations/event/{eventId}/export")
    @Operation(summary = "Export attendees to Excel")
    public ResponseEntity<byte[]> exportAttendees(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        Event event = eventService.getEntityById(eventId);

        byte[] excelContent = excelExportService.exportEventAttendees(event);

        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=attendees_" + eventId + ".xlsx")
                .contentType(MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .body(excelContent);
    }

    @GetMapping("/registrations/{registrationId}/answers")
    @Operation(summary = "Get registration answers for a specific registration")
    public ResponseEntity<ApiResponse<List<RegistrationAnswerResponse>>> getRegistrationAnswers(
            @PathVariable UUID registrationId) {
        List<RegistrationAnswer> answers = registrationAnswerRepository.findByRegistrationId(registrationId);
        List<RegistrationAnswerResponse> response = answers.stream()
                .map(RegistrationAnswerResponse::fromEntity)
                .toList();
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/events/{eventId}/waitlist-offers")
    @Operation(summary = "Get waitlist offers for an event")
    public ResponseEntity<ApiResponse<java.util.List<WaitlistOfferResponse>>> getWaitlistOffers(
            @PathVariable UUID eventId) {
        Event event = eventService.getEntityById(eventId);
        java.util.List<WaitlistOfferResponse> offers = waitlistService.getOffersByEvent(event);
        return ResponseEntity.ok(ApiResponse.success(offers));
    }

    @PostMapping("/registrations/{registrationId}/refund")
    @Operation(summary = "Process refund for a paid registration")
    public ResponseEntity<ApiResponse<PaymentResponse>> processRefund(
            @PathVariable UUID registrationId,
            @Valid @RequestBody RefundRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User organiser = userService.getEntityByEmail(userDetails.getUsername());
        PaymentResponse response = paymentService.processRefund(
                registrationId,
                organiser,
                request.getReason(),
                request.getAmount()
        );
        return ResponseEntity.ok(ApiResponse.success("Refund processed successfully", response));
    }
}

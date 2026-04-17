package com.luma.service;

import com.luma.dto.request.RegistrationAnswerRequest;
import com.luma.dto.request.RegistrationWithAnswersRequest;
import com.luma.dto.response.PageResponse;
import com.luma.dto.response.RegistrationResponse;
import com.luma.dto.response.RegistrationStatusResponse;
import com.luma.entity.*;
import com.luma.entity.enums.PaymentStatus;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.CouponRepository;
import com.luma.repository.CouponUsageRepository;
import com.luma.repository.PaymentRepository;
import com.luma.repository.RegistrationAnswerRepository;
import com.luma.repository.RegistrationQuestionRepository;
import com.luma.repository.RegistrationRepository;
import com.luma.repository.TicketTypeRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class RegistrationService {

    private final RegistrationRepository registrationRepository;
    private final RegistrationQuestionRepository questionRepository;
    private final RegistrationAnswerRepository answerRepository;
    private final PaymentRepository paymentRepository;
    private final TicketTypeRepository ticketTypeRepository;
    private final EventService eventService;
    private final NotificationService notificationService;
    private final WaitlistService waitlistService;
    private final CouponRepository couponRepository;
    private final CouponUsageRepository couponUsageRepository;

    public Registration getEntityById(UUID id) {
        return registrationRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Registration not found"));
    }

    public RegistrationResponse getRegistrationById(UUID id) {
        Registration registration = getEntityById(id);
        return toResponseWithPaymentCheck(registration);
    }

    private boolean hasSuccessfulPayment(UUID registrationId) {
        return paymentRepository.findByRegistrationId(registrationId)
                .map(payment -> payment.getStatus() == PaymentStatus.SUCCEEDED)
                .orElse(false);
    }

    private RegistrationResponse toResponseWithPaymentCheck(Registration registration) {
        boolean hasPaid = hasSuccessfulPayment(registration.getId());
        return RegistrationResponse.fromEntity(registration, hasPaid);
    }

    private static final List<RegistrationStatus> INACTIVE_STATUSES = List.of(
            RegistrationStatus.CANCELLED,
            RegistrationStatus.REJECTED
    );

    public RegistrationStatusResponse getRegistrationStatus(User user, UUID eventId) {
        Event event = eventService.getEntityById(eventId);
        return registrationRepository.findActiveByUserAndEvent(user, event, INACTIVE_STATUSES)
                .map(reg -> {
                    BigDecimal ticketPrice = getActualPrice(reg);
                    boolean isPaidEvent = ticketPrice != null && ticketPrice.compareTo(BigDecimal.ZERO) > 0;
                    boolean requiresPayment = isPaidEvent && reg.getStatus() == RegistrationStatus.PENDING;

                    return RegistrationStatusResponse.registered(
                            reg.getId(),
                            reg.getStatus(),
                            requiresPayment,
                            ticketPrice != null ? ticketPrice.doubleValue() : null,
                            event.getTitle(),
                            reg.getWaitingListPosition(),
                            reg.getTicketType() != null ? reg.getTicketType().getId() : null,
                            reg.getTicketType() != null ? reg.getTicketType().getName() : null,
                            reg.getQuantity() != null ? reg.getQuantity() : 1
                    );
                })
                .orElse(RegistrationStatusResponse.notRegistered());
    }

    public BigDecimal getActualPrice(Registration registration) {
        if (registration.getTicketType() != null) {
            BigDecimal unitPrice = registration.getTicketType().getPrice();
            int quantity = registration.getQuantity() != null ? registration.getQuantity() : 1;
            return unitPrice.multiply(BigDecimal.valueOf(quantity));
        }
        return registration.getEvent().getTicketPrice();
    }

    @Transactional
    public RegistrationResponse registerForEvent(User user, UUID eventId) {
        return registerForEvent(user, eventId, null, 1);
    }

    @Transactional
    public RegistrationResponse registerForEvent(User user, UUID eventId, UUID ticketTypeId, Integer quantity) {
        Event event = eventService.getEntityByIdWithRelationships(eventId);

        if (event.getStartTime().isBefore(LocalDateTime.now())) {
            throw new BadRequestException("Event has already started, registration is closed");
        }

        Optional<Registration> existingReg = registrationRepository.findByUserAndEventWithLock(user, event);
        if (existingReg.isPresent()) {
            Registration oldReg = existingReg.get();
            if (oldReg.getStatus() == RegistrationStatus.CANCELLED ||
                oldReg.getStatus() == RegistrationStatus.REJECTED) {
                returnTicketsToPool(oldReg);
                paymentRepository.deleteByRegistrationId(oldReg.getId());
                answerRepository.deleteAll(oldReg.getAnswers());
                registrationRepository.delete(oldReg);
                registrationRepository.flush();
            } else {
                throw new BadRequestException("You have already registered for this event");
            }
        }

        TicketType ticketType = null;
        int qty = quantity != null ? quantity : 1;

        if (ticketTypeId != null) {
            ticketType = ticketTypeRepository.findByIdWithLock(ticketTypeId)
                    .orElseThrow(() -> new ResourceNotFoundException("Ticket type not found"));

            if (!ticketType.getEvent().getId().equals(eventId)) {
                throw new BadRequestException("Ticket type does not belong to this event");
            }

            validateTicketTypePurchase(ticketType, qty);
        } else if (event.hasTicketTypes()) {
            throw new BadRequestException("This event requires selecting a ticket type");
        }

        Registration registration = Registration.builder()
                .user(user)
                .event(event)
                .ticketType(ticketType)
                .quantity(qty)
                .ticketCode(generateTicketCode())
                .build();

        if (event.isFull()) {
            registration.setStatus(RegistrationStatus.WAITING_LIST);
            registration.setWaitingListPosition(registrationRepository.getMaxWaitingListPositionWithLock(event) + 1);
            registration.setPriorityScore(waitlistService.calculatePriorityScore(user, event));
        } else {
            registration.setStatus(RegistrationStatus.PENDING);
            if (ticketType != null) {
                int updated = ticketTypeRepository.incrementSoldCount(ticketType.getId(), qty);
                if (updated == 0) {
                    throw new BadRequestException("Unable to reserve tickets. They may have been sold out.");
                }
            }
        }

        Registration savedRegistration = registrationRepository.save(registration);

        notificationService.notifyOrganiserNewRegistration(savedRegistration);

        return RegistrationResponse.fromEntity(savedRegistration);
    }

    @Transactional
    public RegistrationResponse registerForEventWithAnswers(User user, UUID eventId, List<RegistrationAnswerRequest> answerRequests) {
        return registerForEventWithAnswers(user, eventId, answerRequests, null, 1);
    }

    @Transactional
    public RegistrationResponse registerForEventWithAnswers(User user, UUID eventId,
            List<RegistrationAnswerRequest> answerRequests, UUID ticketTypeId, Integer quantity) {
        Event event = eventService.getEntityByIdWithRelationships(eventId);

        if (event.getStartTime().isBefore(LocalDateTime.now())) {
            throw new BadRequestException("Event has already started, registration is closed");
        }

        Optional<Registration> existingReg = registrationRepository.findByUserAndEventWithLock(user, event);
        if (existingReg.isPresent()) {
            Registration oldReg = existingReg.get();
            if (oldReg.getStatus() == RegistrationStatus.CANCELLED ||
                oldReg.getStatus() == RegistrationStatus.REJECTED) {
                returnTicketsToPool(oldReg);
                paymentRepository.deleteByRegistrationId(oldReg.getId());
                answerRepository.deleteAll(oldReg.getAnswers());
                registrationRepository.delete(oldReg);
                registrationRepository.flush();
            } else {
                throw new BadRequestException("You have already registered for this event");
            }
        }

        TicketType ticketType = null;
        int qty = quantity != null ? quantity : 1;

        if (ticketTypeId != null) {
            ticketType = ticketTypeRepository.findByIdWithLock(ticketTypeId)
                    .orElseThrow(() -> new ResourceNotFoundException("Ticket type not found"));

            if (!ticketType.getEvent().getId().equals(eventId)) {
                throw new BadRequestException("Ticket type does not belong to this event");
            }

            validateTicketTypePurchase(ticketType, qty);
        } else if (event.hasTicketTypes()) {
            throw new BadRequestException("This event requires selecting a ticket type");
        }

        List<RegistrationQuestion> questions = questionRepository.findByEventOrderByDisplayOrderAsc(event);
        for (RegistrationQuestion question : questions) {
            if (question.isRequired()) {
                boolean hasAnswer = answerRequests != null && answerRequests.stream()
                        .anyMatch(a -> a.getQuestionId().equals(question.getId()) &&
                                a.getAnswer() != null && !a.getAnswer().trim().isEmpty());
                if (!hasAnswer) {
                    throw new BadRequestException("Please answer the required question: " + question.getQuestionText());
                }
            }
        }

        Registration registration = Registration.builder()
                .user(user)
                .event(event)
                .ticketType(ticketType)
                .quantity(qty)
                .ticketCode(generateTicketCode())
                .build();

        if (event.isFull()) {
            registration.setStatus(RegistrationStatus.WAITING_LIST);
            registration.setWaitingListPosition(registrationRepository.getMaxWaitingListPositionWithLock(event) + 1);
            registration.setPriorityScore(waitlistService.calculatePriorityScore(user, event));
        } else {
            registration.setStatus(RegistrationStatus.PENDING);
            if (ticketType != null) {
                int updated = ticketTypeRepository.incrementSoldCount(ticketType.getId(), qty);
                if (updated == 0) {
                    throw new BadRequestException("Unable to reserve tickets. They may have been sold out.");
                }
            }
        }

        registration = registrationRepository.save(registration);

        if (answerRequests != null && !answerRequests.isEmpty()) {
            for (RegistrationAnswerRequest answerReq : answerRequests) {
                RegistrationQuestion question = questionRepository.findById(answerReq.getQuestionId())
                        .orElse(null);
                if (question != null && answerReq.getAnswer() != null) {
                    RegistrationAnswer answer = RegistrationAnswer.builder()
                            .registration(registration)
                            .question(question)
                            .answerText(answerReq.getAnswer())
                            .build();
                    answerRepository.save(answer);
                }
            }
        }

        notificationService.notifyOrganiserNewRegistration(registration);

        return RegistrationResponse.fromEntity(registration);
    }

    @Transactional
    public RegistrationResponse registerWithRequest(User user, UUID eventId, RegistrationWithAnswersRequest request) {
        return registerForEventWithAnswers(
                user,
                eventId,
                request.getAnswers(),
                request.getTicketTypeId(),
                request.getQuantity()
        );
    }

    private void validateTicketTypePurchase(TicketType ticketType, int quantity) {
        if (!ticketType.getIsVisible()) {
            throw new BadRequestException("This ticket type is not available");
        }

        if (!ticketType.isSaleActive()) {
            throw new BadRequestException("Ticket sales are not active for this ticket type");
        }

        if (!ticketType.canPurchase(quantity)) {
            int available = ticketType.getAvailableQuantity();
            if (available <= 0) {
                throw new BadRequestException("This ticket type is sold out");
            } else {
                throw new BadRequestException("Only " + available + " tickets available for this ticket type");
            }
        }

        if (ticketType.getMaxPerOrder() != null && quantity > ticketType.getMaxPerOrder()) {
            throw new BadRequestException("Maximum " + ticketType.getMaxPerOrder() + " tickets per order for this ticket type");
        }
    }

    private void returnTicketsToPool(Registration registration) {
        if (registration.getTicketType() != null && registration.getQuantity() != null) {
            ticketTypeRepository.decrementSoldCount(
                    registration.getTicketType().getId(),
                    registration.getQuantity()
            );
        }
    }

    @Transactional
    public RegistrationResponse approveRegistration(UUID registrationId, User organiser) {
        Registration registration = getEntityById(registrationId);
        Event event = registration.getEvent();

        validateOrganiserAccess(event, organiser);

        if (registration.getStatus() == RegistrationStatus.APPROVED) {
            throw new BadRequestException("Registration has already been approved");
        }

        if (event.isFull()) {
            throw new BadRequestException("Event is at full capacity");
        }

        registration.setStatus(RegistrationStatus.APPROVED);
        registration.setApprovedAt(LocalDateTime.now());
        registration.setWaitingListPosition(null);
        eventService.incrementApprovedCount(event);

        Registration saved = registrationRepository.save(registration);

        try {
            notificationService.sendRegistrationApprovedNotification(saved);
        } catch (Exception e) {
            log.error("Failed to send approval notification for registration {}: {}", registrationId, e.getMessage());
        }

        return RegistrationResponse.fromEntity(saved);
    }

    @Transactional
    public RegistrationResponse rejectRegistration(UUID registrationId, User organiser, String reason) {
        Registration registration = getEntityById(registrationId);
        Event event = registration.getEvent();

        validateOrganiserAccess(event, organiser);

        boolean wasApproved = registration.getStatus() == RegistrationStatus.APPROVED;
        if (wasApproved) {
            eventService.decrementApprovedCount(event);
        }

        returnTicketsToPool(registration);

        registration.setStatus(RegistrationStatus.REJECTED);
        registration.setRejectedAt(LocalDateTime.now());
        registration.setRejectionReason(reason);
        registration.setWaitingListPosition(null);

        Registration saved = registrationRepository.save(registration);

        try {
            notificationService.sendRegistrationRejectedNotification(saved);
        } catch (Exception e) {
            log.error("Failed to send rejection notification for registration {}: {}", registrationId, e.getMessage());
        }

        RegistrationResponse response = RegistrationResponse.fromEntity(saved);

        if (wasApproved) {
            promoteFromWaitingList(event);
        }

        return response;
    }

    @Transactional
    public RegistrationResponse cancelRegistration(UUID registrationId, User user) {
        Registration registration = getEntityById(registrationId);

        if (!registration.getUser().getId().equals(user.getId())) {
            throw new BadRequestException("You do not have permission to cancel this registration");
        }

        if (registration.getStatus() == RegistrationStatus.CANCELLED) {
            throw new BadRequestException("Registration has already been cancelled");
        }

        Event event = registration.getEvent();

        returnTicketsToPool(registration);

        if (registration.getStatus() == RegistrationStatus.APPROVED) {
            eventService.decrementApprovedCount(event);
            promoteFromWaitingList(event);
        } else if (registration.getStatus() == RegistrationStatus.WAITING_LIST) {
            Integer cancelledPosition = registration.getWaitingListPosition();
            if (cancelledPosition != null) {
                registrationRepository.decrementWaitingListPositionsAfter(event, cancelledPosition);
            }
        }

        if (registration.getCouponCode() != null) {
            couponRepository.findByCode(registration.getCouponCode()).ifPresent(coupon -> {
                if (coupon.getUsedCount() > 0) {
                    coupon.setUsedCount(coupon.getUsedCount() - 1);
                    couponRepository.save(coupon);
                }
            });
            couponUsageRepository.findByRegistrationId(registration.getId())
                    .ifPresent(couponUsageRepository::delete);
            registration.setCouponCode(null);
        }

        registration.setStatus(RegistrationStatus.CANCELLED);
        registration.setWaitingListPosition(null);
        Registration savedRegistration = registrationRepository.save(registration);

        notificationService.notifyOrganiserRegistrationCancelled(savedRegistration);

        return RegistrationResponse.fromEntity(savedRegistration);
    }

    @Transactional
    public RegistrationResponse checkInRegistration(UUID registrationId, User organiser) {
        Registration registration = getEntityById(registrationId);
        Event event = registration.getEvent();

        validateOrganiserAccess(event, organiser);

        if (registration.getStatus() != RegistrationStatus.APPROVED) {
            throw new BadRequestException("Only approved registrations can be checked in");
        }

        if (registration.getCheckedInAt() != null) {
            throw new BadRequestException("This registration has already been checked in");
        }

        validateCheckInTime(event);

        registration.setCheckedInAt(LocalDateTime.now());
        return RegistrationResponse.fromEntity(registrationRepository.save(registration));
    }

    @Transactional
    public RegistrationResponse checkInByTicketCode(UUID eventId, String ticketCode, User organiser) {
        String code = ticketCode == null ? "" : ticketCode.trim();
        if (code.isEmpty()) {
            throw new BadRequestException("Ticket code is required");
        }
        Registration registration = registrationRepository.findByTicketCode(code)
                .orElseThrow(() -> new ResourceNotFoundException("No registration found for ticket code: " + code));

        if (!registration.getEvent().getId().equals(eventId)) {
            throw new BadRequestException("This ticket does not belong to the selected event");
        }

        return checkInRegistration(registration.getId(), organiser);
    }

    private void validateCheckInTime(Event event) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime eventStart = event.getStartTime();
        LocalDateTime eventEnd = event.getEndTime();

        LocalDateTime checkInWindowStart = eventStart.minusHours(2);
        LocalDateTime checkInWindowEnd = eventEnd != null ? eventEnd.plusHours(1) : eventStart.plusHours(6);

        if (now.isBefore(checkInWindowStart)) {
            throw new BadRequestException("Check-in is not available yet. Check-in opens 2 hours before the event starts.");
        }

        if (now.isAfter(checkInWindowEnd)) {
            throw new BadRequestException("Check-in period has ended for this event.");
        }
    }

    @Transactional
    public void promoteFromWaitingList(Event event) {
        waitlistService.createOfferForNextInLine(event);
    }

    public PageResponse<RegistrationResponse> getRegistrationsByEvent(Event event, Pageable pageable) {
        Page<Registration> registrations = registrationRepository.findByEvent(event, pageable);
        return PageResponse.from(registrations, RegistrationResponse::fromEntity);
    }

    public PageResponse<RegistrationResponse> getRegistrationsByEventAndStatus(Event event, RegistrationStatus status, Pageable pageable) {
        Page<Registration> registrations = registrationRepository.findByEventAndStatus(event, status, pageable);
        return PageResponse.from(registrations, RegistrationResponse::fromEntity);
    }

    @Transactional
    public List<RegistrationResponse> getWaitingList(Event event) {
        List<Registration> waitingList = registrationRepository.findWaitingListByEvent(event);

        boolean needsFix = false;
        for (int i = 0; i < waitingList.size(); i++) {
            Registration reg = waitingList.get(i);
            int expectedPosition = i + 1;
            if (reg.getWaitingListPosition() == null || reg.getWaitingListPosition() != expectedPosition) {
                needsFix = true;
                break;
            }
        }

        if (needsFix) {
            for (int i = 0; i < waitingList.size(); i++) {
                Registration reg = waitingList.get(i);
                reg.setWaitingListPosition(i + 1);
                registrationRepository.save(reg);
            }
        }

        return waitingList.stream()
                .map(RegistrationResponse::fromEntity)
                .toList();
    }

    public PageResponse<RegistrationResponse> getUserUpcomingRegistrations(User user, Pageable pageable) {
        Page<Registration> registrations = registrationRepository.findUpcomingRegistrationsByUser(user, pageable);
        return PageResponse.from(registrations, this::toResponseWithPaymentCheck);
    }

    public PageResponse<RegistrationResponse> getUserPastRegistrations(User user, Pageable pageable) {
        Page<Registration> registrations = registrationRepository.findPastRegistrationsByUser(user, pageable);
        return PageResponse.from(registrations, this::toResponseWithPaymentCheck);
    }

    public long countApprovedByOrganiser(User organiser) {
        return registrationRepository.countApprovedByOrganiser(organiser);
    }

    private void validateOrganiserAccess(Event event, User organiser) {
        if (!event.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You do not have permission to manage registrations for this event");
        }
    }

    private String generateTicketCode() {
        return "TKT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
    }
}

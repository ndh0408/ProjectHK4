package com.luma.service;

import com.luma.dto.response.PageResponse;
import com.luma.dto.response.TicketTransferResponse;
import com.luma.entity.*;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.entity.enums.TransferStatus;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.RegistrationRepository;
import com.luma.repository.TicketTransferRepository;
import com.luma.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class TicketTransferService {

    private static final BigDecimal MAX_RESALE_MULTIPLIER = BigDecimal.valueOf(1.5);

    private final TicketTransferRepository transferRepository;
    private final RegistrationRepository registrationRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;

    @Transactional
    public TicketTransferResponse initiateTransfer(UUID registrationId, String toEmail, User fromUser) {
        Registration registration = registrationRepository.findById(registrationId)
                .orElseThrow(() -> new ResourceNotFoundException("Registration not found"));

        validateTransfer(registration, fromUser);

        User toUser = userRepository.findByEmail(toEmail)
                .orElseThrow(() -> new BadRequestException(
                        "Recipient must have a Luma account. Ask them to sign up with " + toEmail + " first."));

        if (toUser.getId().equals(fromUser.getId())) {
            throw new BadRequestException("Cannot transfer ticket to yourself");
        }

        TicketTransfer transfer = TicketTransfer.builder()
                .registration(registration)
                .fromUser(fromUser)
                .toUser(toUser)
                .toEmail(toEmail)
                .isResale(false)
                .originalPrice(getTicketPrice(registration))
                .transferCode(generateTransferCode())
                .build();

        transfer = transferRepository.save(transfer);
        log.info("Ticket transfer initiated: {} -> {}", fromUser.getId(), toEmail);

        try {
            notificationService.sendNotification(
                    toUser,
                    "Ticket Transfer Received",
                    fromUser.getFullName() + " wants to transfer a ticket for \"" +
                            registration.getEvent().getTitle() + "\" to you",
                    com.luma.entity.enums.NotificationType.TICKET_TRANSFER_RECEIVED,
                    transfer.getId(),
                    "TRANSFER",
                    fromUser
            );
        } catch (Exception e) {
            log.error("Failed to send transfer notification: {}", e.getMessage());
        }

        return TicketTransferResponse.fromEntity(transfer);
    }

    @Transactional
    public TicketTransferResponse listForResale(UUID registrationId, BigDecimal resalePrice, User fromUser) {
        Registration registration = registrationRepository.findById(registrationId)
                .orElseThrow(() -> new ResourceNotFoundException("Registration not found"));

        validateTransfer(registration, fromUser);

        BigDecimal originalPrice = getTicketPrice(registration);
        BigDecimal maxPrice = originalPrice.multiply(MAX_RESALE_MULTIPLIER);

        if (resalePrice.compareTo(maxPrice) > 0) {
            throw new BadRequestException("Resale price cannot exceed 150% of the original price (" + maxPrice + ")");
        }

        TicketTransfer transfer = TicketTransfer.builder()
                .registration(registration)
                .fromUser(fromUser)
                .isResale(true)
                .resalePrice(resalePrice)
                .originalPrice(originalPrice)
                .transferCode(generateTransferCode())
                .build();

        transfer = transferRepository.save(transfer);
        log.info("Ticket listed for resale: {} at price {}", registrationId, resalePrice);
        return TicketTransferResponse.fromEntity(transfer);
    }

    @Transactional
    public TicketTransferResponse acceptTransfer(UUID transferId, User acceptingUser) {
        TicketTransfer transfer = transferRepository.findById(transferId)
                .orElseThrow(() -> new ResourceNotFoundException("Transfer not found"));

        if (transfer.getStatus() != TransferStatus.PENDING) {
            throw new BadRequestException("This transfer is no longer available");
        }

        if (!transfer.isResale() && transfer.getToUser() != null &&
            !transfer.getToUser().getId().equals(acceptingUser.getId())) {
            throw new BadRequestException("This transfer is not for you");
        }

        Registration registration = transfer.getRegistration();

        String oldTicketCode = registration.getTicketCode();
        registration.setUser(acceptingUser);
        registration.setTicketCode("TKT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase());
        registration.setCheckedInAt(null);

        registration.setRegistrationGoals(null);
        registration.setExpectations(null);
        registration.setExperienceLevel(null);
        registration.setCouponCode(null);
        registration.setReminderSent(false);
        registration.setReminderSentAt(null);
        registration.setPriorityScore(null);
        registration.setWaitingListPosition(null);
        registration.setRejectionReason(null);
        registration.setRejectedAt(null);
        if (registration.getAnswers() != null) {
            registration.getAnswers().clear();
        }

        if (transfer.isResale() && transfer.getResalePrice() != null
                && transfer.getResalePrice().compareTo(BigDecimal.ZERO) > 0) {
            registration.setStatus(RegistrationStatus.PENDING);
            registration.setApprovedAt(null);
        }

        registrationRepository.save(registration);

        log.info("Ticket transferred: old code {} invalidated, new code {} assigned",
                oldTicketCode, registration.getTicketCode());

        transfer.setStatus(TransferStatus.ACCEPTED);
        transfer.setToUser(acceptingUser);
        transfer.setRespondedAt(LocalDateTime.now());
        transferRepository.save(transfer);

        if (transfer.getFromUser() != null) {
            try {
                notificationService.sendNotification(
                        transfer.getFromUser(),
                        "Ticket Transfer Accepted",
                        acceptingUser.getFullName() + " accepted your ticket transfer for \"" +
                                registration.getEvent().getTitle() + "\"",
                        com.luma.entity.enums.NotificationType.TICKET_TRANSFER_ACCEPTED,
                        transfer.getId(),
                        "TRANSFER",
                        acceptingUser
                );
            } catch (Exception e) {
                log.error("Failed to send transfer accepted notification: {}", e.getMessage());
            }
        }

        TicketTransferResponse response = TicketTransferResponse.fromEntity(transfer);
        if (transfer.isResale() && transfer.getResalePrice() != null
                && transfer.getResalePrice().compareTo(BigDecimal.ZERO) > 0) {
            response.setRequiresPayment(true);
        }

        log.info("Transfer accepted: {} by user {} (resale={})", transferId, acceptingUser.getId(), transfer.isResale());
        return response;
    }

    @Transactional
    public TicketTransferResponse declineTransfer(UUID transferId, User user) {
        TicketTransfer transfer = transferRepository.findById(transferId)
                .orElseThrow(() -> new ResourceNotFoundException("Transfer not found"));

        if (transfer.getStatus() != TransferStatus.PENDING) {
            throw new BadRequestException("This transfer is no longer pending");
        }

        if (!transfer.isResale() && transfer.getToUser() != null &&
                !transfer.getToUser().getId().equals(user.getId()) &&
                !transfer.getFromUser().getId().equals(user.getId())) {
            throw new BadRequestException("You cannot decline this transfer");
        }

        transfer.setStatus(TransferStatus.DECLINED);
        transfer.setRespondedAt(LocalDateTime.now());
        transferRepository.save(transfer);

        if (transfer.getFromUser() != null &&
                !transfer.getFromUser().getId().equals(user.getId())) {
            try {
                notificationService.sendNotification(
                        transfer.getFromUser(),
                        "Ticket Transfer Declined",
                        user.getFullName() + " declined your ticket transfer for \"" +
                                transfer.getRegistration().getEvent().getTitle() + "\"",
                        com.luma.entity.enums.NotificationType.TICKET_TRANSFER_RECEIVED,
                        transfer.getId(),
                        "TRANSFER",
                        user
                );
            } catch (Exception e) {
                log.error("Failed to send transfer declined notification: {}", e.getMessage());
            }
        }

        return TicketTransferResponse.fromEntity(transfer);
    }

    public List<TicketTransferResponse> getResaleListings(UUID eventId) {
        return transferRepository.findResaleListingsByEvent(eventId).stream()
                .map(TicketTransferResponse::fromEntity)
                .toList();
    }

    public PageResponse<TicketTransferResponse> getMyTransfers(User user, Pageable pageable) {
        Page<TicketTransfer> page = transferRepository.findByFromUser(user, pageable);
        return PageResponse.from(page, TicketTransferResponse::fromEntity);
    }

    private void validateTransfer(Registration registration, User fromUser) {
        if (!registration.getUser().getId().equals(fromUser.getId())) {
            throw new BadRequestException("You can only transfer your own tickets");
        }
        if (registration.getStatus() != RegistrationStatus.APPROVED) {
            throw new BadRequestException("Only approved registrations can be transferred");
        }
        if (registration.getCheckedInAt() != null) {
            throw new BadRequestException("Cannot transfer a ticket that has been checked in");
        }
        BigDecimal price = getTicketPrice(registration);
        if (price == null || price.compareTo(BigDecimal.ZERO) <= 0) {
            throw new BadRequestException("Free tickets cannot be transferred");
        }
        if (transferRepository.existsByRegistrationAndStatus(registration, TransferStatus.PENDING)) {
            throw new BadRequestException("This ticket already has a pending transfer");
        }
    }

    private BigDecimal getTicketPrice(Registration registration) {
        if (registration.getTicketType() != null) {
            return registration.getTicketType().getPrice();
        }
        return registration.getEvent().getTicketPrice() != null
                ? registration.getEvent().getTicketPrice()
                : BigDecimal.ZERO;
    }

    private String generateTransferCode() {
        return "TRF-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
    }
}

package com.luma.service;

import com.luma.dto.request.WithdrawalRequestDTO;
import com.luma.dto.response.BalanceResponse;
import com.luma.dto.response.WithdrawalResponse;
import com.luma.dto.response.WithdrawalStatsResponse;
import com.luma.entity.OrganiserBankAccount;
import com.luma.entity.User;
import com.luma.entity.WithdrawalRequest;
import com.luma.entity.enums.CommissionStatus;
import com.luma.entity.enums.WithdrawalStatus;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.CommissionTransactionRepository;
import com.luma.repository.OrganiserBankAccountRepository;
import com.luma.repository.WithdrawalRequestRepository;
import com.stripe.Stripe;
import com.stripe.exception.StripeException;
import com.stripe.model.Transfer;
import com.stripe.param.TransferCreateParams;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
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
public class WithdrawalService {

    private final WithdrawalRequestRepository withdrawalRepository;
    private final CommissionTransactionRepository commissionTransactionRepository;
    private final OrganiserBankAccountRepository bankAccountRepository;
    private final CommissionService commissionService;
    private final NotificationService notificationService;

    @Value("${stripe.secret-key}")
    private String stripeSecretKey;

    @Value("${payout.min-amount:50.00}")
    private BigDecimal minWithdrawalAmount;

    // ==================== Organiser Methods ====================

    /**
     * Get balance information for an organiser
     */
    public BalanceResponse getOrganiserBalance(User organiser) {
        UUID organiserId = organiser.getId();

        // Get total earnings from confirmed commission transactions
        BigDecimal totalEarnings = commissionTransactionRepository.getTotalOrganiserEarnings(organiserId);
        if (totalEarnings == null) totalEarnings = BigDecimal.ZERO;

        // Get pending and completed withdrawals
        BigDecimal pendingWithdrawals = withdrawalRepository.getTotalPendingWithdrawalsByOrganiser(organiserId);
        if (pendingWithdrawals == null) pendingWithdrawals = BigDecimal.ZERO;

        BigDecimal completedWithdrawals = withdrawalRepository.getTotalCompletedWithdrawalsByOrganiser(organiserId);
        if (completedWithdrawals == null) completedWithdrawals = BigDecimal.ZERO;

        // Calculate available balance
        BigDecimal availableBalance = totalEarnings.subtract(pendingWithdrawals).subtract(completedWithdrawals);
        if (availableBalance.compareTo(BigDecimal.ZERO) < 0) {
            availableBalance = BigDecimal.ZERO;
        }

        // Get commission rate
        BigDecimal commissionRate = commissionService.getCommissionRateForOrganiser(organiserId);

        // Check bank account
        OrganiserBankAccount bankAccount = bankAccountRepository.findByOrganiserId(organiserId).orElse(null);
        boolean hasBankAccount = bankAccount != null;
        boolean payoutsEnabled = bankAccount != null && Boolean.TRUE.equals(bankAccount.getPayoutsEnabled());

        return BalanceResponse.builder()
                .totalEarnings(totalEarnings)
                .availableBalance(availableBalance)
                .pendingWithdrawals(pendingWithdrawals)
                .completedWithdrawals(completedWithdrawals)
                .minWithdrawalAmount(minWithdrawalAmount)
                .commissionRate(commissionRate)
                .currency("USD")
                .hasBankAccount(hasBankAccount)
                .payoutsEnabled(payoutsEnabled)
                .build();
    }

    /**
     * Create a withdrawal request
     */
    @Transactional
    public WithdrawalResponse createWithdrawalRequest(User organiser, WithdrawalRequestDTO request) {
        UUID organiserId = organiser.getId();

        // Check if organiser has bank account
        OrganiserBankAccount bankAccount = bankAccountRepository.findByOrganiserId(organiserId)
                .orElseThrow(() -> new BadRequestException("Please connect your bank account before requesting withdrawal"));

        if (!Boolean.TRUE.equals(bankAccount.getPayoutsEnabled())) {
            throw new BadRequestException("Your bank account is not verified for payouts. Please complete the verification process.");
        }

        // Check if there's already a pending withdrawal
        boolean hasPending = withdrawalRepository.existsByOrganiserIdAndStatusIn(
                organiserId,
                List.of(WithdrawalStatus.PENDING, WithdrawalStatus.APPROVED, WithdrawalStatus.PROCESSING)
        );
        if (hasPending) {
            throw new BadRequestException("You already have a pending withdrawal request. Please wait for it to be processed.");
        }

        // Get available balance
        BalanceResponse balance = getOrganiserBalance(organiser);
        BigDecimal availableBalance = balance.getAvailableBalance();

        // Validate amount
        BigDecimal amount = request.getAmount();
        if (amount.compareTo(minWithdrawalAmount) < 0) {
            throw new BadRequestException("Minimum withdrawal amount is $" + minWithdrawalAmount);
        }
        if (amount.compareTo(availableBalance) > 0) {
            throw new BadRequestException("Insufficient balance. Available: $" + availableBalance);
        }

        // Create withdrawal request
        WithdrawalRequest withdrawal = WithdrawalRequest.builder()
                .organiser(organiser)
                .amount(amount)
                .availableBalance(availableBalance)
                .currency("USD")
                .status(WithdrawalStatus.PENDING)
                .organiserNote(request.getNote())
                .bankAccountLastFour(bankAccount.getLastFourDigits())
                .bankName(bankAccount.getBankName())
                .build();

        withdrawal = withdrawalRepository.save(withdrawal);
        log.info("Withdrawal request created: {} for organiser {} amount ${}",
                withdrawal.getId(), organiserId, amount);

        // Notify admins
        notifyAdminsNewWithdrawalRequest(withdrawal);

        return WithdrawalResponse.fromEntity(withdrawal);
    }

    /**
     * Cancel a withdrawal request (only if PENDING)
     */
    @Transactional
    public void cancelWithdrawalRequest(UUID withdrawalId, User organiser) {
        WithdrawalRequest withdrawal = withdrawalRepository.findById(withdrawalId)
                .orElseThrow(() -> new ResourceNotFoundException("Withdrawal request not found"));

        if (!withdrawal.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You don't have permission to cancel this request");
        }

        if (withdrawal.getStatus() != WithdrawalStatus.PENDING) {
            throw new BadRequestException("Only pending requests can be cancelled");
        }

        withdrawal.setStatus(WithdrawalStatus.CANCELLED);
        withdrawalRepository.save(withdrawal);

        log.info("Withdrawal request cancelled: {}", withdrawalId);
    }

    /**
     * Get withdrawal history for an organiser
     */
    public Page<WithdrawalResponse> getOrganiserWithdrawals(User organiser, Pageable pageable) {
        return withdrawalRepository.findByOrganiserIdOrderByCreatedAtDesc(organiser.getId(), pageable)
                .map(WithdrawalResponse::fromEntity);
    }

    // ==================== Admin Methods ====================

    /**
     * Get all withdrawal requests (for admin)
     */
    public Page<WithdrawalResponse> getAllWithdrawals(WithdrawalStatus status, Pageable pageable) {
        Page<WithdrawalRequest> page;
        if (status != null) {
            page = withdrawalRepository.findByStatusOrderByCreatedAtDesc(status, pageable);
        } else {
            page = withdrawalRepository.findAllByOrderByCreatedAtDesc(pageable);
        }
        return page.map(WithdrawalResponse::fromEntity);
    }

    /**
     * Get pending withdrawal requests (for admin)
     */
    public Page<WithdrawalResponse> getPendingWithdrawals(Pageable pageable) {
        return withdrawalRepository.findByStatusOrderByCreatedAtDesc(WithdrawalStatus.PENDING, pageable)
                .map(WithdrawalResponse::fromEntity);
    }

    /**
     * Get withdrawal request by ID
     */
    public WithdrawalResponse getWithdrawalById(UUID withdrawalId) {
        WithdrawalRequest withdrawal = withdrawalRepository.findById(withdrawalId)
                .orElseThrow(() -> new ResourceNotFoundException("Withdrawal request not found"));
        return WithdrawalResponse.fromEntity(withdrawal);
    }

    /**
     * Approve a withdrawal request
     */
    @Transactional
    public WithdrawalResponse approveWithdrawal(UUID withdrawalId, User admin, String adminNote) {
        WithdrawalRequest withdrawal = withdrawalRepository.findById(withdrawalId)
                .orElseThrow(() -> new ResourceNotFoundException("Withdrawal request not found"));

        if (withdrawal.getStatus() != WithdrawalStatus.PENDING) {
            throw new BadRequestException("Only pending requests can be approved");
        }

        // Verify balance is still sufficient
        BalanceResponse balance = getOrganiserBalance(withdrawal.getOrganiser());
        BigDecimal currentAvailable = balance.getAvailableBalance().add(withdrawal.getAmount()); // Add back since it's already counted as pending

        if (withdrawal.getAmount().compareTo(currentAvailable) > 0) {
            throw new BadRequestException("Organiser's available balance is insufficient");
        }

        withdrawal.setStatus(WithdrawalStatus.APPROVED);
        withdrawal.setProcessedBy(admin);
        withdrawal.setProcessedAt(LocalDateTime.now());
        withdrawal.setAdminNote(adminNote);

        withdrawal = withdrawalRepository.save(withdrawal);
        log.info("Withdrawal request approved: {} by admin {}", withdrawalId, admin.getId());

        // Notify organiser
        notifyOrganiserWithdrawalApproved(withdrawal);

        return WithdrawalResponse.fromEntity(withdrawal);
    }

    /**
     * Reject a withdrawal request
     */
    @Transactional
    public WithdrawalResponse rejectWithdrawal(UUID withdrawalId, User admin, String reason) {
        WithdrawalRequest withdrawal = withdrawalRepository.findById(withdrawalId)
                .orElseThrow(() -> new ResourceNotFoundException("Withdrawal request not found"));

        if (withdrawal.getStatus() != WithdrawalStatus.PENDING) {
            throw new BadRequestException("Only pending requests can be rejected");
        }

        withdrawal.setStatus(WithdrawalStatus.REJECTED);
        withdrawal.setProcessedBy(admin);
        withdrawal.setProcessedAt(LocalDateTime.now());
        withdrawal.setAdminNote(reason);

        withdrawal = withdrawalRepository.save(withdrawal);
        log.info("Withdrawal request rejected: {} by admin {} reason: {}", withdrawalId, admin.getId(), reason);

        // Notify organiser
        notifyOrganiserWithdrawalRejected(withdrawal, reason);

        return WithdrawalResponse.fromEntity(withdrawal);
    }

    /**
     * Process a withdrawal (transfer money via Stripe)
     */
    @Transactional
    public WithdrawalResponse processWithdrawal(UUID withdrawalId, User admin) {
        WithdrawalRequest withdrawal = withdrawalRepository.findById(withdrawalId)
                .orElseThrow(() -> new ResourceNotFoundException("Withdrawal request not found"));

        if (withdrawal.getStatus() != WithdrawalStatus.APPROVED) {
            throw new BadRequestException("Only approved requests can be processed");
        }

        // Get organiser's bank account
        OrganiserBankAccount bankAccount = bankAccountRepository.findByOrganiserId(withdrawal.getOrganiser().getId())
                .orElseThrow(() -> new BadRequestException("Organiser has no connected bank account"));

        if (!Boolean.TRUE.equals(bankAccount.getPayoutsEnabled())) {
            throw new BadRequestException("Organiser's bank account is not verified for payouts");
        }

        withdrawal.setStatus(WithdrawalStatus.PROCESSING);
        withdrawalRepository.save(withdrawal);

        Stripe.apiKey = stripeSecretKey;

        try {
            // Create Stripe transfer
            TransferCreateParams params = TransferCreateParams.builder()
                    .setAmount(withdrawal.getAmount().multiply(new BigDecimal("100")).longValue())
                    .setCurrency("usd")
                    .setDestination(bankAccount.getStripeAccountId())
                    .setTransferGroup("withdrawal_" + withdrawal.getId())
                    .putMetadata("withdrawal_id", withdrawal.getId().toString())
                    .putMetadata("organiser_id", withdrawal.getOrganiser().getId().toString())
                    .build();

            Transfer transfer = Transfer.create(params);

            // Update withdrawal
            withdrawal.setStripeTransferId(transfer.getId());
            withdrawal.setStatus(WithdrawalStatus.COMPLETED);
            withdrawal.setCompletedAt(LocalDateTime.now());
            withdrawal = withdrawalRepository.save(withdrawal);

            log.info("Withdrawal processed successfully: {} transfer: {}", withdrawalId, transfer.getId());

            // Settle commission transactions
            settleCommissionTransactions(withdrawal);

            // Notify organiser
            notifyOrganiserWithdrawalCompleted(withdrawal);

            return WithdrawalResponse.fromEntity(withdrawal);

        } catch (StripeException e) {
            log.error("Stripe transfer failed for withdrawal {}: {}", withdrawalId, e.getMessage());

            withdrawal.setStatus(WithdrawalStatus.APPROVED); // Revert to approved
            withdrawal.setFailureReason(e.getMessage());
            withdrawalRepository.save(withdrawal);

            throw new BadRequestException("Transfer failed: " + e.getMessage());
        }
    }

    /**
     * Settle commission transactions after successful withdrawal
     */
    private void settleCommissionTransactions(WithdrawalRequest withdrawal) {
        try {
            commissionService.settleCommissions(
                    withdrawal.getOrganiser().getId(),
                    withdrawal.getStripeTransferId()
            );
        } catch (Exception e) {
            log.error("Failed to settle commissions for withdrawal {}: {}",
                    withdrawal.getId(), e.getMessage());
        }
    }

    /**
     * Get withdrawal statistics for admin dashboard
     */
    public WithdrawalStatsResponse getWithdrawalStats() {
        long pendingCount = withdrawalRepository.countByStatus(WithdrawalStatus.PENDING);
        long approvedCount = withdrawalRepository.countByStatus(WithdrawalStatus.APPROVED);
        long processingCount = withdrawalRepository.countByStatus(WithdrawalStatus.PROCESSING);
        long completedCount = withdrawalRepository.countByStatus(WithdrawalStatus.COMPLETED);
        long rejectedCount = withdrawalRepository.countByStatus(WithdrawalStatus.REJECTED);

        BigDecimal pendingAmount = withdrawalRepository.getTotalPendingWithdrawals();
        BigDecimal completedAmount = withdrawalRepository.getTotalCompletedWithdrawals();

        // Get platform commission stats
        CommissionService.PlatformCommissionStats commissionStats = commissionService.getPlatformStats();

        return WithdrawalStatsResponse.builder()
                .pendingCount(pendingCount)
                .approvedCount(approvedCount)
                .processingCount(processingCount)
                .completedCount(completedCount)
                .rejectedCount(rejectedCount)
                .pendingAmount(pendingAmount != null ? pendingAmount : BigDecimal.ZERO)
                .completedAmount(completedAmount != null ? completedAmount : BigDecimal.ZERO)
                .totalPlatformCommission(commissionStats.totalCommission())
                .totalOrganiserEarnings(commissionStats.totalSales().subtract(commissionStats.totalCommission()))
                .currency("USD")
                .build();
    }

    // ==================== Notification Methods ====================

    private void notifyAdminsNewWithdrawalRequest(WithdrawalRequest withdrawal) {
        try {
            String title = "New Withdrawal Request";
            String message = String.format(
                    "Organiser %s requested withdrawal of $%.2f",
                    withdrawal.getOrganiser().getFullName(),
                    withdrawal.getAmount()
            );
            notificationService.sendNotificationToRole(title, message,
                    com.luma.entity.enums.UserRole.ADMIN);
        } catch (Exception e) {
            log.error("Failed to notify admins about withdrawal request: {}", e.getMessage());
        }
    }

    private void notifyOrganiserWithdrawalApproved(WithdrawalRequest withdrawal) {
        try {
            notificationService.sendNotification(
                    withdrawal.getOrganiser(),
                    "Withdrawal Approved",
                    String.format("Your withdrawal request of $%.2f has been approved and is being processed.",
                            withdrawal.getAmount()),
                    com.luma.entity.enums.NotificationType.PAYMENT,
                    null,
                    "WITHDRAWAL"
            );
        } catch (Exception e) {
            log.error("Failed to notify organiser about withdrawal approval: {}", e.getMessage());
        }
    }

    private void notifyOrganiserWithdrawalRejected(WithdrawalRequest withdrawal, String reason) {
        try {
            notificationService.sendNotification(
                    withdrawal.getOrganiser(),
                    "Withdrawal Rejected",
                    String.format("Your withdrawal request of $%.2f has been rejected. Reason: %s",
                            withdrawal.getAmount(), reason),
                    com.luma.entity.enums.NotificationType.PAYMENT,
                    null,
                    "WITHDRAWAL"
            );
        } catch (Exception e) {
            log.error("Failed to notify organiser about withdrawal rejection: {}", e.getMessage());
        }
    }

    private void notifyOrganiserWithdrawalCompleted(WithdrawalRequest withdrawal) {
        try {
            notificationService.sendNotification(
                    withdrawal.getOrganiser(),
                    "Withdrawal Completed",
                    String.format("$%.2f has been transferred to your bank account ending in %s.",
                            withdrawal.getAmount(), withdrawal.getBankAccountLastFour()),
                    com.luma.entity.enums.NotificationType.PAYMENT,
                    null,
                    "WITHDRAWAL"
            );
        } catch (Exception e) {
            log.error("Failed to notify organiser about withdrawal completion: {}", e.getMessage());
        }
    }
}

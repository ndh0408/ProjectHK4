package com.luma.service;

import com.luma.entity.*;
import com.luma.entity.enums.CommissionStatus;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.CommissionTransactionRepository;
import com.luma.repository.OrganiserCommissionRepository;
import com.luma.repository.PlatformConfigRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class CommissionService {

    private final PlatformConfigRepository platformConfigRepository;
    private final OrganiserCommissionRepository organiserCommissionRepository;
    private final CommissionTransactionRepository commissionTransactionRepository;

    private static final BigDecimal DEFAULT_COMMISSION_RATE = new BigDecimal("10.00");

    // ==================== Platform Config ====================

    /**
     * Get or create platform config
     */
    public PlatformConfig getPlatformConfig() {
        return platformConfigRepository.findFirst()
                .orElseGet(() -> {
                    PlatformConfig config = PlatformConfig.builder().build();
                    return platformConfigRepository.save(config);
                });
    }

    /**
     * Update platform config
     */
    @Transactional
    public PlatformConfig updatePlatformConfig(BigDecimal defaultCommissionRate,
                                                BigDecimal minCommissionRate,
                                                BigDecimal maxCommissionRate,
                                                BigDecimal minPayoutAmount,
                                                UUID adminId) {
        PlatformConfig config = getPlatformConfig();

        if (defaultCommissionRate != null) {
            validateCommissionRate(defaultCommissionRate, "Default commission rate");
            config.setDefaultCommissionRate(defaultCommissionRate);
        }
        if (minCommissionRate != null) {
            validateCommissionRate(minCommissionRate, "Minimum commission rate");
            config.setMinCommissionRate(minCommissionRate);
        }
        if (maxCommissionRate != null) {
            validateCommissionRate(maxCommissionRate, "Maximum commission rate");
            config.setMaxCommissionRate(maxCommissionRate);
        }
        if (minPayoutAmount != null) {
            if (minPayoutAmount.compareTo(BigDecimal.ZERO) < 0) {
                throw new BadRequestException("Minimum payout amount cannot be negative");
            }
            config.setMinPayoutAmount(minPayoutAmount);
        }

        config.setUpdatedBy(adminId);
        return platformConfigRepository.save(config);
    }

    // ==================== Organiser Commission ====================

    /**
     * Get commission rate for an organiser
     * Returns custom rate if exists and valid, otherwise platform default
     */
    public BigDecimal getCommissionRateForOrganiser(UUID organiserId) {
        return organiserCommissionRepository.findValidCommissionForOrganiser(organiserId, LocalDateTime.now())
                .map(OrganiserCommission::getCommissionRate)
                .orElseGet(() -> getPlatformConfig().getDefaultCommissionRate());
    }

    /**
     * Set custom commission rate for an organiser
     */
    @Transactional
    public OrganiserCommission setCustomCommissionRate(UUID organiserId,
                                                        BigDecimal commissionRate,
                                                        String reason,
                                                        LocalDateTime effectiveFrom,
                                                        LocalDateTime effectiveUntil,
                                                        User admin) {
        PlatformConfig config = getPlatformConfig();

        // Validate rate within bounds
        if (commissionRate.compareTo(config.getMinCommissionRate()) < 0 ||
            commissionRate.compareTo(config.getMaxCommissionRate()) > 0) {
            throw new BadRequestException(String.format(
                    "Commission rate must be between %.2f%% and %.2f%%",
                    config.getMinCommissionRate(), config.getMaxCommissionRate()));
        }

        // Check if organiser already has custom commission
        OrganiserCommission commission = organiserCommissionRepository.findByOrganiserId(organiserId)
                .orElse(OrganiserCommission.builder()
                        .organiser(User.builder().id(organiserId).build())
                        .build());

        commission.setCommissionRate(commissionRate);
        commission.setReason(reason);
        commission.setEffectiveFrom(effectiveFrom != null ? effectiveFrom : LocalDateTime.now());
        commission.setEffectiveUntil(effectiveUntil);
        commission.setIsActive(true);
        commission.setSetByAdmin(admin);

        commission = organiserCommissionRepository.save(commission);
        log.info("Set custom commission rate {}% for organiser {} by admin {}",
                commissionRate, organiserId, admin.getId());

        return commission;
    }

    /**
     * Remove custom commission rate for an organiser (revert to platform default)
     */
    @Transactional
    public void removeCustomCommissionRate(UUID organiserId) {
        organiserCommissionRepository.findByOrganiserId(organiserId)
                .ifPresent(commission -> {
                    commission.setIsActive(false);
                    organiserCommissionRepository.save(commission);
                    log.info("Removed custom commission rate for organiser {}", organiserId);
                });
    }

    /**
     * Get all custom commission rates (for admin)
     */
    public Page<OrganiserCommission> getAllCustomCommissions(Pageable pageable) {
        return organiserCommissionRepository.findAllByOrderByCreatedAtDesc(pageable);
    }

    // ==================== Commission Transactions ====================

    /**
     * Create commission transaction when payment is successful
     */
    @Transactional
    public CommissionTransaction createCommissionTransaction(Payment payment) {
        Event event = payment.getEvent();
        User organiser = event.getOrganiser();

        BigDecimal commissionRate = getCommissionRateForOrganiser(organiser.getId());
        BigDecimal saleAmount = payment.getAmount();

        CommissionTransaction transaction = CommissionTransaction.builder()
                .payment(payment)
                .event(event)
                .organiser(organiser)
                .saleAmount(saleAmount)
                .commissionRate(commissionRate)
                .currency(payment.getCurrency())
                .status(CommissionStatus.CONFIRMED)
                .build();

        transaction.calculateCommission();

        transaction = commissionTransactionRepository.save(transaction);
        log.info("Created commission transaction: sale={}, commission={}% ({}), organiser earnings={}",
                saleAmount, commissionRate, transaction.getCommissionAmount(), transaction.getOrganiserEarnings());

        return transaction;
    }

    /**
     * Mark commission as refunded when payment is refunded
     */
    @Transactional
    public void refundCommission(UUID paymentId, String reason) {
        commissionTransactionRepository.findByPaymentId(paymentId)
                .ifPresent(transaction -> {
                    transaction.setStatus(CommissionStatus.REFUNDED);
                    transaction.setNotes(reason);
                    commissionTransactionRepository.save(transaction);
                    log.info("Refunded commission for payment {}", paymentId);
                });
    }

    /**
     * Settle commissions for an organiser (mark as paid out)
     */
    @Transactional
    public List<CommissionTransaction> settleCommissions(UUID organiserId, String payoutReference) {
        List<CommissionTransaction> pendingTransactions =
                commissionTransactionRepository.findByOrganiserIdAndStatus(organiserId, CommissionStatus.CONFIRMED);

        if (pendingTransactions.isEmpty()) {
            throw new BadRequestException("No pending commissions to settle");
        }

        LocalDateTime now = LocalDateTime.now();
        for (CommissionTransaction transaction : pendingTransactions) {
            transaction.setStatus(CommissionStatus.SETTLED);
            transaction.setSettledAt(now);
            transaction.setPayoutReference(payoutReference);
        }

        commissionTransactionRepository.saveAll(pendingTransactions);
        log.info("Settled {} commission transactions for organiser {}", pendingTransactions.size(), organiserId);

        return pendingTransactions;
    }

    /**
     * Get commission transactions for an organiser
     */
    public Page<CommissionTransaction> getOrganiserTransactions(UUID organiserId, Pageable pageable) {
        return commissionTransactionRepository.findByOrganiserIdOrderByCreatedAtDesc(organiserId, pageable);
    }

    /**
     * Get commission transactions for an event
     */
    public List<CommissionTransaction> getEventTransactions(UUID eventId) {
        return commissionTransactionRepository.findByEventIdOrderByCreatedAtDesc(eventId);
    }

    // ==================== Statistics ====================

    /**
     * Get platform statistics (for admin dashboard)
     */
    public PlatformCommissionStats getPlatformStats() {
        BigDecimal totalCommission = commissionTransactionRepository.getTotalPlatformCommission();
        BigDecimal totalSales = commissionTransactionRepository.getTotalSalesAmount();
        BigDecimal pendingPayouts = commissionTransactionRepository.getTotalPendingPayouts();
        long totalTransactions = commissionTransactionRepository.count();
        long pendingTransactions = commissionTransactionRepository.countByStatus(CommissionStatus.CONFIRMED);

        return new PlatformCommissionStats(
                totalCommission,
                totalSales,
                pendingPayouts,
                totalTransactions,
                pendingTransactions
        );
    }

    /**
     * Get platform statistics for date range
     */
    public BigDecimal getPlatformCommissionInRange(LocalDateTime startDate, LocalDateTime endDate) {
        return commissionTransactionRepository.getPlatformCommissionInRange(startDate, endDate);
    }

    /**
     * Get organiser statistics (for organiser dashboard)
     */
    public OrganiserRevenueStats getOrganiserStats(UUID organiserId) {
        BigDecimal totalSales = commissionTransactionRepository.getTotalOrganiserSales(organiserId);
        BigDecimal totalEarnings = commissionTransactionRepository.getTotalOrganiserEarnings(organiserId);
        BigDecimal totalCommissionPaid = commissionTransactionRepository.getTotalCommissionPaidByOrganiser(organiserId);
        BigDecimal pendingPayout = commissionTransactionRepository.getPendingPayoutForOrganiser(organiserId);
        BigDecimal settledPayout = commissionTransactionRepository.getSettledPayoutForOrganiser(organiserId);
        BigDecimal currentCommissionRate = getCommissionRateForOrganiser(organiserId);
        long transactionCount = commissionTransactionRepository.countByOrganiserId(organiserId);

        return new OrganiserRevenueStats(
                totalSales,
                totalEarnings,
                totalCommissionPaid,
                pendingPayout,
                settledPayout,
                currentCommissionRate,
                transactionCount
        );
    }

    /**
     * Get event revenue statistics
     */
    public EventRevenueStats getEventRevenueStats(UUID eventId) {
        BigDecimal totalRevenue = commissionTransactionRepository.getTotalEventRevenue(eventId);
        BigDecimal totalCommission = commissionTransactionRepository.getTotalEventCommission(eventId);
        BigDecimal netRevenue = totalRevenue.subtract(totalCommission);

        return new EventRevenueStats(totalRevenue, totalCommission, netRevenue);
    }

    // ==================== Helpers ====================

    private void validateCommissionRate(BigDecimal rate, String fieldName) {
        if (rate.compareTo(BigDecimal.ZERO) < 0 || rate.compareTo(new BigDecimal("100")) > 0) {
            throw new BadRequestException(fieldName + " must be between 0% and 100%");
        }
    }

    // ==================== DTOs for Stats ====================

    public record PlatformCommissionStats(
            BigDecimal totalCommission,
            BigDecimal totalSales,
            BigDecimal pendingPayouts,
            long totalTransactions,
            long pendingTransactions
    ) {}

    public record OrganiserRevenueStats(
            BigDecimal totalSales,
            BigDecimal totalEarnings,
            BigDecimal totalCommissionPaid,
            BigDecimal pendingPayout,
            BigDecimal settledPayout,
            BigDecimal currentCommissionRate,
            long transactionCount
    ) {}

    public record EventRevenueStats(
            BigDecimal totalRevenue,
            BigDecimal totalCommission,
            BigDecimal netRevenue
    ) {}
}

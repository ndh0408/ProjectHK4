package com.luma.service;

import com.luma.dto.response.OrganiserBankAccountResponse;
import com.luma.dto.response.PayoutResponse;
import com.luma.dto.response.PayoutSummaryResponse;
import com.luma.entity.*;
import com.luma.entity.enums.EventStatus;
import com.luma.entity.enums.PayoutStatus;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.*;
import com.stripe.Stripe;
import com.stripe.exception.StripeException;
import com.stripe.model.Account;
import com.stripe.model.AccountLink;
import com.stripe.model.Transfer;
import com.stripe.param.AccountCreateParams;
import com.stripe.param.AccountLinkCreateParams;
import com.stripe.param.TransferCreateParams;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.scheduling.annotation.Scheduled;
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
public class PayoutService {

    private final PayoutRepository payoutRepository;
    private final OrganiserBankAccountRepository bankAccountRepository;
    private final EventRepository eventRepository;
    private final RegistrationRepository registrationRepository;
    private final PaymentRepository paymentRepository;
    private final NotificationService notificationService;
    private final CommissionService commissionService;

    @Value("${stripe.secret-key}")
    private String stripeSecretKey;

    @Value("${app.frontend-url}")
    private String frontendUrl;

    @Value("${payout.delay-hours:48}")
    private int payoutDelayHours;

    @Transactional
    public OrganiserBankAccountResponse createStripeConnectAccount(User organiser) {
        if (bankAccountRepository.existsByOrganiserId(organiser.getId())) {
            throw new BadRequestException("You already have a connected account");
        }

        Stripe.apiKey = stripeSecretKey;

        try {
            AccountCreateParams params = AccountCreateParams.builder()
                    .setType(AccountCreateParams.Type.EXPRESS)
                    .setEmail(organiser.getEmail())
                    .setCapabilities(
                            AccountCreateParams.Capabilities.builder()
                                    .setTransfers(AccountCreateParams.Capabilities.Transfers.builder()
                                            .setRequested(true)
                                            .build())
                                    .build()
                    )
                    .setBusinessType(AccountCreateParams.BusinessType.INDIVIDUAL)
                    .build();

            Account account = Account.create(params);

            OrganiserBankAccount bankAccount = OrganiserBankAccount.builder()
                    .organiser(organiser)
                    .stripeAccountId(account.getId())
                    .accountStatus("pending")
                    .payoutsEnabled(false)
                    .chargesEnabled(false)
                    .build();

            bankAccountRepository.save(bankAccount);

            String onboardingUrl = createOnboardingLink(account.getId());

            OrganiserBankAccountResponse response = OrganiserBankAccountResponse.fromEntity(bankAccount);
            response.setOnboardingUrl(onboardingUrl);

            return response;
        } catch (StripeException e) {
            log.error("Failed to create Stripe Connect account: {}", e.getMessage());
            throw new BadRequestException("Failed to create payment account: " + e.getMessage());
        }
    }

    public String getOnboardingLink(User organiser) {
        OrganiserBankAccount account = bankAccountRepository.findByOrganiserId(organiser.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Bank account not found"));

        return createOnboardingLink(account.getStripeAccountId());
    }

    private String createOnboardingLink(String stripeAccountId) {
        Stripe.apiKey = stripeSecretKey;

        try {
            AccountLinkCreateParams params = AccountLinkCreateParams.builder()
                    .setAccount(stripeAccountId)
                    .setRefreshUrl(frontendUrl + "/organiser/payout/refresh")
                    .setReturnUrl(frontendUrl + "/organiser/payout/complete")
                    .setType(AccountLinkCreateParams.Type.ACCOUNT_ONBOARDING)
                    .build();

            AccountLink accountLink = AccountLink.create(params);
            return accountLink.getUrl();
        } catch (StripeException e) {
            log.error("Failed to create onboarding link: {}", e.getMessage());
            throw new BadRequestException("Failed to create onboarding link");
        }
    }

    @Transactional
    public OrganiserBankAccountResponse refreshAccountStatus(User organiser) {
        OrganiserBankAccount bankAccount = bankAccountRepository.findByOrganiserId(organiser.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Bank account not found"));

        Stripe.apiKey = stripeSecretKey;

        try {
            Account account = Account.retrieve(bankAccount.getStripeAccountId());

            bankAccount.setPayoutsEnabled(account.getPayoutsEnabled());
            bankAccount.setChargesEnabled(account.getChargesEnabled());

            if (account.getPayoutsEnabled() && account.getChargesEnabled()) {
                bankAccount.setAccountStatus("verified");
                bankAccount.setVerifiedAt(LocalDateTime.now());
            } else if (account.getRequirements() != null &&
                    account.getRequirements().getCurrentlyDue() != null &&
                    !account.getRequirements().getCurrentlyDue().isEmpty()) {
                bankAccount.setAccountStatus("pending");
            }

            if (account.getExternalAccounts() != null &&
                    account.getExternalAccounts().getData() != null &&
                    !account.getExternalAccounts().getData().isEmpty()) {
                var externalAccount = account.getExternalAccounts().getData().get(0);
                if (externalAccount instanceof com.stripe.model.BankAccount) {
                    com.stripe.model.BankAccount stripeBankAccount = (com.stripe.model.BankAccount) externalAccount;
                    bankAccount.setBankName(stripeBankAccount.getBankName());
                    bankAccount.setLastFourDigits(stripeBankAccount.getLast4());
                    bankAccount.setCurrency(stripeBankAccount.getCurrency());
                    bankAccount.setCountry(stripeBankAccount.getCountry());
                }
            }

            bankAccountRepository.save(bankAccount);
            return OrganiserBankAccountResponse.fromEntity(bankAccount);
        } catch (StripeException e) {
            log.error("Failed to refresh account status: {}", e.getMessage());
            throw new BadRequestException("Failed to refresh account status");
        }
    }

    public OrganiserBankAccountResponse getBankAccount(User organiser) {
        return bankAccountRepository.findByOrganiserId(organiser.getId())
                .map(OrganiserBankAccountResponse::fromEntity)
                .orElse(null);
    }

    @Transactional
    public void createPayoutRecord(Event event) {
        if (event.isFree() || payoutRepository.existsByEventId(event.getId())) {
            return;
        }

        BigDecimal commissionRate = commissionService.getCommissionRateForOrganiser(event.getOrganiser().getId());

        Payout payout = Payout.builder()
                .organiser(event.getOrganiser())
                .event(event)
                .grossAmount(BigDecimal.ZERO)
                .platformFee(BigDecimal.ZERO)
                .stripeFee(BigDecimal.ZERO)
                .netAmount(BigDecimal.ZERO)
                .platformFeePercent(commissionRate)
                .status(PayoutStatus.PENDING)
                .ticketsSold(0)
                .refundedTickets(0)
                .build();

        payoutRepository.save(payout);
    }

    @Transactional
    public void updatePayoutOnTicketSale(UUID eventId, BigDecimal ticketAmount, BigDecimal stripeFee) {
        payoutRepository.findByEventId(eventId).ifPresent(payout -> {
            BigDecimal commissionRate = payout.getPlatformFeePercent();

            BigDecimal newGross = payout.getGrossAmount().add(ticketAmount);
            BigDecimal newStripeFee = payout.getStripeFee().add(stripeFee);
            BigDecimal platformFee = ticketAmount.multiply(commissionRate.divide(new BigDecimal("100"), 4, RoundingMode.HALF_UP));
            BigDecimal newPlatformFee = payout.getPlatformFee().add(platformFee);
            BigDecimal newNet = newGross.subtract(newPlatformFee).subtract(newStripeFee);

            payout.setGrossAmount(newGross);
            payout.setStripeFee(newStripeFee);
            payout.setPlatformFee(newPlatformFee);
            payout.setNetAmount(newNet);
            payout.setTicketsSold(payout.getTicketsSold() + 1);

            payoutRepository.save(payout);
        });
    }

    @Transactional
    public void updatePayoutOnRefund(UUID eventId, BigDecimal refundAmount) {
        payoutRepository.findByEventId(eventId).ifPresent(payout -> {
            BigDecimal commissionRate = payout.getPlatformFeePercent();

            BigDecimal newGross = payout.getGrossAmount().subtract(refundAmount);
            BigDecimal platformFeeReduction = refundAmount.multiply(commissionRate.divide(new BigDecimal("100"), 4, RoundingMode.HALF_UP));
            BigDecimal newPlatformFee = payout.getPlatformFee().subtract(platformFeeReduction);
            BigDecimal newNet = newGross.subtract(newPlatformFee).subtract(payout.getStripeFee());

            payout.setGrossAmount(newGross.max(BigDecimal.ZERO));
            payout.setPlatformFee(newPlatformFee.max(BigDecimal.ZERO));
            payout.setNetAmount(newNet.max(BigDecimal.ZERO));
            payout.setRefundedTickets(payout.getRefundedTickets() + 1);

            payoutRepository.save(payout);
        });
    }

    @Scheduled(cron = "0 0 * * * *")
    @Transactional
    public void processPayouts() {
        LocalDateTime cutoffTime = LocalDateTime.now().minusHours(payoutDelayHours);

        List<Payout> pendingPayouts = payoutRepository.findPendingPayoutsForCompletedEvents(
                PayoutStatus.PENDING, cutoffTime);

        for (Payout payout : pendingPayouts) {
            if (payout.getNetAmount().compareTo(BigDecimal.ZERO) <= 0) {
                payout.setStatus(PayoutStatus.COMPLETED);
                payout.setCompletedAt(LocalDateTime.now());
                payoutRepository.save(payout);
                continue;
            }

            try {
                processSinglePayout(payout);
            } catch (Exception e) {
                log.error("Failed to process payout for event {}: {}", payout.getEvent().getId(), e.getMessage());
                payout.setStatus(PayoutStatus.FAILED);
                payout.setFailureReason(e.getMessage());
                payoutRepository.save(payout);

                notificationService.sendNotification(
                        payout.getOrganiser(),
                        "Payout Failed",
                        "Payout for event '" + payout.getEvent().getTitle() + "' failed. Please contact support.",
                        com.luma.entity.enums.NotificationType.PAYMENT,
                        payout.getEvent().getId(),
                        "PAYOUT"
                );
            }
        }
    }

    @Transactional
    public void processSinglePayout(Payout payout) {
        OrganiserBankAccount bankAccount = bankAccountRepository.findByOrganiserId(payout.getOrganiser().getId())
                .orElseThrow(() -> new BadRequestException("Organiser has no connected bank account"));

        if (!bankAccount.getPayoutsEnabled()) {
            throw new BadRequestException("Organiser's bank account is not verified for payouts");
        }

        Stripe.apiKey = stripeSecretKey;

        try {
            payout.setStatus(PayoutStatus.PROCESSING);
            payout.setProcessedAt(LocalDateTime.now());
            payoutRepository.save(payout);

            TransferCreateParams params = TransferCreateParams.builder()
                    .setAmount(payout.getNetAmount().multiply(new BigDecimal("100")).longValue())
                    .setCurrency("usd")
                    .setDestination(bankAccount.getStripeAccountId())
                    .setTransferGroup("event_" + payout.getEvent().getId())
                    .putMetadata("event_id", payout.getEvent().getId().toString())
                    .putMetadata("payout_id", payout.getId().toString())
                    .build();

            Transfer transfer = Transfer.create(params);

            payout.setStripeTransferId(transfer.getId());
            payout.setStatus(PayoutStatus.COMPLETED);
            payout.setCompletedAt(LocalDateTime.now());
            payoutRepository.save(payout);

            notificationService.sendNotification(
                    payout.getOrganiser(),
                    "Payout Completed",
                    String.format("$%.2f has been transferred to your bank account for event '%s'",
                            payout.getNetAmount(), payout.getEvent().getTitle()),
                    com.luma.entity.enums.NotificationType.PAYMENT,
                    payout.getEvent().getId(),
                    "PAYOUT"
            );

            log.info("Payout completed for event {}: ${}", payout.getEvent().getId(), payout.getNetAmount());
        } catch (StripeException e) {
            log.error("Stripe transfer failed: {}", e.getMessage());
            throw new BadRequestException("Transfer failed: " + e.getMessage());
        }
    }

    @Transactional
    public PayoutResponse manualProcessPayout(UUID payoutId) {
        Payout payout = payoutRepository.findById(payoutId)
                .orElseThrow(() -> new ResourceNotFoundException("Payout not found"));

        if (payout.getStatus() != PayoutStatus.PENDING && payout.getStatus() != PayoutStatus.FAILED) {
            throw new BadRequestException("Payout is not in a processable state");
        }

        processSinglePayout(payout);
        return PayoutResponse.fromEntity(payout);
    }

    @Transactional
    public PayoutResponse putPayoutOnHold(UUID payoutId, String reason) {
        Payout payout = payoutRepository.findById(payoutId)
                .orElseThrow(() -> new ResourceNotFoundException("Payout not found"));

        if (payout.getStatus() != PayoutStatus.PENDING) {
            throw new BadRequestException("Only pending payouts can be put on hold");
        }

        payout.setStatus(PayoutStatus.ON_HOLD);
        payout.setFailureReason(reason);
        payoutRepository.save(payout);

        notificationService.sendNotification(
                payout.getOrganiser(),
                "Payout On Hold",
                "Your payout for event '" + payout.getEvent().getTitle() + "' has been placed on hold. Reason: " + reason,
                com.luma.entity.enums.NotificationType.PAYMENT,
                payout.getEvent().getId(),
                "PAYOUT"
        );

        return PayoutResponse.fromEntity(payout);
    }

    @Transactional
    public PayoutResponse releasePayoutFromHold(UUID payoutId) {
        Payout payout = payoutRepository.findById(payoutId)
                .orElseThrow(() -> new ResourceNotFoundException("Payout not found"));

        if (payout.getStatus() != PayoutStatus.ON_HOLD) {
            throw new BadRequestException("Payout is not on hold");
        }

        payout.setStatus(PayoutStatus.PENDING);
        payout.setFailureReason(null);
        payoutRepository.save(payout);

        return PayoutResponse.fromEntity(payout);
    }

    public Page<PayoutResponse> getPayoutsByOrganiser(UUID organiserId, Pageable pageable) {
        return payoutRepository.findByOrganiserId(organiserId, pageable)
                .map(PayoutResponse::fromEntity);
    }

    public Page<PayoutResponse> getAllPayouts(Pageable pageable) {
        return payoutRepository.findAllByOrderByCreatedAtDesc(pageable)
                .map(PayoutResponse::fromEntity);
    }

    public Page<PayoutResponse> getPayoutsByStatus(List<PayoutStatus> statuses, Pageable pageable) {
        return payoutRepository.findByStatusIn(statuses, pageable)
                .map(PayoutResponse::fromEntity);
    }

    public PayoutResponse getPayoutById(UUID payoutId) {
        return payoutRepository.findById(payoutId)
                .map(PayoutResponse::fromEntity)
                .orElseThrow(() -> new ResourceNotFoundException("Payout not found"));
    }

    public PayoutSummaryResponse getOrganiserPayoutSummary(UUID organiserId) {
        BigDecimal totalPaid = payoutRepository.calculateTotalPayoutsByOrganiser(organiserId);
        BigDecimal pending = payoutRepository.calculatePendingPayoutsByOrganiser(organiserId);

        return PayoutSummaryResponse.builder()
                .totalPaidOut(totalPaid)
                .pendingPayout(pending)
                .totalEarnings(totalPaid.add(pending))
                .build();
    }

    public PayoutSummaryResponse getAdminPayoutSummary() {
        BigDecimal totalPlatformFees = payoutRepository.calculateTotalPlatformFees();
        long pending = payoutRepository.countByStatus(PayoutStatus.PENDING);
        long completed = payoutRepository.countByStatus(PayoutStatus.COMPLETED);
        long failed = payoutRepository.countByStatus(PayoutStatus.FAILED);

        return PayoutSummaryResponse.builder()
                .totalPlatformFees(totalPlatformFees)
                .pendingPayoutsCount(pending)
                .completedPayoutsCount(completed)
                .failedPayoutsCount(failed)
                .totalPayouts(pending + completed + failed)
                .build();
    }
}

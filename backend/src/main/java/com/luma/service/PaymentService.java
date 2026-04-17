package com.luma.service;

import com.luma.dto.response.PaymentIntentResponse;
import com.luma.dto.response.PaymentResponse;
import com.luma.entity.Event;
import com.luma.entity.Payment;
import com.luma.entity.Registration;
import com.luma.entity.TicketType;
import com.luma.entity.User;
import com.luma.entity.enums.PaymentStatus;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.PaymentRepository;
import com.luma.repository.RegistrationRepository;
import com.luma.repository.TicketTypeRepository;
import com.stripe.Stripe;
import com.stripe.exception.StripeException;
import com.stripe.model.PaymentIntent;
import com.stripe.model.Refund;
import com.stripe.model.checkout.Session;
import com.stripe.param.PaymentIntentCreateParams;
import com.stripe.param.RefundCreateParams;
import com.stripe.param.checkout.SessionCreateParams;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class PaymentService {

    private final PaymentRepository paymentRepository;
    private final RegistrationRepository registrationRepository;
    private final TicketTypeRepository ticketTypeRepository;
    private final EventService eventService;
    private final CommissionService commissionService;
    private final CouponService couponService;

    @Value("${stripe.secret-key}")
    private String stripeSecretKey;

    @Value("${stripe.currency}")
    private String defaultCurrency;

    @Value("${app.base-url:http://localhost:5000}")
    private String appBaseUrl;

    @Value("${app.frontend-url:http://localhost:3000}")
    private String frontendUrl;

    @PostConstruct
    public void init() {
        Stripe.apiKey = stripeSecretKey;
    }

    private BigDecimal getActualPrice(Registration registration) {
        if (registration.getTicketType() != null) {
            BigDecimal unitPrice = registration.getTicketType().getPrice();
            int quantity = registration.getQuantity() != null ? registration.getQuantity() : 1;
            return unitPrice.multiply(BigDecimal.valueOf(quantity));
        }
        return registration.getEvent().getTicketPrice();
    }

    private boolean isPaymentRequired(Registration registration) {
        BigDecimal price = getActualPrice(registration);
        return price != null && price.compareTo(BigDecimal.ZERO) > 0;
    }

    private String buildPaymentDescription(Registration registration) {
        Event event = registration.getEvent();
        TicketType ticketType = registration.getTicketType();
        if (ticketType != null) {
            int quantity = registration.getQuantity() != null ? registration.getQuantity() : 1;
            return String.format("Event: %s - %s x%d", event.getTitle(), ticketType.getName(), quantity);
        }
        return "Event registration: " + event.getTitle();
    }

    @Transactional
    public PaymentIntentResponse createPaymentIntent(UUID registrationId, User user) {
        return createPaymentIntent(registrationId, user, null);
    }

    @Transactional
    public PaymentIntentResponse createPaymentIntent(UUID registrationId, User user, String couponCode) {
        Registration registration = registrationRepository.findById(registrationId)
                .orElseThrow(() -> new ResourceNotFoundException("Registration not found"));

        if (!registration.getUser().getId().equals(user.getId())) {
            throw new BadRequestException("You don't have permission to pay for this registration");
        }

        Event event = registration.getEvent();
        BigDecimal totalPrice = getActualPrice(registration);

        if (couponCode != null && !couponCode.isBlank()) {
            var couponResult = couponService.validateCoupon(couponCode, totalPrice, user, event.getId());
            if (couponResult.isValid()) {
                couponService.applyCoupon(couponCode, registration, user);
                totalPrice = couponResult.getFinalAmount();
                if (totalPrice.compareTo(BigDecimal.ZERO) <= 0) {
                    registration.setStatus(com.luma.entity.enums.RegistrationStatus.APPROVED);
                    registration.setApprovedAt(LocalDateTime.now());
                    registrationRepository.save(registration);
                    return PaymentIntentResponse.builder()
                            .amount(BigDecimal.ZERO)
                            .currency(defaultCurrency)
                            .build();
                }
            }
        }

        if (!isPaymentRequired(registration)) {
            throw new BadRequestException("This event is free and doesn't require payment");
        }

        if (paymentRepository.existsByRegistrationId(registrationId)) {
            Payment existingPayment = paymentRepository.findByRegistrationId(registrationId).get();
            if (existingPayment.getStatus() == PaymentStatus.SUCCEEDED) {
                throw new BadRequestException("Payment has already been completed for this registration");
            }
            if (existingPayment.getStripeClientSecret() != null) {
                return PaymentIntentResponse.builder()
                        .clientSecret(existingPayment.getStripeClientSecret())
                        .paymentIntentId(existingPayment.getStripePaymentIntentId())
                        .amount(existingPayment.getAmount())
                        .currency(existingPayment.getCurrency())
                        .build();
            }
        }

        try {
            long amountInCents = totalPrice.multiply(BigDecimal.valueOf(100)).longValue();

            PaymentIntentCreateParams.Builder paramsBuilder = PaymentIntentCreateParams.builder()
                    .setAmount(amountInCents)
                    .setCurrency(defaultCurrency)
                    .setDescription(buildPaymentDescription(registration))
                    .putMetadata("registration_id", registrationId.toString())
                    .putMetadata("event_id", event.getId().toString())
                    .putMetadata("user_id", user.getId().toString())
                    .setAutomaticPaymentMethods(
                            PaymentIntentCreateParams.AutomaticPaymentMethods.builder()
                                    .setEnabled(true)
                                    .build()
                    );

            if (registration.getTicketType() != null) {
                paramsBuilder.putMetadata("ticket_type_id", registration.getTicketType().getId().toString());
                paramsBuilder.putMetadata("ticket_type_name", registration.getTicketType().getName());
                paramsBuilder.putMetadata("quantity", String.valueOf(registration.getQuantity()));
            }

            PaymentIntent paymentIntent = PaymentIntent.create(paramsBuilder.build());

            Payment payment = paymentRepository.findByRegistrationId(registrationId)
                    .orElse(Payment.builder()
                            .registration(registration)
                            .event(event)
                            .user(user)
                            .build());

            payment.setAmount(totalPrice);
            payment.setCurrency(defaultCurrency);
            payment.setStripePaymentIntentId(paymentIntent.getId());
            payment.setStripeClientSecret(paymentIntent.getClientSecret());
            payment.setStatus(PaymentStatus.PENDING);

            paymentRepository.save(payment);

            log.info("Created payment intent {} for registration {}", paymentIntent.getId(), registrationId);

            return PaymentIntentResponse.builder()
                    .clientSecret(paymentIntent.getClientSecret())
                    .paymentIntentId(paymentIntent.getId())
                    .amount(totalPrice)
                    .currency(defaultCurrency)
                    .build();

        } catch (StripeException e) {
            log.error("Stripe error creating payment intent: {}", e.getMessage());
            throw new BadRequestException("Failed to create payment: " + e.getMessage());
        }
    }

    @Transactional
    public PaymentResponse confirmPayment(UUID registrationId, User user) {
        Payment payment = paymentRepository.findByRegistrationId(registrationId)
                .orElseThrow(() -> new ResourceNotFoundException("Payment not found for this registration"));

        if (!payment.getUser().getId().equals(user.getId())) {
            throw new BadRequestException("You don't have permission to confirm this payment");
        }

        if (payment.getStatus() == PaymentStatus.SUCCEEDED) {
            return PaymentResponse.fromEntity(payment);
        }

        try {
            String paymentIntentId = payment.getStripePaymentIntentId();
            String checkoutStatus = null;

            String sessionId = payment.getStripeClientSecret();
            if (sessionId != null && sessionId.startsWith("cs_")) {
                com.stripe.model.checkout.Session session = com.stripe.model.checkout.Session.retrieve(sessionId);
                checkoutStatus = session.getPaymentStatus();
                if (session.getPaymentIntent() != null) {
                    paymentIntentId = session.getPaymentIntent();
                    if (!paymentIntentId.equals(payment.getStripePaymentIntentId())) {
                        payment.setStripePaymentIntentId(paymentIntentId);
                    }
                }
            }

            if (paymentIntentId == null) {
                if ("paid".equals(checkoutStatus)) {
                    payment.setStatus(PaymentStatus.SUCCEEDED);
                    payment.setPaidAt(LocalDateTime.now());
                    paymentRepository.save(payment);

                    Registration registration = payment.getRegistration();
                    if (registration.getStatus() != RegistrationStatus.APPROVED) {
                        registration.setStatus(RegistrationStatus.APPROVED);
                        registration.setApprovedAt(LocalDateTime.now());
                        registrationRepository.save(registration);
                        eventService.incrementApprovedCount(payment.getEvent());
                        commissionService.createCommissionTransaction(payment);
                    }
                    return PaymentResponse.fromEntity(payment);
                }
                log.warn("Payment {} has no paymentIntentId yet, checkout status: {}", payment.getId(), checkoutStatus);
                return PaymentResponse.fromEntity(payment);
            }

            PaymentIntent paymentIntent = PaymentIntent.retrieve(paymentIntentId);

            if ("succeeded".equals(paymentIntent.getStatus()) || "paid".equals(checkoutStatus)) {
                payment.setStatus(PaymentStatus.SUCCEEDED);
                payment.setPaidAt(LocalDateTime.now());
                payment.setPaymentMethod(paymentIntent.getPaymentMethod());
                paymentRepository.save(payment);

                Registration registration = payment.getRegistration();
                if (registration.getStatus() != RegistrationStatus.APPROVED) {
                    registration.setStatus(RegistrationStatus.APPROVED);
                    registration.setApprovedAt(LocalDateTime.now());
                    registrationRepository.save(registration);

                    eventService.incrementApprovedCount(payment.getEvent());

                    commissionService.createCommissionTransaction(payment);
                }

                log.info("Payment confirmed and registration approved for registration {}", registrationId);

            } else if ("canceled".equals(paymentIntent.getStatus())) {
                payment.setStatus(PaymentStatus.CANCELLED);
                paymentRepository.save(payment);
            } else if ("requires_payment_method".equals(paymentIntent.getStatus()) ||
                       "requires_action".equals(paymentIntent.getStatus())) {
                payment.setStatus(PaymentStatus.PROCESSING);
                paymentRepository.save(payment);
            } else {
                log.warn("Unexpected payment intent status: {}", paymentIntent.getStatus());
            }

            return PaymentResponse.fromEntity(payment);

        } catch (StripeException e) {
            log.error("Stripe error confirming payment: {}", e.getMessage());
            payment.setStatus(PaymentStatus.FAILED);
            payment.setFailureReason(e.getMessage());
            paymentRepository.save(payment);
            throw new BadRequestException("Failed to confirm payment: " + e.getMessage());
        }
    }

    @Transactional
    public void handlePaymentIntentSucceeded(String paymentIntentId) {
        Payment payment = paymentRepository.findByStripePaymentIntentId(paymentIntentId)
                .orElse(null);

        if (payment == null) {
            log.warn("Payment not found for payment intent: {}", paymentIntentId);
            return;
        }

        if (payment.getStatus() == PaymentStatus.SUCCEEDED) {
            log.info("Payment already marked as succeeded: {}", paymentIntentId);
            return;
        }

        payment.setStatus(PaymentStatus.SUCCEEDED);
        payment.setPaidAt(LocalDateTime.now());
        paymentRepository.save(payment);

        Registration registration = payment.getRegistration();
        if (registration.getStatus() != RegistrationStatus.APPROVED) {
            registration.setStatus(RegistrationStatus.APPROVED);
            registration.setApprovedAt(LocalDateTime.now());
            registrationRepository.save(registration);
            eventService.incrementApprovedCount(payment.getEvent());

            commissionService.createCommissionTransaction(payment);
        }

        log.info("Webhook: Payment succeeded for payment intent {}", paymentIntentId);
    }

    @Transactional
    public void handlePaymentIntentFailed(String paymentIntentId, String failureMessage) {
        Payment payment = paymentRepository.findByStripePaymentIntentId(paymentIntentId)
                .orElse(null);

        if (payment == null) {
            log.warn("Payment not found for payment intent: {}", paymentIntentId);
            return;
        }

        payment.setStatus(PaymentStatus.FAILED);
        payment.setFailureReason(failureMessage);
        paymentRepository.save(payment);

        log.info("Webhook: Payment failed for payment intent {}: {}", paymentIntentId, failureMessage);
    }

    public PaymentResponse getPaymentByRegistrationId(UUID registrationId, User user) {
        Payment payment = paymentRepository.findByRegistrationId(registrationId)
                .orElseThrow(() -> new ResourceNotFoundException("Payment not found"));

        if (!payment.getUser().getId().equals(user.getId())) {
            throw new BadRequestException("You don't have permission to view this payment");
        }

        return PaymentResponse.fromEntity(payment);
    }

    @Transactional
    public PaymentResponse processRefund(UUID registrationId, User organiser, String reason, BigDecimal refundAmount) {
        Payment payment = paymentRepository.findByRegistrationId(registrationId)
                .orElseThrow(() -> new ResourceNotFoundException("Payment not found for this registration"));

        Registration registration = payment.getRegistration();
        Event event = registration.getEvent();

        if (!event.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You don't have permission to process refunds for this event");
        }

        if (payment.getStatus() != PaymentStatus.SUCCEEDED) {
            throw new BadRequestException("Can only refund successful payments");
        }

        if (payment.getStatus() == PaymentStatus.REFUNDED) {
            throw new BadRequestException("Payment has already been refunded");
        }

        BigDecimal maxRefundable = payment.getAmount();
        if (payment.getRefundAmount() != null) {
            maxRefundable = maxRefundable.subtract(payment.getRefundAmount());
        }

        if (refundAmount == null) {
            refundAmount = maxRefundable;
        }

        if (refundAmount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new BadRequestException("Refund amount must be greater than zero");
        }

        if (refundAmount.compareTo(maxRefundable) > 0) {
            throw new BadRequestException("Refund amount exceeds maximum refundable amount: " + maxRefundable);
        }

        try {
            long amountInCents = refundAmount.multiply(BigDecimal.valueOf(100)).longValue();

            RefundCreateParams.Builder paramsBuilder = RefundCreateParams.builder()
                    .setPaymentIntent(payment.getStripePaymentIntentId())
                    .setAmount(amountInCents);

            if (reason != null && !reason.isEmpty()) {
                paramsBuilder.setReason(RefundCreateParams.Reason.REQUESTED_BY_CUSTOMER);
            }

            Refund refund = Refund.create(paramsBuilder.build());

            BigDecimal totalRefunded = payment.getRefundAmount() != null
                    ? payment.getRefundAmount().add(refundAmount)
                    : refundAmount;
            payment.setRefundAmount(totalRefunded);
            payment.setStripeRefundId(refund.getId());
            payment.setRefundReason(reason);
            payment.setRefundedAt(LocalDateTime.now());

            if (totalRefunded.compareTo(payment.getAmount()) >= 0) {
                payment.setStatus(PaymentStatus.REFUNDED);

                registration.setStatus(RegistrationStatus.CANCELLED);
                registrationRepository.save(registration);

                if (registration.getTicketType() != null && registration.getQuantity() != null) {
                    ticketTypeRepository.decrementSoldCount(
                            registration.getTicketType().getId(),
                            registration.getQuantity()
                    );
                }

                eventService.decrementApprovedCount(event);
            }

            paymentRepository.save(payment);

            log.info("Refund processed: {} for payment {}, amount: {}",
                    refund.getId(), payment.getId(), refundAmount);

            return PaymentResponse.fromEntity(payment);

        } catch (StripeException e) {
            log.error("Stripe error processing refund: {}", e.getMessage());
            throw new BadRequestException("Failed to process refund: " + e.getMessage());
        }
    }

    @Transactional
    public void handleRefundSucceeded(String paymentIntentId, String refundId, long amountRefunded) {
        Payment payment = paymentRepository.findByStripePaymentIntentId(paymentIntentId)
                .orElse(null);

        if (payment == null) {
            log.warn("Payment not found for refund webhook: {}", paymentIntentId);
            return;
        }

        BigDecimal refundAmount = BigDecimal.valueOf(amountRefunded).divide(BigDecimal.valueOf(100));

        BigDecimal totalRefunded = payment.getRefundAmount() != null
                ? payment.getRefundAmount().add(refundAmount)
                : refundAmount;

        payment.setRefundAmount(totalRefunded);
        payment.setStripeRefundId(refundId);
        payment.setRefundedAt(LocalDateTime.now());

        if (totalRefunded.compareTo(payment.getAmount()) >= 0) {
            payment.setStatus(PaymentStatus.REFUNDED);
        }

        paymentRepository.save(payment);

        log.info("Webhook: Refund succeeded for payment intent {}, refund: {}, amount: {}",
                paymentIntentId, refundId, refundAmount);
    }

    @Transactional
    public PaymentIntentResponse createCheckoutSession(UUID registrationId, User user) {
        return createCheckoutSession(registrationId, user, null);
    }

    @Transactional
    public PaymentIntentResponse createCheckoutSession(UUID registrationId, User user, String couponCode) {
        Registration registration = registrationRepository.findById(registrationId)
                .orElseThrow(() -> new ResourceNotFoundException("Registration not found"));

        if (!registration.getUser().getId().equals(user.getId())) {
            throw new BadRequestException("You don't have permission to pay for this registration");
        }

        Event event = registration.getEvent();
        BigDecimal totalPrice = getActualPrice(registration);

        if (!isPaymentRequired(registration)) {
            throw new BadRequestException("This event is free and doesn't require payment");
        }

        if (couponCode != null && !couponCode.isBlank()) {
            var couponResult = couponService.validateCoupon(couponCode, totalPrice, user, event.getId());
            if (couponResult.isValid()) {
                couponService.applyCoupon(couponCode, registration, user);
                totalPrice = couponResult.getFinalAmount();
                if (totalPrice.compareTo(BigDecimal.ZERO) <= 0) {
                    registration.setStatus(com.luma.entity.enums.RegistrationStatus.APPROVED);
                    registration.setApprovedAt(LocalDateTime.now());
                    registrationRepository.save(registration);
                    return PaymentIntentResponse.builder()
                            .amount(BigDecimal.ZERO)
                            .currency(defaultCurrency)
                            .build();
                }
            }
        }

        if (paymentRepository.existsByRegistrationId(registrationId)) {
            Payment existingPayment = paymentRepository.findByRegistrationId(registrationId).get();
            if (existingPayment.getStatus() == PaymentStatus.SUCCEEDED) {
                throw new BadRequestException("Payment has already been completed for this registration");
            }
        }

        try {
            String successUrl = appBaseUrl + "/#/payment-success?registration_id=" + registrationId;
            String cancelUrl = appBaseUrl + "/#/payment-cancelled?registration_id=" + registrationId;

            String productName;
            String productDescription;
            long quantity = 1L;
            long amountInCents;

            if (registration.getTicketType() != null) {
                TicketType ticketType = registration.getTicketType();
                productName = event.getTitle() + " - " + ticketType.getName();
                productDescription = ticketType.getDescription() != null
                        ? ticketType.getDescription()
                        : "Ticket for " + event.getTitle();
                quantity = registration.getQuantity() != null ? registration.getQuantity() : 1L;
                amountInCents = ticketType.getPrice().multiply(BigDecimal.valueOf(100)).longValue();
            } else {
                productName = "Event Registration: " + event.getTitle();
                productDescription = "Registration for " + event.getTitle();
                amountInCents = totalPrice.multiply(BigDecimal.valueOf(100)).longValue();
            }

            SessionCreateParams.Builder paramsBuilder = SessionCreateParams.builder()
                    .setMode(SessionCreateParams.Mode.PAYMENT)
                    .setSuccessUrl(successUrl)
                    .setCancelUrl(cancelUrl)
                    .addLineItem(SessionCreateParams.LineItem.builder()
                            .setQuantity(quantity)
                            .setPriceData(SessionCreateParams.LineItem.PriceData.builder()
                                    .setCurrency(defaultCurrency)
                                    .setUnitAmount(amountInCents)
                                    .setProductData(SessionCreateParams.LineItem.PriceData.ProductData.builder()
                                            .setName(productName)
                                            .setDescription(productDescription)
                                            .build())
                                    .build())
                            .build())
                    .putMetadata("registration_id", registrationId.toString())
                    .putMetadata("event_id", event.getId().toString())
                    .putMetadata("user_id", user.getId().toString());

            if (registration.getTicketType() != null) {
                paramsBuilder.putMetadata("ticket_type_id", registration.getTicketType().getId().toString());
                paramsBuilder.putMetadata("ticket_type_name", registration.getTicketType().getName());
                paramsBuilder.putMetadata("quantity", String.valueOf(registration.getQuantity()));
            }

            Session session = Session.create(paramsBuilder.build());

            Payment payment = paymentRepository.findByRegistrationId(registrationId)
                    .orElse(Payment.builder()
                            .registration(registration)
                            .event(event)
                            .user(user)
                            .build());

            payment.setAmount(totalPrice);
            payment.setCurrency(defaultCurrency);
            payment.setStripePaymentIntentId(session.getPaymentIntent());
            payment.setStripeClientSecret(session.getId());
            payment.setStatus(PaymentStatus.PENDING);

            paymentRepository.save(payment);

            log.info("Created checkout session {} for registration {}", session.getId(), registrationId);

            return PaymentIntentResponse.builder()
                    .checkoutUrl(session.getUrl())
                    .paymentIntentId(session.getId())
                    .amount(totalPrice)
                    .currency(defaultCurrency)
                    .build();

        } catch (StripeException e) {
            log.error("Stripe error creating checkout session: {}", e.getMessage());
            throw new BadRequestException("Failed to create checkout session: " + e.getMessage());
        }
    }

    public String createSubscriptionCheckoutSession(UUID userId, String planName, BigDecimal amount) {
        try {
            SessionCreateParams params = SessionCreateParams.builder()
                    .setMode(SessionCreateParams.Mode.PAYMENT)
                    .setSuccessUrl(frontendUrl + "/organiser/subscription?success=true&plan=" + planName)
                    .setCancelUrl(frontendUrl + "/organiser/subscription?canceled=true")
                    .addLineItem(
                            SessionCreateParams.LineItem.builder()
                                    .setPriceData(
                                            SessionCreateParams.LineItem.PriceData.builder()
                                                    .setCurrency(defaultCurrency)
                                                    .setUnitAmount(amount.multiply(BigDecimal.valueOf(100)).longValue())
                                                    .setProductData(
                                                            SessionCreateParams.LineItem.PriceData.ProductData.builder()
                                                                    .setName("LUMA " + planName + " Subscription")
                                                                    .setDescription("Monthly subscription to " + planName + " plan")
                                                                    .build()
                                                    )
                                                    .build()
                                    )
                                    .setQuantity(1L)
                                    .build()
                    )
                    .putMetadata("type", "subscription")
                    .putMetadata("user_id", userId.toString())
                    .putMetadata("plan", planName)
                    .build();

            Session session = Session.create(params);
            log.info("Created subscription checkout session {} for user {} - plan {}", session.getId(), userId, planName);
            return session.getUrl();

        } catch (StripeException e) {
            log.error("Stripe error creating subscription checkout: {}", e.getMessage());
            throw new BadRequestException("Failed to create subscription checkout: " + e.getMessage());
        }
    }

    public String createBoostCheckoutSession(UUID userId, UUID eventId, String packageName,
            BigDecimal amount, int days, UUID boostId, String action, UUID existingBoostId) {
        try {
            String productName;
            String description;

            switch (action) {
                case "EXTEND":
                    productName = "Extend Boost - " + packageName;
                    description = "Extend your boost by " + days + " more days";
                    break;
                case "UPGRADE":
                    productName = "Upgrade Boost to " + packageName;
                    description = "Upgrade your boost to " + packageName + " package for " + days + " days";
                    break;
                case "DOWNGRADE":
                    productName = "Change Boost to " + packageName;
                    description = "Change your boost to " + packageName + " package for " + days + " days";
                    break;
                default:
                    productName = "Event Boost - " + packageName;
                    description = "Boost your event for " + days + " days";
                    break;
            }

            String successUrl = frontendUrl + "/organiser/boost?success=true&boost=" + boostId + "&action=" + action;
            if (existingBoostId != null) {
                successUrl += "&existingBoostId=" + existingBoostId;
            }

            var paramsBuilder = SessionCreateParams.builder()
                    .setMode(SessionCreateParams.Mode.PAYMENT)
                    .setSuccessUrl(successUrl)
                    .setCancelUrl(frontendUrl + "/organiser/boost?canceled=true&boost=" + boostId)
                    .addLineItem(
                            SessionCreateParams.LineItem.builder()
                                    .setPriceData(
                                            SessionCreateParams.LineItem.PriceData.builder()
                                                    .setCurrency(defaultCurrency)
                                                    .setUnitAmount(amount.multiply(BigDecimal.valueOf(100)).longValue())
                                                    .setProductData(
                                                            SessionCreateParams.LineItem.PriceData.ProductData.builder()
                                                                    .setName(productName)
                                                                    .setDescription(description)
                                                                    .build()
                                                    )
                                                    .build()
                                    )
                                    .setQuantity(1L)
                                    .build()
                    )
                    .putMetadata("type", "boost")
                    .putMetadata("boost_id", boostId.toString())
                    .putMetadata("user_id", userId.toString())
                    .putMetadata("event_id", eventId.toString())
                    .putMetadata("package", packageName)
                    .putMetadata("days", String.valueOf(days))
                    .putMetadata("action", action);

            if (existingBoostId != null) {
                paramsBuilder.putMetadata("existing_boost_id", existingBoostId.toString());
            }

            Session session = Session.create(paramsBuilder.build());
            log.info("Created boost checkout session {} for boost {} - action {} - user {} - event {}",
                    session.getId(), boostId, action, userId, eventId);
            return session.getUrl();

        } catch (StripeException e) {
            log.error("Stripe error creating boost checkout: {}", e.getMessage());
            throw new BadRequestException("Failed to create boost checkout: " + e.getMessage());
        }
    }

    public String createUserBoostCheckoutSession(UUID userId, UUID eventId, String packageName,
            BigDecimal amount, int days, UUID boostId) {
        try {
            String productName = "Mini Boost - " + packageName;
            String description = "Boost your event for " + days + " days with " + packageName + " package";

            String successUrl = appBaseUrl + "/#/my-events?boost_success=true&boost=" + boostId;
            String cancelUrl = appBaseUrl + "/#/my-events?boost_canceled=true";

            SessionCreateParams params = SessionCreateParams.builder()
                    .setMode(SessionCreateParams.Mode.PAYMENT)
                    .setSuccessUrl(successUrl)
                    .setCancelUrl(cancelUrl)
                    .addLineItem(
                            SessionCreateParams.LineItem.builder()
                                    .setPriceData(
                                            SessionCreateParams.LineItem.PriceData.builder()
                                                    .setCurrency(defaultCurrency)
                                                    .setUnitAmount(amount.multiply(BigDecimal.valueOf(100)).longValue())
                                                    .setProductData(
                                                            SessionCreateParams.LineItem.PriceData.ProductData.builder()
                                                                    .setName(productName)
                                                                    .setDescription(description)
                                                                    .build()
                                                    )
                                                    .build()
                                    )
                                    .setQuantity(1L)
                                    .build()
                    )
                    .putMetadata("type", "user_boost")
                    .putMetadata("boost_id", boostId.toString())
                    .putMetadata("user_id", userId.toString())
                    .putMetadata("event_id", eventId.toString())
                    .putMetadata("package", packageName)
                    .putMetadata("days", String.valueOf(days))
                    .build();

            Session session = Session.create(params);
            log.info("Created user boost checkout session {} for boost {} - user {} - event {}",
                    session.getId(), boostId, userId, eventId);
            return session.getUrl();

        } catch (StripeException e) {
            log.error("Stripe error creating user boost checkout: {}", e.getMessage());
            throw new BadRequestException("Failed to create boost checkout: " + e.getMessage());
        }
    }

    public String createExtraEventCheckoutSession(UUID userId, int quantity, BigDecimal pricePerEvent) {
        try {
            BigDecimal totalAmount = pricePerEvent.multiply(BigDecimal.valueOf(quantity));

            String productName = "Extra Event Slot" + (quantity > 1 ? "s" : "");
            String description = quantity + " additional event slot" + (quantity > 1 ? "s" : "") + " for creating events";

            String successUrl = appBaseUrl + "/#/my-events?purchase_success=true&quantity=" + quantity;
            String cancelUrl = appBaseUrl + "/#/my-events?purchase_canceled=true";

            SessionCreateParams params = SessionCreateParams.builder()
                    .setMode(SessionCreateParams.Mode.PAYMENT)
                    .setSuccessUrl(successUrl)
                    .setCancelUrl(cancelUrl)
                    .addLineItem(
                            SessionCreateParams.LineItem.builder()
                                    .setPriceData(
                                            SessionCreateParams.LineItem.PriceData.builder()
                                                    .setCurrency(defaultCurrency)
                                                    .setUnitAmount(pricePerEvent.multiply(BigDecimal.valueOf(100)).longValue())
                                                    .setProductData(
                                                            SessionCreateParams.LineItem.PriceData.ProductData.builder()
                                                                    .setName(productName)
                                                                    .setDescription(description)
                                                                    .build()
                                                    )
                                                    .build()
                                    )
                                    .setQuantity((long) quantity)
                                    .build()
                    )
                    .putMetadata("type", "extra_event")
                    .putMetadata("user_id", userId.toString())
                    .putMetadata("quantity", String.valueOf(quantity))
                    .putMetadata("price_per_event", pricePerEvent.toString())
                    .build();

            Session session = Session.create(params);
            log.info("Created extra event checkout session {} for user {} - quantity {}",
                    session.getId(), userId, quantity);
            return session.getUrl();

        } catch (StripeException e) {
            log.error("Stripe error creating extra event checkout: {}", e.getMessage());
            throw new BadRequestException("Failed to create checkout: " + e.getMessage());
        }
    }
}

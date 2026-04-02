package com.luma.controller.webhook;

import com.luma.service.PaymentService;
import com.luma.service.OrganiserSubscriptionService;
import com.luma.service.EventBoostService;
import com.luma.service.UserBoostService;
import com.luma.service.UserEventLimitService;
import com.luma.service.WebhookService;
import com.stripe.exception.SignatureVerificationException;
import com.stripe.model.Event;
import com.stripe.model.PaymentIntent;
import com.stripe.model.Refund;
import com.stripe.model.checkout.Session;
import com.stripe.net.Webhook;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;
import com.luma.entity.enums.SubscriptionPlan;

@Slf4j
@RestController
@RequestMapping("/api/webhooks")
@RequiredArgsConstructor
public class StripeWebhookController {

    private final PaymentService paymentService;
    private final WebhookService webhookService;
    private final OrganiserSubscriptionService subscriptionService;
    private final EventBoostService boostService;
    private final UserBoostService userBoostService;
    private final UserEventLimitService userEventLimitService;

    @Value("${stripe.webhook-secret}")
    private String webhookSecret;

    @PostMapping("/stripe")
    public ResponseEntity<String> handleStripeWebhook(
            @RequestBody String payload,
            @RequestHeader("Stripe-Signature") String sigHeader) {

        Event event;
        try {
            event = Webhook.constructEvent(payload, sigHeader, webhookSecret);
        } catch (SignatureVerificationException e) {
            log.error("Stripe webhook signature verification failed: {}", e.getMessage());
            return ResponseEntity.badRequest().body("Invalid signature");
        }

        log.info("Received Stripe webhook event: {} (id: {})", event.getType(), event.getId());

        if (!webhookService.markEventAsProcessed(event.getId(), event.getType(), "stripe")) {
            log.info("Webhook event {} already processed, returning success", event.getId());
            return ResponseEntity.ok("Event already processed");
        }

        try {
            switch (event.getType()) {
                case "payment_intent.succeeded":
                    PaymentIntent successIntent = (PaymentIntent) event.getDataObjectDeserializer()
                            .getObject().orElse(null);
                    if (successIntent != null) {
                        paymentService.handlePaymentIntentSucceeded(successIntent.getId());
                    }
                    break;

                case "payment_intent.payment_failed":
                    PaymentIntent failedIntent = (PaymentIntent) event.getDataObjectDeserializer()
                            .getObject().orElse(null);
                    if (failedIntent != null) {
                        String failureMessage = failedIntent.getLastPaymentError() != null
                                ? failedIntent.getLastPaymentError().getMessage()
                                : "Payment failed";
                        paymentService.handlePaymentIntentFailed(failedIntent.getId(), failureMessage);
                    }
                    break;

                case "charge.refunded":
                    Refund refund = (Refund) event.getDataObjectDeserializer()
                            .getObject().orElse(null);
                    if (refund != null) {
                        paymentService.handleRefundSucceeded(
                                refund.getPaymentIntent(),
                                refund.getId(),
                                refund.getAmount()
                        );
                    }
                    break;

                case "checkout.session.completed":
                    Session session = (Session) event.getDataObjectDeserializer()
                            .getObject().orElse(null);
                    if (session != null && session.getPaymentStatus().equals("paid")) {
                        handleCheckoutSessionCompleted(session);
                    }
                    break;

                default:
                    log.debug("Unhandled Stripe event type: {}", event.getType());
            }
        } catch (Exception e) {
            log.error("Error processing webhook event {}: {}", event.getId(), e.getMessage(), e);
        }

        return ResponseEntity.ok("Webhook received");
    }

    private void handleCheckoutSessionCompleted(Session session) {
        String type = session.getMetadata().get("type");

        if ("subscription".equals(type)) {
            String userId = session.getMetadata().get("user_id");
            String planName = session.getMetadata().get("plan");

            try {
                SubscriptionPlan plan = SubscriptionPlan.valueOf(planName);
                subscriptionService.upgradePlan(UUID.fromString(userId), plan);
                log.info("Subscription upgraded to {} for user {}", planName, userId);
            } catch (Exception e) {
                log.error("Error upgrading subscription: {}", e.getMessage(), e);
            }

        } else if ("boost".equals(type)) {
            String boostIdStr = session.getMetadata().get("boost_id");
            String paymentIntentId = session.getPaymentIntent();

            try {
                UUID boostId = UUID.fromString(boostIdStr);
                boostService.activateBoost(boostId, paymentIntentId);
                log.info("Boost {} activated after successful payment {}", boostId, paymentIntentId);
            } catch (Exception e) {
                log.error("Error activating boost: {}", e.getMessage(), e);
            }

        } else if ("user_boost".equals(type)) {
            String boostIdStr = session.getMetadata().get("boost_id");
            String paymentIntentId = session.getPaymentIntent();

            try {
                UUID boostId = UUID.fromString(boostIdStr);
                userBoostService.activateBoost(boostId, paymentIntentId);
                log.info("User boost {} activated after successful payment {}", boostId, paymentIntentId);
            } catch (Exception e) {
                log.error("Error activating user boost: {}", e.getMessage(), e);
            }

        } else if ("extra_event".equals(type)) {
            String userId = session.getMetadata().get("user_id");
            String quantityStr = session.getMetadata().get("quantity");
            String paymentIntentId = session.getPaymentIntent();

            try {
                int quantity = Integer.parseInt(quantityStr);
                userEventLimitService.purchaseExtraEventAfterPayment(
                        UUID.fromString(userId), quantity, paymentIntentId);
                log.info("User {} purchased {} extra event(s) after payment {}", userId, quantity, paymentIntentId);
            } catch (Exception e) {
                log.error("Error processing extra event purchase: {}", e.getMessage(), e);
            }
        }
    }
}

package com.luma.service;

import com.luma.dto.request.CreateCouponRequest;
import com.luma.dto.response.CouponResponse;
import com.luma.dto.response.CouponValidationResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.*;
import com.luma.entity.enums.CouponStatus;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.CouponRepository;
import com.luma.repository.CouponUsageRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class CouponService {

    private final CouponRepository couponRepository;
    private final CouponUsageRepository couponUsageRepository;
    private final EventService eventService;

    @Transactional
    public CouponResponse createCoupon(CreateCouponRequest request, User creator) {
        if (couponRepository.existsByCode(request.getCode().toUpperCase())) {
            throw new BadRequestException("Coupon code already exists");
        }

        Coupon coupon = Coupon.builder()
                .code(request.getCode().toUpperCase())
                .description(request.getDescription())
                .discountType(request.getDiscountType())
                .discountValue(request.getDiscountValue())
                .maxDiscountAmount(request.getMaxDiscountAmount())
                .minOrderAmount(request.getMinOrderAmount())
                .createdBy(creator)
                .maxUsageCount(request.getMaxUsageCount())
                .maxUsagePerUser(request.getMaxUsagePerUser())
                .validFrom(request.getValidFrom())
                .validUntil(request.getValidUntil())
                .build();

        if (request.getEventId() != null) {
            Event event = eventService.getEntityById(request.getEventId());
            if (!event.getOrganiser().getId().equals(creator.getId())) {
                throw new BadRequestException("You can only create coupons for your own events");
            }
            coupon.setEvent(event);
        }

        coupon = couponRepository.save(coupon);
        log.info("Coupon created: {} by user {}", coupon.getCode(), creator.getId());
        return CouponResponse.fromEntity(coupon);
    }

    @Transactional(readOnly = true)
    public CouponValidationResponse validateCoupon(String code, BigDecimal orderAmount, User user, UUID eventId) {
        return validateCoupon(code, orderAmount, user, eventId, null);
    }

    @Transactional(readOnly = true)
    public CouponValidationResponse validateCoupon(String code, BigDecimal orderAmount, User user, UUID eventId, UUID registrationId) {
        Coupon coupon = couponRepository.findActiveByCode(code.toUpperCase())
                .orElse(null);

        if (coupon == null) {
            return CouponValidationResponse.builder()
                    .valid(false)
                    .message("Invalid coupon code")
                    .build();
        }

        if (!coupon.isValid()) {
            return CouponValidationResponse.builder()
                    .valid(false)
                    .message("This coupon has expired or is no longer valid")
                    .build();
        }

        // Scope check: event-specific coupons must target this exact event;
        // organiser-wide coupons (coupon.event == null) must be authored by
        // the organiser that owns this event. This prevents an organiser's
        // promo code from being redeemed against another organiser's events.
        if (coupon.getEvent() != null) {
            if (!coupon.getEvent().getId().equals(eventId)) {
                return CouponValidationResponse.builder()
                        .valid(false)
                        .message("This coupon is not valid for this event")
                        .build();
            }
        } else {
            Event targetEvent = eventService.getEntityById(eventId);
            UUID targetOrganiserId = targetEvent.getOrganiser() != null
                    ? targetEvent.getOrganiser().getId()
                    : null;
            UUID creatorId = coupon.getCreatedBy() != null
                    ? coupon.getCreatedBy().getId()
                    : null;
            if (targetOrganiserId == null
                    || creatorId == null
                    || !creatorId.equals(targetOrganiserId)) {
                return CouponValidationResponse.builder()
                        .valid(false)
                        .message("This coupon is not valid for this event")
                        .build();
            }
        }

        if (coupon.getMinOrderAmount() != null && orderAmount.compareTo(coupon.getMinOrderAmount()) < 0) {
            return CouponValidationResponse.builder()
                    .valid(false)
                    .message("Minimum order amount is " + coupon.getMinOrderAmount())
                    .build();
        }

        if (coupon.getMaxUsagePerUser() != null) {
            long userUsage = couponUsageRepository.countByCouponAndUser(coupon, user);
            // When re-validating a coupon that is already attached to the
            // registration we are about to pay for (e.g. user tapped Retry),
            // the existing usage row shouldn't count against the per-user
            // quota or we would block the very same checkout we just started.
            if (registrationId != null) {
                var existing = couponUsageRepository.findByRegistrationId(registrationId);
                if (existing.isPresent() && existing.get().getCoupon().getId().equals(coupon.getId())) {
                    userUsage = Math.max(0, userUsage - 1);
                }
            }
            if (userUsage >= coupon.getMaxUsagePerUser()) {
                return CouponValidationResponse.builder()
                        .valid(false)
                        .message("You have already used this coupon the maximum number of times")
                        .build();
            }
        }

        BigDecimal discount = coupon.calculateDiscount(orderAmount);
        BigDecimal finalAmount = orderAmount.subtract(discount);

        return CouponValidationResponse.builder()
                .valid(true)
                .message("Coupon applied successfully")
                .code(coupon.getCode())
                .description(coupon.getDescription())
                .discountAmount(discount)
                .originalAmount(orderAmount)
                .finalAmount(finalAmount.max(BigDecimal.ZERO))
                .build();
    }

    @Transactional
    public CouponUsage applyCoupon(String code, Registration registration, User user) {
        Coupon coupon = couponRepository.findActiveByCode(code.toUpperCase())
                .orElseThrow(() -> new BadRequestException("Invalid coupon code"));

        if (!coupon.isValid()) {
            throw new BadRequestException("Coupon is no longer valid");
        }

        // Idempotent for retries & coupon swaps while the registration is still
        // pending payment: reuse the existing usage if the same code is being
        // re-applied, or replace it if the user picked a different coupon.
        var existingUsage = couponUsageRepository.findByRegistrationId(registration.getId());
        if (existingUsage.isPresent()) {
            CouponUsage prior = existingUsage.get();
            if (prior.getCoupon().getId().equals(coupon.getId())) {
                return prior;
            }
            couponRepository.decrementUsedCount(prior.getCoupon().getId());
            couponUsageRepository.delete(prior);
            couponUsageRepository.flush();
        }

        BigDecimal orderAmount = getOrderAmount(registration);
        BigDecimal discount = coupon.calculateDiscount(orderAmount);

        CouponUsage usage = CouponUsage.builder()
                .coupon(coupon)
                .user(user)
                .registration(registration)
                .discountAmount(discount)
                .originalAmount(orderAmount)
                .finalAmount(orderAmount.subtract(discount).max(BigDecimal.ZERO))
                .build();

        couponUsageRepository.save(usage);
        couponRepository.incrementUsedCount(coupon.getId());

        registration.setCouponCode(coupon.getCode());

        return usage;
    }

    private BigDecimal getOrderAmount(Registration registration) {
        if (registration.getTicketType() != null) {
            int qty = registration.getQuantity() != null ? registration.getQuantity() : 1;
            return registration.getTicketType().getPrice().multiply(BigDecimal.valueOf(qty));
        }
        return registration.getEvent().getTicketPrice() != null
                ? registration.getEvent().getTicketPrice()
                : BigDecimal.ZERO;
    }

    public PageResponse<CouponResponse> getOrganiserCoupons(User organiser, Pageable pageable) {
        Page<Coupon> page = couponRepository.findByCreatedByOrderByCreatedAtDesc(organiser, pageable);
        return PageResponse.from(page, CouponResponse::fromEntity);
    }

    @Transactional
    public CouponResponse disableCoupon(UUID couponId, User organiser) {
        Coupon coupon = couponRepository.findById(couponId)
                .orElseThrow(() -> new ResourceNotFoundException("Coupon not found"));
        if (!coupon.getCreatedBy().getId().equals(organiser.getId())) {
            throw new BadRequestException("You can only manage your own coupons");
        }
        coupon.setStatus(CouponStatus.DISABLED);
        couponRepository.save(coupon);
        return CouponResponse.fromEntity(coupon);
    }

    @Transactional(readOnly = true)
    public List<CouponResponse> getAvailableCouponsForUser(UUID eventId) {
        List<Coupon> coupons;
        if (eventId != null) {
            // Merge event-specific + organiser-wide coupons authored by the
            // event owner so the checkout screen surfaces every coupon the
            // attendee is eligible for, with biggest savings on top.
            coupons = new java.util.ArrayList<>(couponRepository.findAvailableCouponsByEvent(eventId));
            coupons.addAll(couponRepository.findOrganiserWideCouponsForEvent(eventId));
        } else {
            // No event context → show all active, non-event coupons so the user
            // can browse the catalogue. These only redeem against events of the
            // same organiser who authored the coupon; enforcement happens in
            // validateCoupon().
            coupons = couponRepository.findAvailableGlobalCoupons();
        }
        return coupons.stream()
                .map(CouponResponse::fromEntity)
                .toList();
    }
}

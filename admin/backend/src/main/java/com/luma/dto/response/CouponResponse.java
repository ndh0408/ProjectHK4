package com.luma.dto.response;

import com.luma.entity.Coupon;
import com.luma.entity.enums.CouponStatus;
import com.luma.entity.enums.DiscountType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CouponResponse {

    private UUID id;
    private String code;
    private String description;
    private DiscountType discountType;
    private BigDecimal discountValue;
    private BigDecimal maxDiscountAmount;
    private BigDecimal minOrderAmount;
    private UUID eventId;
    private String eventTitle;
    private CouponStatus status;
    private int maxUsageCount;
    private int usedCount;
    private Integer maxUsagePerUser;
    private LocalDateTime validFrom;
    private LocalDateTime validUntil;
    private boolean isValid;
    private LocalDateTime createdAt;

    public static CouponResponse fromEntity(Coupon coupon) {
        return CouponResponse.builder()
                .id(coupon.getId())
                .code(coupon.getCode())
                .description(coupon.getDescription())
                .discountType(coupon.getDiscountType())
                .discountValue(coupon.getDiscountValue())
                .maxDiscountAmount(coupon.getMaxDiscountAmount())
                .minOrderAmount(coupon.getMinOrderAmount())
                .eventId(coupon.getEvent() != null ? coupon.getEvent().getId() : null)
                .eventTitle(coupon.getEvent() != null ? coupon.getEvent().getTitle() : null)
                .status(coupon.getStatus())
                .maxUsageCount(coupon.getMaxUsageCount())
                .usedCount(coupon.getUsedCount())
                .maxUsagePerUser(coupon.getMaxUsagePerUser())
                .validFrom(coupon.getValidFrom())
                .validUntil(coupon.getValidUntil())
                .isValid(coupon.isValid())
                .createdAt(coupon.getCreatedAt())
                .build();
    }
}

package com.luma.entity;

import com.luma.entity.enums.CouponStatus;
import com.luma.entity.enums.DiscountType;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "coupons", indexes = {
    @Index(name = "idx_coupon_code", columnList = "code", unique = true)
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Coupon {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false, unique = true, length = 50)
    private String code;

    @Column(columnDefinition = "NVARCHAR(500)")
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private DiscountType discountType;

    @Column(nullable = false)
    private BigDecimal discountValue;

    private BigDecimal maxDiscountAmount;

    private BigDecimal minOrderAmount;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "event_id")
    private Event event;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by", nullable = false)
    private User createdBy;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private CouponStatus status = CouponStatus.ACTIVE;

    @Builder.Default
    private int maxUsageCount = 0;

    @Builder.Default
    private int usedCount = 0;

    private Integer maxUsagePerUser;

    private LocalDateTime validFrom;

    private LocalDateTime validUntil;

    @CreationTimestamp
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;

    public boolean isValid() {
        if (status != CouponStatus.ACTIVE) return false;
        LocalDateTime now = LocalDateTime.now();
        if (validFrom != null && now.isBefore(validFrom)) return false;
        if (validUntil != null && now.isAfter(validUntil)) return false;
        if (maxUsageCount > 0 && usedCount >= maxUsageCount) return false;
        return true;
    }

    public BigDecimal calculateDiscount(BigDecimal orderAmount) {
        if (orderAmount == null || orderAmount.compareTo(BigDecimal.ZERO) <= 0) {
            return BigDecimal.ZERO;
        }
        if (minOrderAmount != null && orderAmount.compareTo(minOrderAmount) < 0) {
            return BigDecimal.ZERO;
        }

        BigDecimal discount;
        if (discountType == DiscountType.PERCENTAGE) {
            BigDecimal effectivePercent = discountValue.min(BigDecimal.valueOf(100));
            discount = orderAmount.multiply(effectivePercent).divide(BigDecimal.valueOf(100));
            if (maxDiscountAmount != null && discount.compareTo(maxDiscountAmount) > 0) {
                discount = maxDiscountAmount;
            }
        } else {
            discount = discountValue;
        }

        return discount.min(orderAmount).max(BigDecimal.ZERO);
    }
}

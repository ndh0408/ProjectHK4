package com.luma.dto.request;

import com.luma.entity.enums.DiscountType;
import jakarta.validation.constraints.*;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
public class CreateCouponRequest {

    @NotBlank
    @Size(max = 50, message = "Coupon code cannot exceed 50 characters")
    private String code;

    @Size(max = 500, message = "Description cannot exceed 500 characters")
    private String description;

    @NotNull
    private DiscountType discountType;

    @NotNull
    @Positive
    @DecimalMax(value = "999999.99", message = "Discount value is too large")
    private BigDecimal discountValue;

    @PositiveOrZero(message = "Max discount amount must be zero or positive")
    @DecimalMax(value = "999999.99", message = "Max discount amount is too large")
    private BigDecimal maxDiscountAmount;

    @PositiveOrZero(message = "Min order amount must be zero or positive")
    @DecimalMax(value = "999999.99", message = "Min order amount is too large")
    private BigDecimal minOrderAmount;

    private UUID eventId;

    @Min(value = 0, message = "Max usage count cannot be negative")
    @Max(value = 1000000, message = "Max usage count is too large")
    private int maxUsageCount;

    @Min(value = 1, message = "Max usage per user must be at least 1")
    @Max(value = 1000, message = "Max usage per user is too large")
    private Integer maxUsagePerUser;

    private LocalDateTime validFrom;

    private LocalDateTime validUntil;
}

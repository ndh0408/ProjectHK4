package com.luma.dto.request;

import com.luma.entity.enums.DiscountType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
public class CreateCouponRequest {

    @NotBlank
    private String code;

    private String description;

    @NotNull
    private DiscountType discountType;

    @NotNull
    @Positive
    private BigDecimal discountValue;

    private BigDecimal maxDiscountAmount;

    private BigDecimal minOrderAmount;

    private UUID eventId;

    private int maxUsageCount;

    private Integer maxUsagePerUser;

    private LocalDateTime validFrom;

    private LocalDateTime validUntil;
}

package com.luma.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "subscription_plan_config")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SubscriptionPlanConfig {

    @Id
    @Column(name = "plan_key", length = 40)
    private String planKey;

    @Column(nullable = false, length = 100)
    private String displayName;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal monthlyPriceUsd;

    /** -1 means unlimited. */
    @Column(nullable = false)
    private Integer maxEventsPerMonth;

    @Column(nullable = false)
    private Integer boostDiscountPercent;

    @Column(nullable = false)
    @Builder.Default
    private Boolean active = true;

    @Column(nullable = false)
    @Builder.Default
    private Integer sortOrder = 0;

    @CreationTimestamp
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;
}

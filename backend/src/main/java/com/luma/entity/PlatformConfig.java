package com.luma.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Platform-wide configuration settings
 * Singleton table - only one row should exist
 */
@Entity
@Table(name = "platform_config")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PlatformConfig {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /**
     * Default commission rate for all organisers (percentage)
     * e.g., 10.00 means 10%
     */
    @Column(name = "default_commission_rate", nullable = false, precision = 5, scale = 2)
    @Builder.Default
    private BigDecimal defaultCommissionRate = new BigDecimal("10.00");

    /**
     * Minimum commission rate allowed (for custom organiser rates)
     */
    @Column(name = "min_commission_rate", nullable = false, precision = 5, scale = 2)
    @Builder.Default
    private BigDecimal minCommissionRate = new BigDecimal("5.00");

    /**
     * Maximum commission rate allowed
     */
    @Column(name = "max_commission_rate", nullable = false, precision = 5, scale = 2)
    @Builder.Default
    private BigDecimal maxCommissionRate = new BigDecimal("25.00");

    /**
     * Currency for platform transactions
     */
    @Column(name = "currency", nullable = false, length = 3)
    @Builder.Default
    private String currency = "USD";

    /**
     * Minimum payout amount for organisers
     */
    @Column(name = "min_payout_amount", nullable = false, precision = 10, scale = 2)
    @Builder.Default
    private BigDecimal minPayoutAmount = new BigDecimal("50.00");

    /**
     * Payout processing fee (fixed amount)
     */
    @Column(name = "payout_processing_fee", nullable = false, precision = 10, scale = 2)
    @Builder.Default
    private BigDecimal payoutProcessingFee = new BigDecimal("2.00");

    /**
     * Whether the platform is accepting new events
     */
    @Column(name = "accepting_events", nullable = false)
    @Builder.Default
    private Boolean acceptingEvents = true;

    /**
     * Whether the platform is accepting new organisers
     */
    @Column(name = "accepting_organisers", nullable = false)
    @Builder.Default
    private Boolean acceptingOrganisers = true;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @Column(name = "updated_by")
    private UUID updatedBy;
}

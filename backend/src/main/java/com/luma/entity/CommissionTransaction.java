package com.luma.entity;

import com.luma.entity.enums.CommissionStatus;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Records each commission transaction when a ticket is sold
 * Tracks platform earnings and organiser payouts
 */
@Entity
@Table(name = "commission_transactions",
       indexes = {
           @Index(name = "idx_commission_payment", columnList = "payment_id"),
           @Index(name = "idx_commission_organiser", columnList = "organiser_id"),
           @Index(name = "idx_commission_event", columnList = "event_id"),
           @Index(name = "idx_commission_status", columnList = "status"),
           @Index(name = "idx_commission_created", columnList = "created_at")
       })
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CommissionTransaction {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /**
     * The payment this commission is associated with
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "payment_id", nullable = false)
    private Payment payment;

    /**
     * The event the ticket was sold for
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "event_id", nullable = false)
    private Event event;

    /**
     * The organiser who owns the event
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "organiser_id", nullable = false)
    private User organiser;

    /**
     * Total sale amount (what user paid)
     */
    @Column(name = "sale_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal saleAmount;

    /**
     * Commission rate applied (percentage)
     */
    @Column(name = "commission_rate", nullable = false, precision = 5, scale = 2)
    private BigDecimal commissionRate;

    /**
     * Commission amount (platform takes this)
     * = saleAmount * commissionRate / 100
     */
    @Column(name = "commission_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal commissionAmount;

    /**
     * Organiser earnings (organiser receives this)
     * = saleAmount - commissionAmount
     */
    @Column(name = "organiser_earnings", nullable = false, precision = 10, scale = 2)
    private BigDecimal organiserEarnings;

    /**
     * Currency
     */
    @Column(name = "currency", nullable = false, length = 3)
    @Builder.Default
    private String currency = "USD";

    /**
     * Status of this commission transaction
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    @Builder.Default
    private CommissionStatus status = CommissionStatus.PENDING;

    /**
     * When the commission was settled (paid out to organiser)
     */
    @Column(name = "settled_at")
    private LocalDateTime settledAt;

    /**
     * Payout reference ID (from Stripe or other payment provider)
     */
    @Column(name = "payout_reference", length = 255)
    private String payoutReference;

    /**
     * Notes (e.g., refund reason, adjustment reason)
     */
    @Column(name = "notes", length = 1000)
    private String notes;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    /**
     * Calculate commission based on sale amount and rate
     */
    public void calculateCommission() {
        if (saleAmount != null && commissionRate != null) {
            this.commissionAmount = saleAmount.multiply(commissionRate)
                    .divide(new BigDecimal("100"), 2, java.math.RoundingMode.HALF_UP);
            this.organiserEarnings = saleAmount.subtract(this.commissionAmount);
        }
    }
}

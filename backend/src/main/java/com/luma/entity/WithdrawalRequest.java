package com.luma.entity;

import com.luma.entity.enums.WithdrawalStatus;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Represents a withdrawal request from an organiser to withdraw their earnings
 */
@Entity
@Table(name = "withdrawal_requests",
       indexes = {
           @Index(name = "idx_withdrawal_organiser", columnList = "organiser_id"),
           @Index(name = "idx_withdrawal_status", columnList = "status"),
           @Index(name = "idx_withdrawal_created", columnList = "created_at")
       })
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class WithdrawalRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /**
     * The organiser requesting the withdrawal
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "organiser_id", nullable = false)
    private User organiser;

    /**
     * Amount requested to withdraw
     */
    @Column(name = "amount", nullable = false, precision = 15, scale = 2)
    private BigDecimal amount;

    /**
     * Available balance at the time of request (snapshot)
     */
    @Column(name = "available_balance", nullable = false, precision = 15, scale = 2)
    private BigDecimal availableBalance;

    /**
     * Currency
     */
    @Column(name = "currency", nullable = false, length = 3)
    @Builder.Default
    private String currency = "USD";

    /**
     * Current status of the request
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    @Builder.Default
    private WithdrawalStatus status = WithdrawalStatus.PENDING;

    /**
     * Note from organiser
     */
    @Column(name = "organiser_note", length = 500)
    private String organiserNote;

    /**
     * Note from admin (for approval/rejection reason)
     */
    @Column(name = "admin_note", length = 500)
    private String adminNote;

    /**
     * Admin who processed this request
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "processed_by")
    private User processedBy;

    /**
     * When the request was approved/rejected
     */
    @Column(name = "processed_at")
    private LocalDateTime processedAt;

    /**
     * When the transfer was completed
     */
    @Column(name = "completed_at")
    private LocalDateTime completedAt;

    /**
     * Stripe transfer ID
     */
    @Column(name = "stripe_transfer_id", length = 100)
    private String stripeTransferId;

    /**
     * Stripe payout ID (if applicable)
     */
    @Column(name = "stripe_payout_id", length = 100)
    private String stripePayoutId;

    /**
     * Failure reason if transfer failed
     */
    @Column(name = "failure_reason", length = 500)
    private String failureReason;

    /**
     * Bank account info snapshot at time of request
     */
    @Column(name = "bank_account_last_four", length = 4)
    private String bankAccountLastFour;

    @Column(name = "bank_name", length = 100)
    private String bankName;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
}

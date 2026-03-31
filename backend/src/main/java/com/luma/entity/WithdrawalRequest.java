package com.luma.entity;

import com.luma.entity.enums.WithdrawalStatus;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

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

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "organiser_id", nullable = false)
    private User organiser;

    @Column(name = "amount", nullable = false, precision = 15, scale = 2)
    private BigDecimal amount;

    @Column(name = "available_balance", nullable = false, precision = 15, scale = 2)
    private BigDecimal availableBalance;

    @Column(name = "currency", nullable = false, length = 3)
    @Builder.Default
    private String currency = "USD";

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    @Builder.Default
    private WithdrawalStatus status = WithdrawalStatus.PENDING;

    @Column(name = "organiser_note", length = 500)
    private String organiserNote;

    @Column(name = "admin_note", length = 500)
    private String adminNote;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "processed_by")
    private User processedBy;

    @Column(name = "processed_at")
    private LocalDateTime processedAt;

    @Column(name = "completed_at")
    private LocalDateTime completedAt;

    @Column(name = "stripe_transfer_id", length = 100)
    private String stripeTransferId;

    @Column(name = "stripe_payout_id", length = 100)
    private String stripePayoutId;

    @Column(name = "failure_reason", length = 500)
    private String failureReason;

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

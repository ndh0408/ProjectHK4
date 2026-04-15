package com.luma.entity;

import com.luma.entity.enums.PayoutStatus;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "payouts")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Payout {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "organiser_id", nullable = false)
    private User organiser;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "event_id", nullable = false)
    private Event event;

    @Column(nullable = false, precision = 15, scale = 2)
    private BigDecimal grossAmount;

    @Column(nullable = false, precision = 15, scale = 2)
    private BigDecimal platformFee;

    @Column(nullable = false, precision = 15, scale = 2)
    private BigDecimal stripeFee;

    @Column(nullable = false, precision = 15, scale = 2)
    private BigDecimal netAmount;

    @Column(precision = 5, scale = 2)
    @Builder.Default
    private BigDecimal platformFeePercent = new BigDecimal("5.00");

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private PayoutStatus status = PayoutStatus.PENDING;

    @Column(length = 100)
    private String stripeTransferId;

    @Column(length = 100)
    private String stripePayoutId;

    private LocalDateTime processedAt;

    private LocalDateTime completedAt;

    @Column(columnDefinition = "NVARCHAR(1000)")
    private String failureReason;

    private Integer ticketsSold;

    private Integer refundedTickets;

    @CreationTimestamp
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;
}

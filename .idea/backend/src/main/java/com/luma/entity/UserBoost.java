package com.luma.entity;

import com.luma.entity.enums.BoostStatus;
import com.luma.entity.enums.UserBoostPackage;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "user_boosts")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserBoost {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "event_id", nullable = false)
    private Event event;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(name = "boost_package", nullable = false)
    private UserBoostPackage boostPackage;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private BoostStatus status = BoostStatus.PENDING;

    @Column(precision = 10, scale = 2)
    private BigDecimal amount;

    @Column(name = "payment_intent_id")
    private String paymentIntentId;

    @Column(name = "paid_at")
    private LocalDateTime paidAt;

    @Column(name = "start_time")
    private LocalDateTime startTime;

    @Column(name = "end_time")
    private LocalDateTime endTime;

    @Builder.Default
    @Column(name = "views_during_boost")
    private int viewsDuringBoost = 0;

    @Builder.Default
    @Column(name = "clicks_during_boost")
    private int clicksDuringBoost = 0;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    public boolean isActive() {
        if (status != BoostStatus.ACTIVE) return false;
        if (startTime == null || endTime == null) return false;
        LocalDateTime now = LocalDateTime.now();
        return now.isAfter(startTime) && now.isBefore(endTime);
    }

    public int getDaysRemaining() {
        if (!isActive() || endTime == null) return 0;
        long days = java.time.temporal.ChronoUnit.DAYS.between(LocalDateTime.now(), endTime);
        return Math.max(0, (int) days);
    }
}

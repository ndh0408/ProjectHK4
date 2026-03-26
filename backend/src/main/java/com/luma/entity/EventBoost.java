package com.luma.entity;

import com.luma.entity.enums.BoostPackage;
import com.luma.entity.enums.BoostStatus;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "event_boosts")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EventBoost {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "event_id", nullable = false)
    private Event event;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "organiser_id", nullable = false)
    private User organiser;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private BoostPackage boostPackage;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private BoostStatus status = BoostStatus.PENDING;

    @Column(nullable = false)
    private BigDecimal amount;

    private LocalDateTime startTime;

    private LocalDateTime endTime;

    // Payment info
    private String paymentIntentId;
    private LocalDateTime paidAt;

    // Stats
    @Builder.Default
    private int viewsBeforeBoost = 0;

    @Builder.Default
    private int viewsDuringBoost = 0;

    @Builder.Default
    private int clicksBeforeBoost = 0;

    @Builder.Default
    private int clicksDuringBoost = 0;

    @Builder.Default
    private int registrationsBeforeBoost = 0;

    @Builder.Default
    private int registrationsDuringBoost = 0;

    @CreationTimestamp
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;

    public boolean isActive() {
        if (status != BoostStatus.ACTIVE) return false;
        if (startTime == null || endTime == null) return false;

        LocalDateTime now = LocalDateTime.now();
        // Use isAfter or equals for startTime to include the exact start moment
        return (now.isAfter(startTime) || now.isEqual(startTime)) && now.isBefore(endTime);
    }

    public double getConversionRate() {
        if (viewsDuringBoost == 0) return 0;
        return (double) registrationsDuringBoost / viewsDuringBoost * 100;
    }
}

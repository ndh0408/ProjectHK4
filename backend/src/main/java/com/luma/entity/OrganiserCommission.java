package com.luma.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Custom commission rate for specific organisers
 * If an organiser has a record here, use this rate instead of platform default
 */
@Entity
@Table(name = "organiser_commissions",
       uniqueConstraints = @UniqueConstraint(columnNames = "organiser_id"))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OrganiserCommission {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /**
     * The organiser this commission rate applies to
     */
    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "organiser_id", nullable = false, unique = true)
    private User organiser;

    /**
     * Custom commission rate for this organiser (percentage)
     * e.g., 8.00 means 8%
     */
    @Column(name = "commission_rate", nullable = false, precision = 5, scale = 2)
    private BigDecimal commissionRate;

    /**
     * Reason for custom rate (e.g., "VIP Partner", "Early Adopter Discount")
     */
    @Column(name = "reason", length = 500)
    private String reason;

    /**
     * Start date of this commission rate
     */
    @Column(name = "effective_from", nullable = false)
    private LocalDateTime effectiveFrom;

    /**
     * End date of this commission rate (null = no expiry)
     */
    @Column(name = "effective_until")
    private LocalDateTime effectiveUntil;

    /**
     * Whether this custom rate is currently active
     */
    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private Boolean isActive = true;

    /**
     * Admin who set this rate
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "set_by_admin_id")
    private User setByAdmin;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    /**
     * Check if this commission rate is currently valid
     */
    public boolean isCurrentlyValid() {
        if (!isActive) return false;
        LocalDateTime now = LocalDateTime.now();
        if (now.isBefore(effectiveFrom)) return false;
        if (effectiveUntil != null && now.isAfter(effectiveUntil)) return false;
        return true;
    }
}

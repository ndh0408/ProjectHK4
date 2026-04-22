package com.luma.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Admin-editable boost tier config. Key is a free-form string so admins can add new tiers
 * beyond the four seeded from {@link com.luma.entity.enums.BoostPackage} — the enum just
 * provides initial defaults. Code paths that switch on the enum will only recognise the four
 * canonical keys; custom tiers created by admin show up in the admin UI but won't wire into
 * the purchase flow until the enum is extended. Marked clearly in the admin UI.
 */
@Entity
@Table(name = "boost_package_config")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BoostPackageConfig {

    @Id
    @Column(name = "package_key", length = 40)
    private String packageKey;

    @Column(nullable = false, length = 100)
    private String displayName;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal priceUsd;

    @Column(nullable = false)
    private Integer durationDays;

    @Column(nullable = false)
    private Double boostMultiplier;

    @Column(nullable = false, length = 50)
    private String badgeText;

    @Column(nullable = false)
    @Builder.Default
    private Boolean featuredInCategory = false;

    @Column(nullable = false)
    @Builder.Default
    private Boolean featuredOnHome = false;

    @Column(nullable = false)
    @Builder.Default
    private Boolean priorityInSearch = false;

    @Column(nullable = false)
    @Builder.Default
    private Boolean homeBanner = false;

    @Column(nullable = false)
    @Builder.Default
    private Boolean active = true;

    @Column(name = "discount_eligible", nullable = false)
    @Builder.Default
    private Boolean discountEligible = true;

    @Column(name = "discount_percent", nullable = false)
    @Builder.Default
    private Integer discountPercent = 0;

    @Column(nullable = false)
    @Builder.Default
    private Integer sortOrder = 0;

    @CreationTimestamp
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;
}

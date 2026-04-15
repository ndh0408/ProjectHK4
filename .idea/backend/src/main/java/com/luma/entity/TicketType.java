package com.luma.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "ticket_types")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TicketType {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "event_id", nullable = false)
    private Event event;

    @Column(nullable = false)
    private String name;

    @Column(columnDefinition = "NVARCHAR(1000)")
    private String description;

    @Column(nullable = false, precision = 10, scale = 2)
    @Builder.Default
    private BigDecimal price = BigDecimal.ZERO;

    @Column(nullable = false)
    private Integer quantity;

    @Column(nullable = false)
    @Builder.Default
    private Integer soldCount = 0;

    @Column(nullable = false)
    @Builder.Default
    private Integer maxPerOrder = 10;

    private LocalDateTime saleStartDate;

    private LocalDateTime saleEndDate;

    @Column(nullable = false)
    @Builder.Default
    private Boolean isVisible = true;

    @Column(nullable = false)
    @Builder.Default
    private Integer displayOrder = 0;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    public boolean isFree() {
        return price == null || price.compareTo(BigDecimal.ZERO) == 0;
    }

    public boolean isAvailable() {
        return getAvailableQuantity() > 0;
    }

    public Integer getAvailableQuantity() {
        return quantity - soldCount;
    }

    public boolean isSaleActive() {
        LocalDateTime now = LocalDateTime.now();

        if (saleStartDate != null && now.isBefore(saleStartDate)) {
            return false;
        }

        if (saleEndDate != null && now.isAfter(saleEndDate)) {
            return false;
        }

        return true;
    }

    public boolean canPurchase(int requestedQuantity) {
        if (!isVisible) return false;
        if (!isSaleActive()) return false;
        if (requestedQuantity > maxPerOrder) return false;
        if (requestedQuantity > getAvailableQuantity()) return false;
        return true;
    }

    public String getStatus() {
        if (!isVisible) return "HIDDEN";
        if (!isSaleActive()) {
            LocalDateTime now = LocalDateTime.now();
            if (saleStartDate != null && now.isBefore(saleStartDate)) {
                return "NOT_STARTED";
            }
            return "ENDED";
        }
        if (getAvailableQuantity() <= 0) return "SOLD_OUT";
        return "AVAILABLE";
    }
}

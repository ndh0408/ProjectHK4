package com.luma.entity;

import com.luma.entity.enums.SeatStatus;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "seats", uniqueConstraints = {
    @UniqueConstraint(columnNames = {"zone_id", "seat_row", "seat_number"})
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Seat {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "zone_id", nullable = false)
    private SeatZone zone;

    @Column(name = "seat_row", nullable = false, length = 10)
    private String row;

    @Column(name = "seat_number", nullable = false)
    private int number;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private SeatStatus status = SeatStatus.AVAILABLE;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reserved_by")
    private User reservedBy;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "registration_id")
    private Registration registration;

    private LocalDateTime lockedUntil;

    public String getLabel() {
        return row + number;
    }

    public boolean isAvailable() {
        if (status == SeatStatus.AVAILABLE) return true;
        if (status == SeatStatus.LOCKED && lockedUntil != null && LocalDateTime.now().isAfter(lockedUntil)) {
            return true;
        }
        return false;
    }
}

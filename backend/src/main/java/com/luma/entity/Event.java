package com.luma.entity;

import com.luma.entity.enums.EventStatus;
import com.luma.entity.enums.EventVisibility;
import com.luma.entity.enums.RecurrenceType;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.SQLDelete;
import org.hibernate.annotations.SQLRestriction;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "events")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@SQLDelete(sql = "UPDATE events SET deleted = true, deleted_at = GETDATE() WHERE id = ?")
@SQLRestriction("deleted = false")
public class Event {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false, columnDefinition = "NVARCHAR(300)")
    private String title;

    @Column(columnDefinition = "NVARCHAR(MAX)")
    private String description;

    @Column(columnDefinition = "NVARCHAR(1000)")
    private String imageUrl;

    @Column(nullable = false)
    private LocalDateTime startTime;

    @Column(nullable = false)
    private LocalDateTime endTime;

    private LocalDateTime registrationDeadline;

    @Column(columnDefinition = "NVARCHAR(300)")
    private String venue;

    @Column(columnDefinition = "NVARCHAR(500)")
    private String address;

    private Double latitude;

    private Double longitude;

    @Builder.Default
    private BigDecimal ticketPrice = BigDecimal.ZERO;

    @Column(name = "is_free", nullable = false)
    @Builder.Default
    private boolean isFree = true;

    private Integer capacity;

    @Builder.Default
    private int approvedCount = 0;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private EventStatus status = EventStatus.DRAFT;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private EventVisibility visibility = EventVisibility.PUBLIC;

    @Builder.Default
    private boolean requiresApproval = false;

    @Column(columnDefinition = "NVARCHAR(2000)")
    private String rejectionReason;

    @Enumerated(EnumType.STRING)
    @Builder.Default
    private RecurrenceType recurrenceType = RecurrenceType.NONE;

    private Integer recurrenceInterval;

    private String recurrenceDaysOfWeek;

    private LocalDateTime recurrenceEndDate;

    private Integer recurrenceCount;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "parent_event_id")
    private Event parentEvent;

    @OneToMany(mappedBy = "parentEvent", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<Event> childEvents = new ArrayList<>();

    private Integer occurrenceIndex;

    @CreationTimestamp
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;

    @Column(name = "deleted", nullable = false)
    @Builder.Default
    private boolean deleted = false;

    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "organiser_id", nullable = false)
    private User organiser;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id")
    private Category category;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "city_id")
    private City city;

    @OneToMany(mappedBy = "event", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<Registration> registrations = new ArrayList<>();

    @OneToMany(mappedBy = "event", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<Question> questions = new ArrayList<>();

    @OneToMany(mappedBy = "event", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @Builder.Default
    private List<Speaker> speakers = new ArrayList<>();

    @OneToMany(mappedBy = "event", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @OrderBy("displayOrder ASC")
    @Builder.Default
    private List<RegistrationQuestion> registrationQuestions = new ArrayList<>();

    @OneToMany(mappedBy = "event", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @OrderBy("displayOrder ASC")
    @Builder.Default
    private List<TicketType> ticketTypes = new ArrayList<>();

    @OneToMany(mappedBy = "event", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @Builder.Default
    private List<Poll> polls = new ArrayList<>();

    @OneToMany(mappedBy = "event", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @Builder.Default
    private List<SeatZone> seatZones = new ArrayList<>();

    @OneToMany(mappedBy = "event", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @Builder.Default
    private List<EventSession> sessions = new ArrayList<>();

    public boolean hasRegistrationQuestions() {
        return registrationQuestions != null && !registrationQuestions.isEmpty();
    }

    public boolean hasTicketTypes() {
        return ticketTypes != null && !ticketTypes.isEmpty();
    }

    public boolean isFull() {
        return capacity != null && approvedCount >= capacity;
    }

    public boolean isAlmostFull() {
        if (capacity == null || capacity == 0) return false;
        double remainingPercentage = (double) (capacity - approvedCount) / capacity * 100;
        return remainingPercentage <= 10 && remainingPercentage > 0;
    }

    public int getRemainingSpots() {
        if (capacity == null) return Integer.MAX_VALUE;
        return Math.max(0, capacity - approvedCount);
    }
}

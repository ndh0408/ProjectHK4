package com.luma.entity;

import com.luma.entity.enums.RegistrationStatus;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "registrations", uniqueConstraints = {
    @UniqueConstraint(columnNames = {"user_id", "event_id"})
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Registration {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "event_id", nullable = false)
    private Event event;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "ticket_type_id")
    private TicketType ticketType;

    @Column(nullable = false)
    @Builder.Default
    private Integer quantity = 1;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private RegistrationStatus status = RegistrationStatus.PENDING;

    private String ticketCode;

    private LocalDateTime approvedAt;

    private LocalDateTime rejectedAt;

    @Column(columnDefinition = "NVARCHAR(500)")
    private String rejectionReason;

    @Column(name = "registration_goals", columnDefinition = "NVARCHAR(MAX)")
    private String registrationGoals;

    @Column(name = "expectations", columnDefinition = "NVARCHAR(MAX)")
    private String expectations;

    @Column(name = "experience_level", columnDefinition = "NVARCHAR(100)")
    private String experienceLevel;

    private Integer waitingListPosition;

    private Integer priorityScore;

    /**
     * Deadline by which a waitlist-promoted paid user must complete payment.
     * Set by {@code WaitlistService.acceptOffer} for paid events. A scheduler
     * cancels PENDING registrations past this deadline and promotes the next
     * person in line. Null for non-promoted registrations.
     */
    private LocalDateTime paymentDeadline;

    @Column(length = 50)
    private String couponCode;

    private LocalDateTime checkedInAt;

    @Column(columnDefinition = "BIT DEFAULT 0")
    @Builder.Default
    private Boolean reminderSent = false;

    private LocalDateTime reminderSentAt;

    @OneToMany(mappedBy = "registration", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @Builder.Default
    private List<RegistrationAnswer> answers = new ArrayList<>();

    @CreationTimestamp
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;
}

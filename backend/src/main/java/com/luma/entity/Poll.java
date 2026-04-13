package com.luma.entity;

import com.luma.entity.enums.PollStatus;
import com.luma.entity.enums.PollType;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "polls")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Poll {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "event_id", nullable = false)
    private Event event;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by", nullable = false)
    private User createdBy;

    @Column(nullable = false, columnDefinition = "NVARCHAR(500)")
    private String question;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private PollType type = PollType.SINGLE_CHOICE;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private PollStatus status = PollStatus.ACTIVE;

    @Column(name = "allow_multiple")
    @Builder.Default
    private boolean allowMultiple = false;

    @Column(name = "max_rating")
    private Integer maxRating;

    private LocalDateTime closesAt;

    private LocalDateTime closedAt;

    @Builder.Default
    private int totalVotes = 0;

    @OneToMany(mappedBy = "poll", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.EAGER)
    @Builder.Default
    @OrderBy("displayOrder ASC")
    private List<PollOption> options = new ArrayList<>();

    @CreationTimestamp
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;

    public boolean isActive() {
        if (status != PollStatus.ACTIVE) return false;
        if (closesAt != null && LocalDateTime.now().isAfter(closesAt)) return false;
        return true;
    }
}

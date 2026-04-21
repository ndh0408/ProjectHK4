package com.luma.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "conversation_participants", uniqueConstraints = {
    @UniqueConstraint(columnNames = {"conversation_id", "user_id"})
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ConversationParticipant {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "conversation_id", nullable = false)
    private Conversation conversation;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    private LocalDateTime lastReadAt;

    @Builder.Default
    private int unreadCount = 0;

    @Builder.Default
    private boolean muted = false;

    @Builder.Default
    private boolean pinned = false;

    @Builder.Default
    private boolean archived = false;

    /// Timestamp the organiser banned this participant from the event chat.
    /// Null means active; non-null blocks send + (optionally) read.
    private LocalDateTime bannedAt;

    /// Mute duration — if set in the future, the participant can still read
    /// but their messages are rejected. Null/past means unmuted.
    private LocalDateTime mutedUntil;

    @CreationTimestamp
    private LocalDateTime joinedAt;

    @Transient
    public boolean isBanned() {
        return bannedAt != null;
    }

    @Transient
    public boolean isCurrentlyMuted() {
        return mutedUntil != null && mutedUntil.isAfter(LocalDateTime.now());
    }
}

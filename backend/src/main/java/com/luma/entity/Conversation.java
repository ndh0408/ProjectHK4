package com.luma.entity;

import com.luma.entity.enums.ConversationType;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "conversations")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Conversation {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ConversationType type;

    private String name;

    private String imageUrl;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "event_id")
    private Event event;

    @OneToMany(mappedBy = "conversation", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<ConversationParticipant> participants = new ArrayList<>();

    @OneToMany(mappedBy = "conversation", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<Message> messages = new ArrayList<>();

    @Column(columnDefinition = "NVARCHAR(MAX)")
    private String lastMessageContent;

    private LocalDateTime lastMessageAt;

    private LocalDateTime closedAt;

    /// The currently pinned announcement for this conversation, if any. Only
    /// organisers can pin in EVENT_GROUP chats. Setting to null unpins.
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "pinned_message_id")
    private Message pinnedMessage;

    private LocalDateTime pinnedAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "pinned_by_user_id")
    private User pinnedBy;

    @CreationTimestamp
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;
}

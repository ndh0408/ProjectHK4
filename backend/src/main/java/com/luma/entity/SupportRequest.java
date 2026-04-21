package com.luma.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

/// Support escalation created from the chatbot when the LLM cannot resolve
/// the user's issue on its own. Stores the transcript of the surrounding
/// conversation so a human agent can pick up with full context.
@Entity
@Table(name = "support_requests", indexes = {
        @Index(name = "idx_support_requests_status", columnList = "status"),
        @Index(name = "idx_support_requests_user", columnList = "user_id")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SupportRequest {

    public enum Status {
        OPEN, IN_PROGRESS, RESOLVED, CLOSED
    }

    public enum Category {
        PAYMENT_ISSUE,     // "đã trừ tiền chưa có vé"
        REFUND,            // "muốn hoàn tiền"
        TICKET_MISSING,    // "không thấy vé"
        ACCOUNT,           // "không đăng nhập được"
        EVENT_INFO,        // general event question the bot couldn't answer
        OTHER
    }

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    @Column(columnDefinition = "NVARCHAR(200)")
    private String subject;

    @Column(columnDefinition = "NVARCHAR(2000)", nullable = false)
    private String message;

    /// JSON-encoded chat transcript (role + content pairs) so support can
    /// see what the user asked and what the bot answered.
    @Lob
    @Column(columnDefinition = "NVARCHAR(MAX)")
    private String transcript;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    @Builder.Default
    private Category category = Category.OTHER;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    @Builder.Default
    private Status status = Status.OPEN;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "related_registration_id")
    private Registration relatedRegistration;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "related_event_id")
    private Event relatedEvent;

    @Column(columnDefinition = "NVARCHAR(500)")
    private String resolutionNote;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "resolved_by_user_id")
    private User resolvedBy;

    private LocalDateTime resolvedAt;

    @CreationTimestamp
    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;
}

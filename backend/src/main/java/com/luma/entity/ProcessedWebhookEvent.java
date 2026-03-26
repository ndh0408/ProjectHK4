package com.luma.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

/**
 * Entity để track các webhook events đã xử lý
 * Đảm bảo idempotency - không xử lý duplicate events
 */
@Entity
@Table(name = "processed_webhook_events", indexes = {
    @Index(name = "idx_webhook_event_id", columnList = "eventId", unique = true),
    @Index(name = "idx_webhook_created_at", columnList = "createdAt")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ProcessedWebhookEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "event_id", nullable = false, unique = true, length = 100)
    private String eventId;

    @Column(name = "event_type", nullable = false, length = 100)
    private String eventType;

    @Column(name = "source", nullable = false, length = 50)
    private String source; // e.g., "stripe"

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
}

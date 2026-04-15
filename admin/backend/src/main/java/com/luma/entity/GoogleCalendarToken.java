package com.luma.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "google_calendar_tokens")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GoogleCalendarToken {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    @Column(nullable = false, length = 2000)
    private String accessToken;

    @Column(nullable = false, length = 2000)
    private String refreshToken;

    @Column(nullable = false)
    private LocalDateTime expiresAt;

    @Column(length = 500)
    private String scope;

    @Builder.Default
    private Boolean isActive = true;

    @CreationTimestamp
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;

    public boolean isExpired() {
        return LocalDateTime.now().isAfter(expiresAt);
    }
}

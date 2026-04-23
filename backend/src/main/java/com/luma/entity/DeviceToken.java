package com.luma.entity;

import com.luma.entity.enums.DevicePlatform;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "device_tokens",
        indexes = {
                @Index(name = "idx_device_tokens_user", columnList = "user_id"),
                @Index(name = "idx_device_tokens_token", columnList = "token", unique = true)
        })
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DeviceToken {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /**
     * FCM registration token. Unique across users — when a user signs out and
     * a different user signs in on the same device, the token is re-associated
     * via {@code upsert}.
     */
    @Column(nullable = false, length = 500, unique = true)
    private String token;

    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    @Builder.Default
    private DevicePlatform platform = DevicePlatform.ANDROID;

    @Column(length = 150)
    private String deviceModel;

    @Column(length = 50)
    private String appVersion;

    @CreationTimestamp
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;

    private LocalDateTime lastUsedAt;
}

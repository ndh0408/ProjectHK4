package com.luma.entity;

import com.luma.entity.enums.UserRole;
import com.luma.entity.enums.UserStatus;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.SQLDelete;
import org.hibernate.annotations.SQLRestriction;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@SQLDelete(sql = "UPDATE users SET deleted = true, deleted_at = GETDATE() WHERE id = ?")
@SQLRestriction("deleted = false")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(unique = true)
    private String email;

    @Column(columnDefinition = "NVARCHAR(50)")
    private String phone;

    private String password;

    @Column(columnDefinition = "NVARCHAR(200)")
    private String fullName;

    @Column(columnDefinition = "NVARCHAR(1000)")
    private String avatarUrl;

    @Column(name = "signature_url", columnDefinition = "NVARCHAR(1000)")
    private String signatureUrl;

    @Column(columnDefinition = "NVARCHAR(1000)")
    private String bio;

    @Column(columnDefinition = "NVARCHAR(200)")
    private String jobTitle;

    @Column(columnDefinition = "NVARCHAR(200)")
    private String company;

    @Column(columnDefinition = "NVARCHAR(200)")
    private String industry;

    @Column(columnDefinition = "NVARCHAR(500)")
    private String linkedinUrl;

    @Column(columnDefinition = "NVARCHAR(500)")
    private String interests;

    @Column(name = "networking_visible", nullable = false, columnDefinition = "BIT DEFAULT 1")
    @Builder.Default
    private boolean networkingVisible = true;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private UserRole role = UserRole.USER;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private UserStatus status = UserStatus.ACTIVE;

    private boolean phoneVerified;

    private boolean emailVerified;

    private String verificationCode;

    private LocalDateTime verificationCodeExpiry;

    @CreationTimestamp
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;

    private LocalDateTime lastLoginAt;

    @Column(columnDefinition = "BIT DEFAULT 1")
    @Builder.Default
    private boolean emailNotificationsEnabled = true;

    @Column(columnDefinition = "BIT DEFAULT 1")
    @Builder.Default
    private boolean emailEventReminders = true;

    @Column(name = "deleted", nullable = false)
    @Builder.Default
    private boolean deleted = false;

    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;

    @OneToOne(mappedBy = "user", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    private OrganiserProfile organiserProfile;

    @OneToMany(mappedBy = "organiser", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<Event> organizedEvents = new ArrayList<>();

    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<Registration> registrations = new ArrayList<>();

    @OneToMany(mappedBy = "follower", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<Follow> following = new ArrayList<>();

    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<Notification> notifications = new ArrayList<>();
}

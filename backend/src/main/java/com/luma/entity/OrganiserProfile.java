package com.luma.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "organiser_profiles")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OrganiserProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    @Column(nullable = false, columnDefinition = "NVARCHAR(200)")
    private String displayName;

    @Column(columnDefinition = "NVARCHAR(MAX)")
    private String bio;

    private String logoUrl;

    private String coverUrl;

    private String website;

    private String contactEmail;

    @Column(columnDefinition = "NVARCHAR(50)")
    private String contactPhone;

    @Builder.Default
    private boolean verified = false;

    @Builder.Default
    private int totalEvents = 0;

    @Builder.Default
    private int totalFollowers = 0;

    @CreationTimestamp
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;

    @OneToMany(mappedBy = "organiser", fetch = FetchType.LAZY)
    @Builder.Default
    private List<Follow> followers = new ArrayList<>();
}

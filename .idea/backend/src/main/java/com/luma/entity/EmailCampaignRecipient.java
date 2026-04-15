package com.luma.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "email_campaign_recipients", uniqueConstraints = {
    @UniqueConstraint(columnNames = {"campaign_id", "user_id"})
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EmailCampaignRecipient {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "campaign_id", nullable = false)
    private EmailCampaign campaign;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    private String email;

    @Builder.Default
    private Boolean sent = false;

    private LocalDateTime sentAt;

    @Builder.Default
    private Boolean opened = false;

    private LocalDateTime openedAt;

    @Builder.Default
    private Boolean clicked = false;

    private LocalDateTime clickedAt;

    @Builder.Default
    private Boolean bounced = false;

    private String bounceReason;

    @Builder.Default
    private Boolean unsubscribed = false;

    @CreationTimestamp
    private LocalDateTime createdAt;
}

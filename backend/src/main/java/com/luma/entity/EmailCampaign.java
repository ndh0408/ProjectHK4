package com.luma.entity;

import com.luma.entity.enums.EmailCampaignStatus;
import com.luma.entity.enums.EmailCampaignType;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "email_campaigns")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EmailCampaign {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private String subject;

    @Column(columnDefinition = "NVARCHAR(MAX)", nullable = false)
    private String htmlContent;

    @Column(columnDefinition = "NVARCHAR(MAX)")
    private String plainTextContent;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private EmailCampaignType type = EmailCampaignType.NEWSLETTER;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private EmailCampaignStatus status = EmailCampaignStatus.DRAFT;

    // Target audience filters (stored as JSON)
    @Column(columnDefinition = "NVARCHAR(2000)")
    private String audienceFilter; // {"role": "USER", "cities": [1,2], "categories": [3,4]}

    private LocalDateTime scheduledAt;

    private LocalDateTime sentAt;

    @Builder.Default
    private Integer totalRecipients = 0;

    @Builder.Default
    private Integer sentCount = 0;

    @Builder.Default
    private Integer openCount = 0;

    @Builder.Default
    private Integer clickCount = 0;

    @Builder.Default
    private Integer bounceCount = 0;

    @Builder.Default
    private Integer unsubscribeCount = 0;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by")
    private User createdBy;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "event_id")
    private Event relatedEvent;

    @OneToMany(mappedBy = "campaign", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<EmailCampaignRecipient> recipients = new ArrayList<>();

    @CreationTimestamp
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;

    public double getOpenRate() {
        return sentCount > 0 ? (openCount * 100.0 / sentCount) : 0;
    }

    public double getClickRate() {
        return openCount > 0 ? (clickCount * 100.0 / openCount) : 0;
    }

    public double getBounceRate() {
        return totalRecipients > 0 ? (bounceCount * 100.0 / totalRecipients) : 0;
    }
}

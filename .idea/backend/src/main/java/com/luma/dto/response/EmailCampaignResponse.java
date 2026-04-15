package com.luma.dto.response;

import com.luma.entity.EmailCampaign;
import com.luma.entity.enums.EmailCampaignStatus;
import com.luma.entity.enums.EmailCampaignType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EmailCampaignResponse {

    private UUID id;
    private String name;
    private String subject;
    private String htmlContent;
    private String plainTextContent;
    private EmailCampaignType type;
    private EmailCampaignStatus status;
    private String audienceFilter;
    private LocalDateTime scheduledAt;
    private LocalDateTime sentAt;
    private Integer totalRecipients;
    private Integer sentCount;
    private Integer openCount;
    private Integer clickCount;
    private Integer bounceCount;
    private Integer unsubscribeCount;
    private Double openRate;
    private Double clickRate;
    private Double bounceRate;
    private UUID relatedEventId;
    private String relatedEventTitle;
    private String createdByName;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public static EmailCampaignResponse fromEntity(EmailCampaign campaign) {
        EmailCampaignResponseBuilder builder = EmailCampaignResponse.builder()
                .id(campaign.getId())
                .name(campaign.getName())
                .subject(campaign.getSubject())
                .htmlContent(campaign.getHtmlContent())
                .plainTextContent(campaign.getPlainTextContent())
                .type(campaign.getType())
                .status(campaign.getStatus())
                .audienceFilter(campaign.getAudienceFilter())
                .scheduledAt(campaign.getScheduledAt())
                .sentAt(campaign.getSentAt())
                .totalRecipients(campaign.getTotalRecipients())
                .sentCount(campaign.getSentCount())
                .openCount(campaign.getOpenCount())
                .clickCount(campaign.getClickCount())
                .bounceCount(campaign.getBounceCount())
                .unsubscribeCount(campaign.getUnsubscribeCount())
                .openRate(campaign.getOpenRate())
                .clickRate(campaign.getClickRate())
                .bounceRate(campaign.getBounceRate())
                .createdAt(campaign.getCreatedAt())
                .updatedAt(campaign.getUpdatedAt());

        if (campaign.getRelatedEvent() != null) {
            builder.relatedEventId(campaign.getRelatedEvent().getId());
            builder.relatedEventTitle(campaign.getRelatedEvent().getTitle());
        }

        if (campaign.getCreatedBy() != null) {
            builder.createdByName(campaign.getCreatedBy().getFullName());
        }

        return builder.build();
    }
}

package com.luma.dto.request;

import com.luma.entity.enums.EmailCampaignType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EmailCampaignRequest {

    @NotBlank(message = "Campaign name is required")
    private String name;

    @NotBlank(message = "Email subject is required")
    private String subject;

    @NotBlank(message = "HTML content is required")
    private String htmlContent;

    private String plainTextContent;

    @NotNull(message = "Campaign type is required")
    private EmailCampaignType type;

    // Audience targeting
    private AudienceFilter audienceFilter;

    // Schedule (null for immediate send)
    private LocalDateTime scheduledAt;

    // Related event for event-based campaigns
    private UUID relatedEventId;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class AudienceFilter {
        private String userRole; // USER, ORGANISER, or null for all
        private List<Integer> cityIds;
        private List<Integer> categoryIds;
        private Boolean registeredUsersOnly; // Only users who have registered for events
        private Boolean subscribedToNewsletter; // Only users subscribed to newsletter
    }
}

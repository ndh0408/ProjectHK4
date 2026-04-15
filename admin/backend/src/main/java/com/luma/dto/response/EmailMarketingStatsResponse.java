package com.luma.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EmailMarketingStatsResponse {

    private long totalCampaigns;
    private long draftCampaigns;
    private long sentCampaigns;
    private long scheduledCampaigns;
    private long totalEmailsSent;
    private long totalEmailsOpened;
    private long totalEmailsClicked;
    private long totalUnsubscribes;
    private double averageOpenRate;
    private double averageClickRate;
}

package com.luma.dto.response.analytics;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FunnelAnalyticsResponse {

    private long totalViews;
    private long totalRegistrations;
    private long totalApproved;
    private long totalAttended;
    private long totalReviewed;

    private double viewToRegistrationRate;
    private double registrationToApprovedRate;
    private double approvedToAttendedRate;
    private double attendedToReviewedRate;
    private double overallConversionRate;

    private List<FunnelStep> steps;
    private List<EventFunnel> eventFunnels;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class FunnelStep {
        private String name;
        private long count;
        private double percentage;
        private double dropOffRate;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class EventFunnel {
        private UUID eventId;
        private String eventTitle;
        private long views;
        private long registrations;
        private long approved;
        private long attended;
        private long reviewed;
        private double conversionRate;
    }
}

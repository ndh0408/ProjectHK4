package com.luma.dto.response.subscription;

import com.luma.entity.enums.SubscriptionPlan;
import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

@Data
@Builder
public class SubscriptionPlanInfo {
    private String name;  // Enum name: FREE, STANDARD, PREMIUM, VIP
    private SubscriptionPlan planType;
    private String displayName;
    private BigDecimal monthlyPrice;
    private String priceFormatted;
    private String maxEventsPerMonth;
    private String maxAttendeesPerEvent;
    private String aiUsagePerMonth;
    private boolean canGenerateCertificates;
    private boolean canExportExcel;
    private int boostDiscountPercent;
    private String badge;
    private String badgeColor;
    private String description;
    private List<String> features;
    private boolean isPopular;

    public static SubscriptionPlanInfo fromEnum(SubscriptionPlan plan) {
        List<String> features = new ArrayList<>();
        String description;
        boolean isPopular = false;

        switch (plan) {
            case FREE -> {
                features.add("✓ 3 events per month");
                features.add("✓ Up to 100 attendees per event");
                features.add("✓ 3 AI generations per month");
                features.add("✓ Basic event management");
                features.add("✗ No certificates");
                features.add("✗ No Excel export");
                description = "Perfect for getting started with event management";
            }
            case STANDARD -> {
                features.add("✓ 10 events per month");
                features.add("✓ Up to 500 attendees per event");
                features.add("✓ 30 AI generations per month");
                features.add("✓ Generate certificates");
                features.add("✓ Export to Excel");
                features.add("✓ 10% boost discount");
                description = "Great for regular event organizers";
            }
            case PREMIUM -> {
                features.add("✓ 30 events per month");
                features.add("✓ Up to 2,000 attendees per event");
                features.add("✓ Unlimited AI generations");
                features.add("✓ Generate certificates");
                features.add("✓ Export to Excel");
                features.add("✓ 20% boost discount");
                features.add("★ Most popular choice");
                description = "Best for professional event organizers";
                isPopular = true;
            }
            case VIP -> {
                features.add("✓ Unlimited events");
                features.add("✓ Unlimited attendees");
                features.add("✓ Unlimited AI generations");
                features.add("✓ Generate certificates");
                features.add("✓ Export to Excel");
                features.add("✓ 30% boost discount");
                features.add("★ Priority support");
                features.add("★ Best for enterprises");
                description = "Ultimate plan for large-scale event management";
            }
            default -> {
                description = "";
            }
        }

        return SubscriptionPlanInfo.builder()
                .name(plan.name())
                .planType(plan)
                .displayName(plan.getDisplayName())
                .monthlyPrice(plan.getMonthlyPrice())
                .priceFormatted(plan.getMonthlyPrice().compareTo(BigDecimal.ZERO) == 0
                        ? "Free"
                        : String.format("$%.2f/month", plan.getMonthlyPrice()))
                .maxEventsPerMonth(plan.isUnlimitedEvents() ? "Unlimited" : String.valueOf(plan.getMaxEventsPerMonth()))
                .maxAttendeesPerEvent(plan.isUnlimitedAttendees() ? "Unlimited" : String.valueOf(plan.getMaxAttendeesPerEvent()))
                .aiUsagePerMonth(plan.isUnlimitedAI() ? "Unlimited" : String.valueOf(plan.getAiUsagePerMonth()))
                .canGenerateCertificates(plan.isCanGenerateCertificates())
                .canExportExcel(plan.isCanExportExcel())
                .boostDiscountPercent(plan.getBoostDiscountPercent())
                .badge(plan.getBadgeText())
                .badgeColor(plan.getBadgeColor())
                .description(description)
                .features(features)
                .isPopular(isPopular)
                .build();
    }
}

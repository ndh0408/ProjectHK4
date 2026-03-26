package com.luma.dto.response.boost;

import com.luma.entity.enums.BoostPackage;
import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;
import java.util.ArrayList;

@Data
@Builder
public class BoostPackageInfo {
    private BoostPackage packageType;
    private String displayName;
    private int durationDays;
    private BigDecimal price;
    private String priceFormatted;
    private double boostMultiplier;
    private String boostMultiplierText;
    private String badge;
    private String badgeColor;
    private String description;
    private List<String> features;

    // Feature flags
    private boolean priorityInSearch;
    private boolean featuredInCategory;
    private boolean featuredOnHome;
    private boolean homeBanner;

    public static BoostPackageInfo fromEnum(BoostPackage pkg) {
        List<String> features = new ArrayList<>();
        String description;
        String badgeColor;

        switch (pkg) {
            case BASIC -> {
                features.add("✓ Priority in search results");
                features.add("✓ 1.5x visibility boost");
                features.add("✓ 7 days duration");
                features.add("✓ \"BOOSTED\" badge on event");
                description = "Get noticed first in search results with priority placement";
                badgeColor = "#3B82F6"; // Blue
            }
            case STANDARD -> {
                features.add("✓ All BASIC features");
                features.add("✓ 2x visibility boost");
                features.add("✓ 14 days duration");
                features.add("✓ Featured in category listings");
                features.add("✓ \"FEATURED\" badge on event");
                description = "Stand out in your category with featured placement and enhanced visibility";
                badgeColor = "#8B5CF6"; // Purple
            }
            case PREMIUM -> {
                features.add("✓ All STANDARD features");
                features.add("✓ 3x visibility boost");
                features.add("✓ 30 days duration");
                features.add("✓ Featured on home page");
                features.add("✓ \"PREMIUM\" badge on event");
                features.add("★ Recommended for maximum reach");
                description = "Maximum exposure with home page featuring and premium badge";
                badgeColor = "#7C3AED"; // Deep purple
            }
            case VIP -> {
                features.add("✓ All PREMIUM features");
                features.add("✓ 5x visibility boost");
                features.add("✓ 30 days duration");
                features.add("✓ Home page banner placement");
                features.add("✓ Exclusive \"VIP\" badge");
                features.add("★ Highest priority placement");
                features.add("★ Best for major events");
                description = "Ultimate visibility with exclusive banner placement and VIP treatment";
                badgeColor = "#F59E0B"; // Gold/Orange
            }
            default -> {
                description = "";
                badgeColor = "#6B7280"; // Gray
            }
        }

        return BoostPackageInfo.builder()
                .packageType(pkg)
                .displayName(pkg.getDisplayName())
                .durationDays(pkg.getDurationDays())
                .price(pkg.getPrice())
                .priceFormatted(String.format("$%.2f", pkg.getPrice()))
                .boostMultiplier(pkg.getBoostMultiplier())
                .boostMultiplierText(String.format("%.1fx visibility", pkg.getBoostMultiplier()))
                .badge(pkg.getBadgeText())
                .badgeColor(badgeColor)
                .description(description)
                .features(features)
                .priorityInSearch(pkg.isPriorityInSearch())
                .featuredInCategory(pkg.isFeaturedInCategory())
                .featuredOnHome(pkg.isFeaturedOnHome())
                .homeBanner(pkg.isHomeBanner())
                .build();
    }
}

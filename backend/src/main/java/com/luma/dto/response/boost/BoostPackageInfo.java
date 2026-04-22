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
    private String packageKey;
    private String displayName;
    private int durationDays;
    private BigDecimal price;
    private String priceFormatted;
    private BigDecimal originalPrice;
    private String originalPriceFormatted;
    private boolean discountEligible;
    private int discountPercent;
    private double boostMultiplier;
    private String boostMultiplierText;
    private String badge;
    private String badgeColor;
    private String description;
    private List<String> features;

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
                features.add("✓ Prioritized in upcoming discovery lists");
                features.add("✓ 7 days duration");
                features.add("✓ \"BOOSTED\" badge on event");
                description = "Move above non-boosted events in search and discovery lists for 7 days";
                badgeColor = "#3B82F6";
            }
            case STANDARD -> {
                features.add("✓ All BASIC features");
                features.add("✓ 14 days duration");
                features.add("✓ Featured in category listings");
                features.add("✓ Higher placement in city listings");
                features.add("✓ \"FEATURED\" badge on event");
                description = "Get stronger placement across search, category, and city discovery surfaces";
                badgeColor = "#8B5CF6";
            }
            case PREMIUM -> {
                features.add("✓ All STANDARD features");
                features.add("✓ 30 days duration");
                features.add("✓ Featured in the home sponsored section");
                features.add("✓ \"PREMIUM\" badge on event");
                features.add("★ Recommended for maximum reach");
                description = "Add home page featured placement on top of search and listing priority";
                badgeColor = "#7C3AED";
            }
            case VIP -> {
                features.add("✓ All PREMIUM features");
                features.add("✓ 30 days duration");
                features.add("✓ Home page banner placement");
                features.add("✓ Exclusive \"VIP\" badge");
                features.add("★ Highest priority placement");
                features.add("★ Best for major events");
                description = "Get the strongest placement with VIP banner exposure and top-tier discovery priority";
                badgeColor = "#F59E0B";
            }
            default -> {
                description = "";
                badgeColor = "#6B7280";
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

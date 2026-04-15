package com.luma.dto.response.userboost;

import com.luma.entity.enums.UserBoostPackage;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserBoostPackageInfo {

    private UserBoostPackage packageType;
    private String displayName;
    private String description;
    private int durationDays;
    private BigDecimal price;
    private String priceFormatted;
    private double boostMultiplier;
    private boolean priorityInSearch;
    private boolean showBadge;
    private String badgeText;

    public static UserBoostPackageInfo fromEnum(UserBoostPackage pkg) {
        return UserBoostPackageInfo.builder()
                .packageType(pkg)
                .displayName(pkg.getDisplayName())
                .description(pkg.getDescription())
                .durationDays(pkg.getDurationDays())
                .price(pkg.getPrice())
                .priceFormatted(String.format("$%.2f", pkg.getPrice()))
                .boostMultiplier(pkg.getBoostMultiplier())
                .priorityInSearch(pkg.isPriorityInSearch())
                .showBadge(pkg.isShowBadge())
                .badgeText(pkg.getBadgeText())
                .build();
    }
}

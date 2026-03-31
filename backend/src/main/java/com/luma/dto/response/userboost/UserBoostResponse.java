package com.luma.dto.response.userboost;

import com.luma.entity.UserBoost;
import com.luma.entity.enums.BoostStatus;
import com.luma.entity.enums.UserBoostPackage;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserBoostResponse {

    private UUID id;
    private UUID eventId;
    private String eventTitle;
    private String eventImageUrl;
    private UserBoostPackage boostPackage;
    private String packageDisplayName;
    private BoostStatus status;
    private BigDecimal amount;
    private LocalDateTime startTime;
    private LocalDateTime endTime;
    private LocalDateTime paidAt;
    private boolean isActive;
    private int daysRemaining;
    private int viewsDuringBoost;
    private int clicksDuringBoost;
    private LocalDateTime createdAt;

    public static UserBoostResponse fromEntity(UserBoost boost) {
        return UserBoostResponse.builder()
                .id(boost.getId())
                .eventId(boost.getEvent().getId())
                .eventTitle(boost.getEvent().getTitle())
                .eventImageUrl(boost.getEvent().getImageUrl())
                .boostPackage(boost.getBoostPackage())
                .packageDisplayName(boost.getBoostPackage().getDisplayName())
                .status(boost.getStatus())
                .amount(boost.getAmount())
                .startTime(boost.getStartTime())
                .endTime(boost.getEndTime())
                .paidAt(boost.getPaidAt())
                .isActive(boost.isActive())
                .daysRemaining(boost.getDaysRemaining())
                .viewsDuringBoost(boost.getViewsDuringBoost())
                .clicksDuringBoost(boost.getClicksDuringBoost())
                .createdAt(boost.getCreatedAt())
                .build();
    }
}

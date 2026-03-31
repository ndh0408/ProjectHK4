package com.luma.dto.response.boost;

import com.luma.entity.enums.BoostPackage;
import com.luma.entity.enums.BoostStatus;
import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
public class BoostResponse {
    private UUID id;
    private UUID eventId;
    private String eventTitle;
    private String eventImageUrl;
    private BoostPackage boostPackage;
    private String packageDisplayName;
    private BoostStatus status;
    private BigDecimal amount;
    private LocalDateTime startTime;
    private LocalDateTime endTime;
    private LocalDateTime paidAt;
    private boolean isActive;
    private int daysRemaining;

    private int viewsBeforeBoost;
    private int viewsDuringBoost;
    private int clicksBeforeBoost;
    private int clicksDuringBoost;
    private int registrationsBeforeBoost;
    private int registrationsDuringBoost;
    private double conversionRate;

    private LocalDateTime createdAt;
}

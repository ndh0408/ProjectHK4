package com.luma.dto.response.boost;

import com.luma.entity.enums.BoostPackage;
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
public class BoostUpgradeInfo {

    private boolean hasExistingBoost;
    private boolean canBoost;
    private BoostAction action;

    private BoostPackage currentPackage;
    private BoostPackage newPackage;
    private UUID currentBoostId;

    private int remainingDays;
    private LocalDateTime currentEndTime;
    private LocalDateTime newEndTime;
    private int additionalDays;

    private BigDecimal price;
    private BigDecimal originalPrice;
    private BigDecimal refundAmount;

    private String message;

    public enum BoostAction {
        NEW,
        EXTEND,
        UPGRADE,
        DOWNGRADE
    }
}

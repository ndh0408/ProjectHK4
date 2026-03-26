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

    private BigDecimal price;           // Final price to pay
    private BigDecimal originalPrice;   // Original price before refund
    private BigDecimal refundAmount;    // Prorated refund for upgrade

    private String message;

    public enum BoostAction {
        NEW,        // No existing boost - create new
        EXTEND,     // Same package - add more days
        UPGRADE,    // Higher tier package
        DOWNGRADE   // Lower tier package (still allowed)
    }
}

package com.luma.entity.enums;

public enum PayoutStatus {
    PENDING,        // Waiting for event to complete
    PROCESSING,     // Payout initiated
    COMPLETED,      // Payout successful
    FAILED,         // Payout failed
    CANCELLED,      // Payout cancelled (e.g., event cancelled)
    ON_HOLD         // Payout on hold (e.g., dispute)
}

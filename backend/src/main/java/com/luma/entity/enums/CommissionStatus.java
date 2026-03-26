package com.luma.entity.enums;

/**
 * Status of a commission transaction
 */
public enum CommissionStatus {
    /**
     * Commission recorded but payment not yet confirmed
     */
    PENDING,

    /**
     * Payment confirmed, commission is confirmed
     */
    CONFIRMED,

    /**
     * Commission has been paid out to organiser
     */
    SETTLED,

    /**
     * Commission was refunded (due to ticket refund)
     */
    REFUNDED,

    /**
     * Commission was cancelled (payment failed)
     */
    CANCELLED
}

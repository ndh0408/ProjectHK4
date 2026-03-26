package com.luma.entity.enums;

/**
 * Status of a withdrawal request
 */
public enum WithdrawalStatus {
    /**
     * Organiser submitted request, waiting for admin review
     */
    PENDING,

    /**
     * Admin approved, waiting for processing
     */
    APPROVED,

    /**
     * Transfer is being processed via Stripe
     */
    PROCESSING,

    /**
     * Transfer completed successfully
     */
    COMPLETED,

    /**
     * Admin rejected the request
     */
    REJECTED,

    /**
     * Organiser cancelled the request
     */
    CANCELLED
}

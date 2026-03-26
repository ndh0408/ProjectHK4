package com.luma.entity.enums;

public enum PaymentStatus {
    PENDING,           // Payment initiated but not completed
    PROCESSING,        // Payment is being processed
    SUCCEEDED,         // Payment successful
    FAILED,            // Payment failed
    CANCELLED,         // Payment cancelled by user
    REFUNDED           // Payment refunded
}

package com.luma.entity.enums;

public enum NotificationType {
    SYSTEM,
    EVENT_CREATED,        // Admin receives when organiser creates event
    EVENT_APPROVED,       // Organiser receives when admin approves event
    EVENT_REJECTED,       // Organiser receives when admin rejects event
    EVENT_REMINDER,
    EVENT_UPDATE,
    REGISTRATION_APPROVED,
    REGISTRATION_REJECTED,
    NEW_FOLLOWER,
    QUESTION_ANSWERED,
    NEW_REGISTRATION,     // Organiser receives when user registers for their event
    NEW_QUESTION,         // Organiser receives when user asks a question about their event
    REGISTRATION_CANCELLED, // Organiser receives when user cancels registration
    REPLY_MESSAGE,        // Reply message in notification thread (both organiser and user)
    BROADCAST,
    PAYMENT,              // Payment related notifications (withdrawal, payout)
    WITHDRAWAL_REQUEST,   // Admin receives when organiser requests withdrawal
    WITHDRAWAL_APPROVED,  // Organiser receives when admin approves withdrawal
    WITHDRAWAL_REJECTED,  // Organiser receives when admin rejects withdrawal
    WITHDRAWAL_COMPLETED  // Organiser receives when withdrawal is completed
}

package com.luma.entity.enums;

/**
 * Poll State Machine:
 * DRAFT → SCHEDULED → ACTIVE → CLOSED
 *   ↓         ↓          ↓
 *  EDIT    CANCEL      REOPEN
 *
 * DRAFT: Poll đang chuẩn bị, chưa publish
 * SCHEDULED: Đã lên lịch, chờ đến giờ mở (auto-open)
 * ACTIVE: Đang mở, có thể vote
 * CLOSED: Đã đóng, không thể vote (có thể reopen)
 * CANCELLED: Đã hủy (cho poll DRAFT/SCHEDULED)
 */
public enum PollStatus {
    DRAFT,      // Chuẩn bị, chưa publish
    SCHEDULED,  // Đã lên lịch, chờ auto-open
    ACTIVE,     // Đang mở, có thể vote
    CLOSED,     // Đã đóng
    CANCELLED   // Đã hủy
}

package com.luma.entity;

import com.luma.entity.enums.PollStatus;
import com.luma.entity.enums.PollType;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "polls")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Poll {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "event_id", nullable = false)
    private Event event;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by", nullable = false)
    private User createdBy;

    @Column(nullable = false, columnDefinition = "NVARCHAR(500)")
    private String question;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private PollType type = PollType.SINGLE_CHOICE;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private PollStatus status = PollStatus.DRAFT;  // Mặc định là DRAFT

    @Column(name = "allow_multiple")
    @Builder.Default
    private boolean allowMultiple = false;

    @Column(name = "max_rating")
    private Integer maxRating;

    private LocalDateTime closesAt;           // Thời gian tự động đóng

    private LocalDateTime closedAt;           // Thời gian thực tế đã đóng

    @Column(name = "scheduled_open_at")
    private LocalDateTime scheduledOpenAt;  // Thời gian lên lịch mở

    @Column(name = "opened_at")
    private LocalDateTime openedAt;         // Thời gian thực tế đã mở

    @Builder.Default
    private int totalVotes = 0;

    @Column(name = "close_at_vote_count")
    private Integer closeAtVoteCount;       // Tự động đóng khi đủ số vote

    @Column(name = "auto_open_event_start", nullable = false)
    @Builder.Default
    private boolean autoOpenEventStart = false;  // Tự động mở khi event bắt đầu

    @Column(name = "auto_close_event_end", nullable = false)
    @Builder.Default
    private boolean autoCloseEventEnd = false;   // Tự động đóng khi event kết thúc

    @Column(name = "auto_close_ten_days_after_event_end", nullable = false)
    @Builder.Default
    private boolean autoCloseTenDaysAfterEventEnd = false;  // Tự động đóng 10 ngày sau khi event kết thúc

    @Column(name = "hide_results_until_closed", nullable = false)
    @Builder.Default
    private boolean hideResultsUntilClosed = false;  // Ẩn kết quả đến khi đóng

    @Column(name = "chat_message_id")
    private UUID chatMessageId;  // ID tin nhắn đã đăng trong event group chat (idempotent flag)

    @OneToMany(mappedBy = "poll", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @Builder.Default
    @OrderBy("displayOrder ASC")
    private List<PollOption> options = new ArrayList<>();

    @CreationTimestamp
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;

    /**
     * Kiểm tra poll có đang ở trạng thái có thể vote hay không
     * Chỉ ACTIVE và chưa quá closesAt mới có thể vote
     */
    public boolean isActive() {
        if (status != PollStatus.ACTIVE) return false;
        if (closesAt != null && LocalDateTime.now().isAfter(closesAt)) return false;
        return true;
    }

    /**
     * Kiểm tra poll có thể được publish từ DRAFT
     */
    public boolean canPublish() {
        return status == PollStatus.DRAFT;
    }

    /**
     * Kiểm tra poll có thể được mở (từ SCHEDULED)
     */
    public boolean canOpen() {
        return status == PollStatus.SCHEDULED;
    }

    /**
     * Kiểm tra poll có thể được đóng
     */
    public boolean canClose() {
        return status == PollStatus.ACTIVE;
    }

    /**
     * Kiểm tra poll có thể được mở lại (reopen)
     */
    public boolean canReopen() {
        return status == PollStatus.CLOSED;
    }

    /**
     * Kiểm tra poll có thể được hủy
     */
    public boolean canCancel() {
        return status == PollStatus.DRAFT || status == PollStatus.SCHEDULED;
    }

    /**
     * Kiểm tra poll có thể được chỉnh sửa (edit)
     */
    public boolean canEdit() {
        // Chỉ cho edit khi DRAFT hoặc SCHEDULED (chưa có vote)
        return (status == PollStatus.DRAFT || status == PollStatus.SCHEDULED)
                && totalVotes == 0;
    }

    /**
     * Kiểm tra poll có nên tự động đóng do đủ số vote
     */
    public boolean shouldAutoCloseByVoteCount() {
        return closeAtVoteCount != null && totalVotes >= closeAtVoteCount;
    }

    /**
     * Kiểm tra poll đã đến giờ mở (scheduledOpenAt)
     */
    public boolean isReadyToOpen() {
        return status == PollStatus.SCHEDULED
                && scheduledOpenAt != null
                && !LocalDateTime.now().isBefore(scheduledOpenAt);
    }
}

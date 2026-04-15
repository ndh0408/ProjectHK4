package com.luma.dto.request;

import com.luma.entity.enums.PollType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

@Data
public class CreatePollRequest {

    @NotBlank
    @Size(max = 500)
    private String question;

    @NotNull
    private PollType type;

    @Size(min = 2, max = 10)
    private List<String> options;

    private Integer maxRating;

    private LocalDateTime closesAt;

    // Schedule settings
    private LocalDateTime scheduledOpenAt;     // Thời gian lên lịch mở
    private Boolean draft;                     // Lưu nháp (DRAFT state)

    // Auto-close settings
    private Integer closeAtVoteCount;                   // Tự động đóng khi đủ số vote
    private boolean autoOpenEventStart = false;         // Tự động mở khi event bắt đầu
    private boolean autoCloseEventEnd = false;          // Tự động đóng khi event kết thúc
    private boolean autoCloseTenDaysAfterEventEnd = false;  // Tự động đóng 10 ngày sau khi event kết thúc

    // Display settings
    private boolean hideResultsUntilClosed = false;    // Ẩn kết quả đến khi đóng poll
}

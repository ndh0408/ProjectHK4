package com.luma.scheduler;

import com.luma.config.RateLimitConfig;
import com.luma.service.PollService;
import com.luma.service.SeatMapService;
import com.luma.service.WebhookService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class CleanupScheduler {

    private final RateLimitConfig rateLimitConfig;
    private final WebhookService webhookService;
    private final PollService pollService;
    private final SeatMapService seatMapService;

    @Scheduled(fixedRate = 3600000)
    public void cleanupRateLimitBuckets() {
        log.debug("Running rate limit bucket cleanup...");
        rateLimitConfig.cleanupOldBuckets();
    }

    @Scheduled(fixedRate = 120000)
    public void autoCloseExpiredPolls() {
        pollService.autoCloseExpiredPolls();
    }

    @Scheduled(fixedRate = 60000)  // Mỗi phút kiểm tra poll cần mở
    public void autoOpenScheduledPolls() {
        pollService.autoOpenScheduledPolls();
    }

    @Scheduled(fixedRate = 60000)  // Mỗi phút kiểm tra event bắt đầu/kết thúc
    public void autoOpenCloseByEventTime() {
        pollService.autoOpenPollsByEventStart();
        pollService.autoClosePollsByEventEnd();
        pollService.autoClosePollsTenDaysAfterEventEnd();  // Kiểm tra đóng poll sau 10 ngày
    }

    @Scheduled(fixedRate = 30000)  // Mỗi 30 giây kiểm tra vote count
    public void autoCloseByVoteCount() {
        pollService.autoCloseByVoteCount();
    }

    @Scheduled(fixedRate = 60000)
    public void releaseExpiredSeatLocks() {
        seatMapService.releaseExpiredLocks();
    }

    @Scheduled(cron = "0 0 3 * * *")
    public void cleanupOldWebhookEvents() {
        log.info("Running webhook events cleanup...");
        int deleted = webhookService.cleanupOldEvents();
        if (deleted > 0) {
            log.info("Cleaned up {} old webhook events", deleted);
        }
    }
}

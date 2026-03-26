package com.luma.scheduler;

import com.luma.config.RateLimitConfig;
import com.luma.service.WebhookService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Scheduler để cleanup các data cũ/không cần thiết
 * Tránh memory leak và giữ database sạch
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class CleanupScheduler {

    private final RateLimitConfig rateLimitConfig;
    private final WebhookService webhookService;

    /**
     * Cleanup rate limit buckets mỗi giờ
     */
    @Scheduled(fixedRate = 3600000) // 1 hour
    public void cleanupRateLimitBuckets() {
        log.debug("Running rate limit bucket cleanup...");
        rateLimitConfig.cleanupOldBuckets();
    }

    /**
     * Cleanup old webhook events mỗi ngày lúc 3:00 AM
     */
    @Scheduled(cron = "0 0 3 * * *")
    public void cleanupOldWebhookEvents() {
        log.info("Running webhook events cleanup...");
        int deleted = webhookService.cleanupOldEvents();
        if (deleted > 0) {
            log.info("Cleaned up {} old webhook events", deleted);
        }
    }
}

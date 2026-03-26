package com.luma.service;

import com.luma.entity.ProcessedWebhookEvent;
import com.luma.repository.ProcessedWebhookEventRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

/**
 * Service để quản lý webhook events và đảm bảo idempotency
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class WebhookService {

    private final ProcessedWebhookEventRepository webhookEventRepository;

    /**
     * Check và mark event as processed
     * Returns true nếu event chưa được xử lý và đã được mark thành công
     * Returns false nếu event đã được xử lý trước đó
     */
    @Transactional
    public boolean markEventAsProcessed(String eventId, String eventType, String source) {
        // Quick check first (không cần lock)
        if (webhookEventRepository.existsByEventId(eventId)) {
            log.info("Webhook event {} already processed, skipping", eventId);
            return false;
        }

        // Try to insert - database unique constraint sẽ prevent race condition
        try {
            ProcessedWebhookEvent event = ProcessedWebhookEvent.builder()
                    .eventId(eventId)
                    .eventType(eventType)
                    .source(source)
                    .build();
            webhookEventRepository.save(event);
            log.debug("Marked webhook event {} as processed", eventId);
            return true;
        } catch (DataIntegrityViolationException e) {
            // Duplicate event - another thread/instance already processed it
            log.info("Webhook event {} already processed (concurrent), skipping", eventId);
            return false;
        }
    }

    /**
     * Check if event was already processed
     */
    public boolean isEventProcessed(String eventId) {
        return webhookEventRepository.existsByEventId(eventId);
    }

    /**
     * Cleanup old events (older than 30 days)
     * Should be called by scheduled job
     */
    @Transactional
    public int cleanupOldEvents() {
        LocalDateTime cutoffDate = LocalDateTime.now().minusDays(30);
        int deleted = webhookEventRepository.deleteOlderThan(cutoffDate);
        if (deleted > 0) {
            log.info("Cleaned up {} old webhook events", deleted);
        }
        return deleted;
    }
}

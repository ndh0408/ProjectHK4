package com.luma.service;

import com.luma.entity.ProcessedWebhookEvent;
import com.luma.repository.ProcessedWebhookEventRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
@Slf4j
public class WebhookService {

    private final ProcessedWebhookEventRepository webhookEventRepository;

    @Transactional
    public boolean markEventAsProcessed(String eventId, String eventType, String source) {
        if (webhookEventRepository.existsByEventId(eventId)) {
            log.info("Webhook event {} already processed, skipping", eventId);
            return false;
        }

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
            log.info("Webhook event {} already processed (concurrent), skipping", eventId);
            return false;
        }
    }

    public boolean isEventProcessed(String eventId) {
        return webhookEventRepository.existsByEventId(eventId);
    }

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

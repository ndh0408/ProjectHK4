package com.luma.scheduler;

import com.luma.entity.Event;
import com.luma.entity.enums.EventStatus;
import com.luma.repository.EventRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Scheduler để tự động cập nhật trạng thái event
 * - Chuyển PUBLISHED -> ONGOING khi event bắt đầu
 * - Chuyển ONGOING -> COMPLETED khi event kết thúc
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class EventAutoCompleteScheduler {

    private final EventRepository eventRepository;

    /**
     * Chạy mỗi 5 phút để cập nhật trạng thái events
     */
    @Scheduled(fixedRate = 300000) // 5 minutes
    @Transactional
    public void updateEventStatuses() {
        LocalDateTime now = LocalDateTime.now();

        // Update PUBLISHED -> ONGOING (event đã bắt đầu)
        int startedCount = markEventsAsOngoing(now);
        if (startedCount > 0) {
            log.info("Marked {} events as ONGOING", startedCount);
        }

        // Update ONGOING -> COMPLETED (event đã kết thúc)
        int completedCount = markEventsAsCompleted(now);
        if (completedCount > 0) {
            log.info("Marked {} events as COMPLETED", completedCount);
        }
    }

    private int markEventsAsOngoing(LocalDateTime now) {
        List<Event> eventsToStart = eventRepository.findByStatusAndStartTimeBefore(
                EventStatus.PUBLISHED, now);

        for (Event event : eventsToStart) {
            event.setStatus(EventStatus.ONGOING);
            eventRepository.save(event);
            log.debug("Event '{}' (id: {}) marked as ONGOING", event.getTitle(), event.getId());
        }

        return eventsToStart.size();
    }

    private int markEventsAsCompleted(LocalDateTime now) {
        List<Event> eventsToComplete = eventRepository.findByStatusAndEndTimeBefore(
                EventStatus.ONGOING, now);

        for (Event event : eventsToComplete) {
            event.setStatus(EventStatus.COMPLETED);
            eventRepository.save(event);
            log.debug("Event '{}' (id: {}) marked as COMPLETED", event.getTitle(), event.getId());
        }

        return eventsToComplete.size();
    }
}

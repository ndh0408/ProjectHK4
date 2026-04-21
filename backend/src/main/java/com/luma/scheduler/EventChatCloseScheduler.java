package com.luma.scheduler;

import com.luma.entity.Conversation;
import com.luma.repository.ConversationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Component
@RequiredArgsConstructor
@Slf4j
public class EventChatCloseScheduler {

    private final ConversationRepository conversationRepository;

    @Scheduled(fixedRate = 600_000, initialDelay = 60_000)
    @Transactional
    public void closeEndedEventChats() {
        LocalDateTime cutoff = LocalDateTime.now().minusDays(1);
        List<Conversation> toClose = conversationRepository.findEventGroupsToClose(cutoff);

        if (toClose.isEmpty()) {
            return;
        }

        LocalDateTime now = LocalDateTime.now();
        for (Conversation conversation : toClose) {
            conversation.setClosedAt(now);
            conversation.setLastMessageContent("Group chat closed — event ended over 24h ago");
            conversation.setLastMessageAt(now);
            log.info("Event group chat closed for event '{}' (conversation={})",
                    conversation.getEvent() != null ? conversation.getEvent().getTitle() : "?",
                    conversation.getId());
        }
        conversationRepository.saveAll(toClose);

        log.info("Closed {} event group chat(s) whose events ended more than 24h ago", toClose.size());
    }
}

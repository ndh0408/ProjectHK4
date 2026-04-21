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
        runCloseCheck();
    }

    /**
     * Manual trigger for testing
     */
    @Transactional
    public int runCloseCheck() {
        LocalDateTime cutoff = LocalDateTime.now().minusDays(7);
        List<Conversation> toClose = conversationRepository.findEventGroupsToClose(cutoff);

        if (toClose.isEmpty()) {
            log.info("No event chats to close (checked events ending before {})", cutoff);
            return 0;
        }

        LocalDateTime now = LocalDateTime.now();
        for (Conversation conversation : toClose) {
            conversation.setClosedAt(now);
            conversation.setLastMessageContent("Group chat closed — event ended over 7 days ago");
            conversation.setLastMessageAt(now);
            log.info("Event group chat closed for event '{}' (conversation={})",
                    conversation.getEvent() != null ? conversation.getEvent().getTitle() : "?",
                    conversation.getId());
        }
        conversationRepository.saveAll(toClose);

        log.info("Closed {} event group chat(s) whose events ended more than 7 days ago", toClose.size());
        return toClose.size();
    }
}

package com.luma.service;

import com.luma.dto.response.MessageResponse;
import com.luma.entity.Conversation;
import com.luma.entity.ConversationParticipant;
import com.luma.entity.Event;
import com.luma.entity.Message;
import com.luma.entity.Poll;
import com.luma.entity.enums.ConversationType;
import com.luma.entity.enums.MessageType;
import com.luma.repository.ConversationParticipantRepository;
import com.luma.repository.ConversationRepository;
import com.luma.repository.MessageRepository;
import com.luma.repository.PollRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
@Slf4j
public class PollChatPoster {

    private final ConversationRepository conversationRepository;
    private final MessageRepository messageRepository;
    private final ConversationParticipantRepository participantRepository;
    private final PollRepository pollRepository;
    private final ChatWebSocketService webSocketService;

    /**
     * Post a POLL-type message into the event's group chat so attendees can
     * vote inline. Idempotent — skips if the poll already has a chat message.
     */
    @Transactional
    public void postPollToEventChat(Poll poll) {
        if (poll.getChatMessageId() != null) {
            return;
        }

        Event event = poll.getEvent();
        Conversation conversation = conversationRepository
                .findByEventAndType(event, ConversationType.EVENT_GROUP)
                .orElseGet(() -> createEventGroupChat(event));

        // Don't post into a closed chat — ended events.
        if (conversation.getClosedAt() != null) {
            log.debug("Skip posting poll {} to chat {} — conversation closed", poll.getId(), conversation.getId());
            return;
        }

        Message message = Message.builder()
                .conversation(conversation)
                .sender(poll.getCreatedBy())
                .type(MessageType.POLL)
                .content(poll.getQuestion())
                .poll(poll)
                .createdAt(LocalDateTime.now())
                .build();
        message = messageRepository.save(message);

        String preview = "📊 Poll: " + poll.getQuestion();
        conversation.setLastMessageContent(preview);
        conversation.setLastMessageAt(message.getCreatedAt());
        conversationRepository.save(conversation);

        participantRepository.incrementUnreadCountExceptSender(conversation, poll.getCreatedBy());

        poll.setChatMessageId(message.getId());
        pollRepository.save(poll);

        MessageResponse response = MessageResponse.fromEntity(message, pid -> false);
        // Only fire the WS broadcast once the enclosing transaction commits,
        // so clients that refetch on the event see the persisted row.
        Conversation conv = conversation;
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    webSocketService.broadcastNewMessage(conv, response);
                }
            });
        } else {
            webSocketService.broadcastNewMessage(conv, response);
        }

        log.info("Posted poll {} as chat message {} in conversation {}",
                poll.getId(), message.getId(), conversation.getId());
    }

    private Conversation createEventGroupChat(Event event) {
        Conversation conversation = Conversation.builder()
                .type(ConversationType.EVENT_GROUP)
                .name(event.getTitle())
                .imageUrl(event.getImageUrl())
                .event(event)
                .build();
        conversation = conversationRepository.save(conversation);
        participantRepository.save(ConversationParticipant.builder()
                .conversation(conversation)
                .user(event.getOrganiser())
                .build());
        return conversation;
    }
}

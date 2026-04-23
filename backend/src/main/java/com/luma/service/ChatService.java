package com.luma.service;

import com.luma.dto.request.CreateGroupChatRequest;
import com.luma.dto.request.SendMessageRequest;
import com.luma.dto.response.BlockedUserResponse;
import com.luma.dto.response.ConversationResponse;
import com.luma.dto.response.EventBuddyResponse;
import com.luma.dto.response.EventChatSummaryResponse;
import com.luma.dto.response.MessageResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.*;
import com.luma.entity.enums.ConversationType;
import com.luma.entity.enums.MessageType;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.exception.BadRequestException;
import com.luma.exception.ForbiddenException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ChatService {

    private final ConversationRepository conversationRepository;
    private final ConversationParticipantRepository participantRepository;
    private final MessageRepository messageRepository;
    private final EventRepository eventRepository;
    private final RegistrationRepository registrationRepository;
    private final UserRepository userRepository;
    private final BlockedUserRepository blockedUserRepository;
    private final ChatWebSocketService webSocketService;
    private final PollVoteRepository pollVoteRepository;

    public PageResponse<ConversationResponse> getConversations(User user, Pageable pageable) {
        Page<Conversation> conversations = conversationRepository.findByUser(user, pageable);

        List<ConversationResponse> responses = conversations.getContent().stream()
                .map(conv -> {
                    ConversationParticipant participant = participantRepository
                            .findByConversationAndUser(conv, user)
                            .orElse(null);
                    return ConversationResponse.fromEntity(conv, participant);
                })
                .toList();

        return PageResponse.<ConversationResponse>builder()
                .content(responses)
                .page(conversations.getNumber())
                .size(conversations.getSize())
                .totalElements(conversations.getTotalElements())
                .totalPages(conversations.getTotalPages())
                .first(conversations.isFirst())
                .last(conversations.isLast())
                .build();
    }

    public ConversationResponse getConversation(User user, UUID conversationId) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));

        ConversationParticipant participant = participantRepository
                .findByConversationAndUser(conversation, user)
                .orElseThrow(() -> new ForbiddenException("You are not a participant of this conversation"));

        return ConversationResponse.fromEntity(conversation, participant);
    }

    @Transactional
    public ConversationResponse getOrCreateEventChat(User user, UUID eventId) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        boolean isOrganiser = event.getOrganiser().getId().equals(user.getId());
        Conversation conversation = conversationRepository.findByEventAndType(event, ConversationType.EVENT_GROUP)
                .orElse(null);
        if (conversation == null) {
            if (!isOrganiser) {
                throw new ForbiddenException("Join the event chat before opening it");
            }
            conversation = createEventGroupChat(event);
        }

        ConversationParticipant currentParticipant = isOrganiser
                ? ensureParticipant(conversation, user)
                : participantRepository.findByConversationAndUser(conversation, user)
                        .orElseThrow(() -> new ForbiddenException("Join the event chat before opening it"));

        return ConversationResponse.fromEntity(conversation, currentParticipant);
    }

    private ConversationParticipant ensureParticipant(Conversation conversation, User user) {
        return participantRepository.findByConversationAndUser(conversation, user)
                .orElseGet(() -> participantRepository.save(ConversationParticipant.builder()
                        .conversation(conversation)
                        .user(user)
                        .build()));
    }

    private Conversation createEventGroupChat(Event event) {
        Conversation conversation = Conversation.builder()
                .type(ConversationType.EVENT_GROUP)
                .name(event.getTitle())
                .imageUrl(event.getImageUrl())
                .event(event)
                .build();
        conversation = conversationRepository.save(conversation);
        ensureParticipant(conversation, event.getOrganiser());
        return conversation;
    }

    @Transactional
    public List<EventChatSummaryResponse> getEventChats(User user) {
        List<Registration> approvedRegs = registrationRepository.findByUserAndStatus(user, RegistrationStatus.APPROVED);
        List<Event> organisedEvents = eventRepository.findByOrganiserIdOrderByStartTimeDesc(user.getId());

        if (approvedRegs.isEmpty() && organisedEvents.isEmpty()) {
            return Collections.emptyList();
        }

        Map<UUID, Event> eventsById = new LinkedHashMap<>();
        for (Registration reg : approvedRegs) {
            eventsById.putIfAbsent(reg.getEvent().getId(), reg.getEvent());
        }
        // Organisers can also chat in their own event groups, even without
        // an APPROVED registration to their own event.
        for (Event event : organisedEvents) {
            eventsById.putIfAbsent(event.getId(), event);
        }

        List<EventChatSummaryResponse> summaries = new ArrayList<>(eventsById.size());
        for (Event event : eventsById.values()) {
            boolean isOrganiser = event.getOrganiser().getId().equals(user.getId());
            Conversation conversation = conversationRepository
                    .findByEventAndType(event, ConversationType.EVENT_GROUP)
                    .orElse(null);
            if (conversation == null && isOrganiser) {
                conversation = createEventGroupChat(event);
            }

            ConversationParticipant participant = conversation == null
                    ? null
                    : isOrganiser
                            ? ensureParticipant(conversation, user)
                            : participantRepository.findByConversationAndUser(conversation, user).orElse(null);

            int participantCount = conversation != null
                    ? (int) participantRepository.countByConversation(conversation)
                    : 0;

            summaries.add(EventChatSummaryResponse.builder()
                    .eventId(event.getId())
                    .eventTitle(event.getTitle())
                    .eventImageUrl(event.getImageUrl())
                    .eventStartTime(event.getStartTime())
                    .eventEndTime(event.getEndTime())
                    .venue(event.getVenue())
                    .conversationId(conversation != null ? conversation.getId() : null)
                    .joined(participant != null)
                    .canModerate(isOrganiser)
                    .closed(conversation != null && conversation.getClosedAt() != null)
                    .closedAt(conversation != null ? conversation.getClosedAt() : null)
                    .participantCount(participantCount)
                    .lastMessageContent(conversation != null ? conversation.getLastMessageContent() : null)
                    .lastMessageAt(conversation != null ? conversation.getLastMessageAt() : null)
                    .unreadCount(participant != null ? participant.getUnreadCount() : 0)
                    .build());
        }

        summaries.sort((a, b) -> {
            LocalDateTime aTime = a.getLastMessageAt() != null ? a.getLastMessageAt() : a.getEventStartTime();
            LocalDateTime bTime = b.getLastMessageAt() != null ? b.getLastMessageAt() : b.getEventStartTime();
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
        });

        return summaries;
    }

    @Transactional
    public EventChatSummaryResponse joinEventChat(User user, UUID eventId) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        boolean isRegistered = registrationRepository.existsByEventAndUserAndStatus(event, user, RegistrationStatus.APPROVED);
        boolean isOrganiser = event.getOrganiser().getId().equals(user.getId());

        if (!isRegistered && !isOrganiser) {
            throw new ForbiddenException("You must be registered for this event to join the chat");
        }

        Conversation conversation = conversationRepository.findByEventAndType(event, ConversationType.EVENT_GROUP)
                .orElseGet(() -> createEventGroupChat(event));

        if (conversation.getClosedAt() != null) {
            throw new BadRequestException("This event group chat has been closed");
        }

        ConversationParticipant participant = participantRepository
                .findByConversationAndUser(conversation, user)
                .orElseGet(() -> participantRepository.save(ConversationParticipant.builder()
                        .conversation(conversation)
                        .user(user)
                        .build()));

        int participantCount = (int) participantRepository.countByConversation(conversation);

        return EventChatSummaryResponse.builder()
                .eventId(event.getId())
                .eventTitle(event.getTitle())
                .eventImageUrl(event.getImageUrl())
                .eventStartTime(event.getStartTime())
                .eventEndTime(event.getEndTime())
                .venue(event.getVenue())
                .conversationId(conversation.getId())
                .joined(true)
                .canModerate(isOrganiser)
                .closed(false)
                .closedAt(null)
                .participantCount(participantCount)
                .lastMessageContent(conversation.getLastMessageContent())
                .lastMessageAt(conversation.getLastMessageAt())
                .unreadCount(participant.getUnreadCount())
                .build();
    }

    @Transactional
    public void leaveEventChat(User user, UUID eventId) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        Conversation conversation = conversationRepository.findByEventAndType(event, ConversationType.EVENT_GROUP)
                .orElseThrow(() -> new ResourceNotFoundException("Event chat not found"));

        ConversationParticipant participant = participantRepository
                .findByConversationAndUser(conversation, user)
                .orElseThrow(() -> new BadRequestException("You are not a member of this chat"));

        participantRepository.delete(participant);
    }

    @Transactional
    public ConversationResponse getOrCreateDirectChat(User currentUser, UUID otherUserId) {
        User otherUser = userRepository.findById(otherUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        if (currentUser.getId().equals(otherUserId)) {
            throw new BadRequestException("Cannot create chat with yourself");
        }

        if (blockedUserRepository.isBlockedBetween(currentUser, otherUser)) {
            throw new ForbiddenException("Cannot chat with this user");
        }

        Conversation conversation = conversationRepository.findDirectConversation(currentUser, otherUser)
                .orElseGet(() -> createDirectChat(currentUser, otherUser));

        ConversationParticipant currentParticipant = participantRepository
                .findByConversationAndUser(conversation, currentUser)
                .orElse(null);

        return ConversationResponse.fromEntity(conversation, currentParticipant);
    }

    private Conversation createDirectChat(User user1, User user2) {
        Conversation conversation = Conversation.builder()
                .type(ConversationType.DIRECT)
                .build();
        conversation = conversationRepository.save(conversation);

        participantRepository.save(ConversationParticipant.builder()
                .conversation(conversation)
                .user(user1)
                .build());
        participantRepository.save(ConversationParticipant.builder()
                .conversation(conversation)
                .user(user2)
                .build());

        return conversation;
    }

    public PageResponse<MessageResponse> getMessages(User user, UUID conversationId, Pageable pageable) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));

        if (!participantRepository.existsByConversationAndUser(conversation, user)) {
            throw new ForbiddenException("You are not a participant of this conversation");
        }

        Page<Message> messages = messageRepository.findByConversation(conversation, pageable);

        // Pre-resolve which polls on this page the viewer has already voted on,
        // so we can mark the embedded poll snapshots accordingly without N+1.
        Set<UUID> pollIds = messages.getContent().stream()
                .filter(m -> m.getType() == com.luma.entity.enums.MessageType.POLL && m.getPoll() != null)
                .map(m -> m.getPoll().getId())
                .collect(Collectors.toSet());
        Set<UUID> votedPollIds = pollIds.isEmpty()
                ? Collections.emptySet()
                : pollVoteRepository.findVotedPollIdsByUserAndPollIds(user, pollIds);

        // For polls the viewer voted on, also fetch the exact options they
        // picked so the mobile chat can highlight them.
        java.util.Map<UUID, java.util.List<UUID>> votedOptionsByPoll = new java.util.HashMap<>();
        for (UUID pollId : votedPollIds) {
            Set<UUID> opts = pollVoteRepository.findVotedOptionIdsByPollAndUser(pollId, user);
            if (!opts.isEmpty()) votedOptionsByPoll.put(pollId, new java.util.ArrayList<>(opts));
        }

        List<MessageResponse> responses = messages.getContent().stream()
                .map(m -> MessageResponse.fromEntity(m, votedPollIds::contains,
                        votedOptionsByPoll::get))
                .toList();

        return PageResponse.<MessageResponse>builder()
                .content(responses)
                .page(messages.getNumber())
                .size(messages.getSize())
                .totalElements(messages.getTotalElements())
                .totalPages(messages.getTotalPages())
                .first(messages.isFirst())
                .last(messages.isLast())
                .build();
    }

    @Transactional
    public MessageResponse sendMessage(User user, UUID conversationId, SendMessageRequest request) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));

        ConversationParticipant sender = participantRepository
                .findByConversationAndUser(conversation, user)
                .orElseThrow(() -> new ForbiddenException("You are not a participant of this conversation"));

        if (sender.isBanned()) {
            throw new ForbiddenException("You have been banned from this chat by the organiser");
        }
        if (sender.isCurrentlyMuted()) {
            throw new ForbiddenException("You are muted in this chat until " + sender.getMutedUntil());
        }

        if (conversation.getClosedAt() != null) {
            throw new BadRequestException("This event group chat has been closed");
        }

        Message replyTo = null;
        if (request.getReplyToId() != null) {
            replyTo = messageRepository.findById(request.getReplyToId()).orElse(null);
        }

        Message message = Message.builder()
                .conversation(conversation)
                .sender(user)
                .type(request.getType() != null ? request.getType() : MessageType.TEXT)
                .content(request.getContent())
                .mediaUrl(request.getMediaUrl())
                .replyTo(replyTo)
                .createdAt(LocalDateTime.now())
                .build();

        message = messageRepository.save(message);

        String lastContent = request.getContent();
        if (message.getType() == MessageType.IMAGE) {
            lastContent = "Sent an image";
        } else if (message.getType() == MessageType.FILE) {
            lastContent = "Sent a file";
        }
        conversation.setLastMessageContent(lastContent);
        conversation.setLastMessageAt(LocalDateTime.now());
        conversationRepository.save(conversation);

        participantRepository.incrementUnreadCountExceptSender(conversation, user);

        MessageResponse response = MessageResponse.fromEntity(message);

        // Broadcast only after the DB commit so receivers that refetch on the
        // WS event see the persisted row.
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

        return response;
    }

    @Transactional
    public void markAsRead(User user, UUID conversationId) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));

        if (!participantRepository.existsByConversationAndUser(conversation, user)) {
            throw new ForbiddenException("You are not a participant of this conversation");
        }

        participantRepository.markAsRead(conversation, user, LocalDateTime.now());
    }

    @Transactional
    public void muteConversation(User user, UUID conversationId, boolean muted) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));

        ConversationParticipant participant = participantRepository
                .findByConversationAndUser(conversation, user)
                .orElseThrow(() -> new ForbiddenException("You are not a participant of this conversation"));

        participant.setMuted(muted);
        participantRepository.save(participant);
    }

    @Transactional
    public void pinConversation(User user, UUID conversationId, boolean pinned) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));

        ConversationParticipant participant = participantRepository
                .findByConversationAndUser(conversation, user)
                .orElseThrow(() -> new ForbiddenException("You are not a participant of this conversation"));

        participant.setPinned(pinned);
        participantRepository.save(participant);
    }

    @Transactional
    public void archiveConversation(User user, UUID conversationId, boolean archived) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));

        ConversationParticipant participant = participantRepository
                .findByConversationAndUser(conversation, user)
                .orElseThrow(() -> new ForbiddenException("You are not a participant of this conversation"));

        participant.setArchived(archived);
        participantRepository.save(participant);
    }

    public long getUnreadCount(User user) {
        return participantRepository.getTotalUnreadCount(user);
    }

    @Transactional
    public void muteAttendee(User organiser, UUID conversationId, UUID attendeeId, boolean mute) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));
        requireOrganiser(organiser, conversation);

        User attendee = userRepository.findById(attendeeId)
                .orElseThrow(() -> new ResourceNotFoundException("Attendee not found"));
        
        ConversationParticipant participant = participantRepository.findByConversationAndUser(conversation, attendee)
                .orElseThrow(() -> new BadRequestException("User is not a participant of this conversation"));

        participant.setMuted(mute);
        participantRepository.save(participant);
        
        // Notify via websocket or system message if needed
    }

    @Transactional
    public void banAttendee(User organiser, UUID conversationId, UUID attendeeId) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));
        requireOrganiser(organiser, conversation);

        User attendee = userRepository.findById(attendeeId)
                .orElseThrow(() -> new ResourceNotFoundException("Attendee not found"));
        
        ConversationParticipant participant = participantRepository.findByConversationAndUser(conversation, attendee)
                .orElseThrow(() -> new BadRequestException("User is not a participant of this conversation"));

        participantRepository.delete(participant);
        
        // Also block from re-joining this specific conversation in the future 
        // (Logic should be added to join/register flow)
    }

    @Transactional
    public void deleteMessage(User user, UUID messageId) {
        Message message = messageRepository.findById(messageId)
                .orElseThrow(() -> new ResourceNotFoundException("Message not found"));

        boolean isSender = message.getSender() != null
                && message.getSender().getId().equals(user.getId());
        // Organisers can moderate any message in their own event group chat.
        boolean isOrganiserModerator = isEventOrganiser(user, message.getConversation());

        if (!isSender && !isOrganiserModerator) {
            throw new ForbiddenException("You can only delete your own messages");
        }

        UUID conversationId = message.getConversation().getId();

        // If the deleted message was the pinned announcement, unpin it too
        // so clients don't keep rendering a dangling banner.
        Conversation conversation = message.getConversation();
        boolean clearedPinnedMessage = false;
        if (conversation.getPinnedMessage() != null
                && conversation.getPinnedMessage().getId().equals(messageId)) {
            conversation.setPinnedMessage(null);
            conversation.setPinnedAt(null);
            conversation.setPinnedBy(null);
            conversationRepository.save(conversation);
            clearedPinnedMessage = true;
        }

        message.setDeleted(true);
        message.setDeletedBy(user);
        message.setDeletedAt(LocalDateTime.now());
        message.setContent("This message was deleted");
        message.setMediaUrl(null);
        messageRepository.save(message);

        webSocketService.broadcastMessageDeleted(conversationId, messageId);
        if (clearedPinnedMessage) {
            webSocketService.broadcastPinnedMessageUpdated(conversationId, null);
        }
    }

    /// True iff the user is the event organiser for this conversation's
    /// linked event. Only EVENT_GROUP conversations have an event; for
    /// DIRECT / GROUP chats this always returns false.
    private boolean isEventOrganiser(User user, Conversation conversation) {
        if (conversation == null || user == null) return false;
        Event event = conversation.getEvent();
        if (event == null || event.getOrganiser() == null) return false;
        return event.getOrganiser().getId().equals(user.getId());
    }

    private void requireOrganiser(User user, Conversation conversation) {
        if (conversation.getType() != ConversationType.EVENT_GROUP) {
            throw new BadRequestException("Only available in event group chats");
        }
        if (!isEventOrganiser(user, conversation)) {
            throw new ForbiddenException("Only the event organiser can perform this action");
        }
    }

    @Transactional
    public ConversationResponse pinMessage(User user, UUID conversationId, UUID messageId) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));
        requireOrganiser(user, conversation);

        Message message = messageRepository.findById(messageId)
                .orElseThrow(() -> new ResourceNotFoundException("Message not found"));
        if (!message.getConversation().getId().equals(conversationId)) {
            throw new BadRequestException("Message does not belong to this conversation");
        }
        if (message.isDeleted()) {
            throw new BadRequestException("Cannot pin a deleted message");
        }

        conversation.setPinnedMessage(message);
        conversation.setPinnedAt(LocalDateTime.now());
        conversation.setPinnedBy(user);
        conversationRepository.save(conversation);

        webSocketService.broadcastPinnedMessageUpdated(
                conversationId,
                MessageResponse.fromEntity(message, pid -> false)
        );

        ConversationParticipant participant = participantRepository
                .findByConversationAndUser(conversation, user)
                .orElse(null);
        return ConversationResponse.fromEntity(conversation, participant);
    }

    @Transactional
    public ConversationResponse unpinMessage(User user, UUID conversationId) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));
        requireOrganiser(user, conversation);

        conversation.setPinnedMessage(null);
        conversation.setPinnedAt(null);
        conversation.setPinnedBy(null);
        conversationRepository.save(conversation);

        webSocketService.broadcastPinnedMessageUpdated(conversationId, null);

        ConversationParticipant participant = participantRepository
                .findByConversationAndUser(conversation, user)
                .orElse(null);
        return ConversationResponse.fromEntity(conversation, participant);
    }

    @Transactional
    public void banParticipant(User user, UUID conversationId, UUID targetUserId) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));
        requireOrganiser(user, conversation);
        if (targetUserId.equals(user.getId())) {
            throw new BadRequestException("You cannot ban yourself");
        }

        User target = userRepository.findById(targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        ConversationParticipant participant = participantRepository
                .findByConversationAndUser(conversation, target)
                .orElseThrow(() -> new ResourceNotFoundException("User is not a participant"));

        participant.setBannedAt(LocalDateTime.now());
        participantRepository.save(participant);
    }

    @Transactional
    public void unbanParticipant(User user, UUID conversationId, UUID targetUserId) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));
        requireOrganiser(user, conversation);

        User target = userRepository.findById(targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        ConversationParticipant participant = participantRepository
                .findByConversationAndUser(conversation, target)
                .orElseThrow(() -> new ResourceNotFoundException("User is not a participant"));

        participant.setBannedAt(null);
        participantRepository.save(participant);
    }

    @Transactional
    public void muteParticipant(User user, UUID conversationId, UUID targetUserId, int minutes) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));
        requireOrganiser(user, conversation);
        if (targetUserId.equals(user.getId())) {
            throw new BadRequestException("You cannot mute yourself");
        }

        User target = userRepository.findById(targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        ConversationParticipant participant = participantRepository
                .findByConversationAndUser(conversation, target)
                .orElseThrow(() -> new ResourceNotFoundException("User is not a participant"));

        if (minutes <= 0) {
            participant.setMutedUntil(null);
        } else {
            participant.setMutedUntil(LocalDateTime.now().plusMinutes(minutes));
        }
        participantRepository.save(participant);
    }

    public PageResponse<MessageResponse> searchMessages(
            User user, UUID conversationId, String query, Pageable pageable) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));

        // User must be a participant to search the history.
        participantRepository.findByConversationAndUser(conversation, user)
                .orElseThrow(() -> new ForbiddenException("You are not a participant"));

        String trimmed = query == null ? "" : query.trim();
        if (trimmed.isEmpty()) {
            return PageResponse.<MessageResponse>builder()
                    .content(List.of())
                    .page(0).size(pageable.getPageSize())
                    .totalElements(0L).totalPages(0)
                    .first(true).last(true)
                    .build();
        }

        Page<Message> page = messageRepository.searchByConversation(
                conversation, trimmed.toLowerCase(), pageable);

        List<MessageResponse> content = page.getContent().stream()
                .map(m -> MessageResponse.fromEntity(m, pid -> false))
                .toList();

        return PageResponse.<MessageResponse>builder()
                .content(content)
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .first(page.isFirst())
                .last(page.isLast())
                .build();
    }

    @Transactional
    public ConversationResponse openSupportConversationWithOrganiser(User user, UUID eventId) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));
        User organiser = event.getOrganiser();
        if (organiser == null) {
            throw new BadRequestException("This event has no organiser to contact");
        }
        if (organiser.getId().equals(user.getId())) {
            throw new BadRequestException("You are the organiser of this event");
        }

        Conversation conversation = conversationRepository
                .findDirectConversation(user, organiser)
                .orElseGet(() -> createDirectConversation(user, organiser));

        ConversationParticipant participant = participantRepository
                .findByConversationAndUser(conversation, user)
                .orElse(null);
        return ConversationResponse.fromEntity(conversation, participant);
    }

    private Conversation createDirectConversation(User a, User b) {
        Conversation conversation = Conversation.builder()
                .type(ConversationType.DIRECT)
                .build();
        conversation = conversationRepository.save(conversation);

        participantRepository.save(ConversationParticipant.builder()
                .conversation(conversation).user(a).build());
        participantRepository.save(ConversationParticipant.builder()
                .conversation(conversation).user(b).build());
        return conversation;
    }

    @Transactional
    public void leaveConversation(User user, UUID conversationId) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));

        ConversationParticipant participant = participantRepository
                .findByConversationAndUser(conversation, user)
                .orElseThrow(() -> new ForbiddenException("You are not a participant in this conversation"));

        participantRepository.delete(participant);

        if (conversation.getType() == ConversationType.DIRECT) {
            long remainingParticipants = participantRepository.countByConversation(conversation);
            if (remainingParticipants == 0) {
                messageRepository.deleteByConversation(conversation);
                conversationRepository.delete(conversation);
            }
        }
    }

    public List<ConversationResponse.ParticipantResponse> getEventAttendees(User user, UUID eventId) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        boolean isRegistered = registrationRepository.existsByEventAndUserAndStatus(event, user, RegistrationStatus.APPROVED);
        boolean isOrganiser = event.getOrganiser().getId().equals(user.getId());

        if (!isRegistered && !isOrganiser) {
            throw new ForbiddenException("You must be registered for this event to see attendees");
        }

        return registrationRepository.findByEventAndStatus(event, RegistrationStatus.APPROVED, PageRequest.of(0, 100))
                .getContent()
                .stream()
                .filter(r -> !r.getUser().getId().equals(user.getId()))
                .map(r -> ConversationResponse.ParticipantResponse.builder()
                        .userId(r.getUser().getId())
                        .fullName(r.getUser().getFullName())
                        .avatarUrl(r.getUser().getAvatarUrl())
                        .build())
                .toList();
    }

    private static final List<RegistrationStatus> BUDDY_STATUSES = List.of(
            RegistrationStatus.APPROVED,
            RegistrationStatus.PENDING,
            RegistrationStatus.WAITING_LIST
    );

    public PageResponse<EventBuddyResponse> getEventBuddies(User user, Pageable pageable) {
        List<Registration> userRegs = registrationRepository.findByUserAndStatusIn(user, BUDDY_STATUSES);

        if (userRegs.isEmpty()) {
            return PageResponse.<EventBuddyResponse>builder()
                    .content(Collections.emptyList())
                    .page(pageable.getPageNumber())
                    .size(pageable.getPageSize())
                    .totalElements(0)
                    .totalPages(0)
                    .first(true)
                    .last(true)
                    .build();
        }

        Set<UUID> blockedUserIds = blockedUserRepository.findBlockedUserIds(user);

        List<Event> userEvents = userRegs.stream().map(Registration::getEvent).toList();
        List<Registration> allEventRegs = registrationRepository.findByEventInAndStatusIn(userEvents, BUDDY_STATUSES);

        Map<UUID, BuddyData> buddyDataMap = new HashMap<>();

        for (Registration reg : allEventRegs) {
            User buddy = reg.getUser();
            if (buddy.getId().equals(user.getId())) {
                continue;
            }
            if (blockedUserIds.contains(buddy.getId())) {
                continue;
            }

            BuddyData data = buddyDataMap.computeIfAbsent(buddy.getId(),
                k -> new BuddyData(buddy));
            data.addSharedEvent(reg.getEvent());
        }

        List<EventBuddyResponse> buddies = buddyDataMap.values().stream()
                .sorted((a, b) -> Integer.compare(b.getSharedEventsCount(), a.getSharedEventsCount()))
                .map(BuddyData::toResponse)
                .collect(Collectors.toList());

        int start = (int) pageable.getOffset();
        int end = Math.min(start + pageable.getPageSize(), buddies.size());

        List<EventBuddyResponse> pagedBuddies = start < buddies.size()
                ? buddies.subList(start, end)
                : Collections.emptyList();

        return PageResponse.<EventBuddyResponse>builder()
                .content(pagedBuddies)
                .page(pageable.getPageNumber())
                .size(pageable.getPageSize())
                .totalElements(buddies.size())
                .totalPages((int) Math.ceil((double) buddies.size() / pageable.getPageSize()))
                .first(pageable.getPageNumber() == 0)
                .last(end >= buddies.size())
                .build();
    }

    public List<EventBuddyResponse> getEventBuddiesByEvent(User user, UUID eventId) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        List<Registration> eventRegs = registrationRepository.findByEventAndStatusIn(event, BUDDY_STATUSES);

        boolean userRegistered = eventRegs.stream()
                .anyMatch(r -> r.getUser().getId().equals(user.getId()));

        if (!userRegistered) {
            throw new ForbiddenException("You must be registered for this event to see buddies");
        }

        Set<UUID> blockedUserIds = blockedUserRepository.findBlockedUserIds(user);

        List<Registration> userRegs = registrationRepository.findByUserAndStatusIn(user, BUDDY_STATUSES);
        List<Event> userEvents = userRegs.stream().map(Registration::getEvent).toList();
        List<Registration> allUserEventRegs = registrationRepository.findByEventInAndStatusIn(userEvents, BUDDY_STATUSES);

        Map<UUID, Long> sharedCountMap = allUserEventRegs.stream()
                .filter(r -> !r.getUser().getId().equals(user.getId()))
                .collect(Collectors.groupingBy(r -> r.getUser().getId(), Collectors.counting()));

        return eventRegs.stream()
                .filter(reg -> !reg.getUser().getId().equals(user.getId()))
                .filter(reg -> !blockedUserIds.contains(reg.getUser().getId()))
                .map(reg -> {
                    User buddy = reg.getUser();
                    int totalShared = sharedCountMap.getOrDefault(buddy.getId(), 1L).intValue();
                    return EventBuddyResponse.builder()
                            .userId(buddy.getId())
                            .fullName(buddy.getFullName())
                            .avatarUrl(buddy.getAvatarUrl())
                            .sharedEventsCount(totalShared)
                            .sharedEvents(List.of(
                                    EventBuddyResponse.SharedEventInfo.builder()
                                            .eventId(event.getId())
                                            .eventTitle(event.getTitle())
                                            .eventDate(event.getStartTime())
                                            .eventImageUrl(event.getImageUrl())
                                            .build()
                            ))
                            .lastEventDate(event.getStartTime())
                            .build();
                })
                .collect(Collectors.toList());
    }

    @Transactional
    public ConversationResponse createGroupChat(User user, CreateGroupChatRequest request) {
        if (request.getParticipantIds().isEmpty()) {
            throw new BadRequestException("At least 1 participant is required for a group chat");
        }

        Conversation conversation = Conversation.builder()
                .type(ConversationType.GROUP)
                .name(request.getName())
                .imageUrl(request.getImageUrl())
                .build();
        conversation = conversationRepository.save(conversation);

        ConversationParticipant creatorParticipant = ConversationParticipant.builder()
                .conversation(conversation)
                .user(user)
                .build();
        participantRepository.save(creatorParticipant);
        conversation.getParticipants().add(creatorParticipant);

        for (UUID userId : request.getParticipantIds()) {
            if (userId.equals(user.getId())) {
                continue;
            }

            User participant = userRepository.findById(userId)
                    .orElseThrow(() -> new ResourceNotFoundException("User not found: " + userId));

            ConversationParticipant newParticipant = ConversationParticipant.builder()
                    .conversation(conversation)
                    .user(participant)
                    .build();
            participantRepository.save(newParticipant);
            conversation.getParticipants().add(newParticipant);
        }

        return ConversationResponse.fromEntity(conversation, creatorParticipant);
    }

    @Transactional
    public ConversationResponse addGroupParticipants(User user, UUID conversationId, List<UUID> userIds) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));

        if (!participantRepository.existsByConversationAndUser(conversation, user)) {
            throw new ForbiddenException("You are not a participant of this conversation");
        }

        if (conversation.getType() != ConversationType.GROUP) {
            throw new BadRequestException("Can only add participants to group chats");
        }

        for (UUID userId : userIds) {
            User participant = userRepository.findById(userId)
                    .orElseThrow(() -> new ResourceNotFoundException("User not found: " + userId));

            if (!participantRepository.existsByConversationAndUser(conversation, participant)) {
                participantRepository.save(ConversationParticipant.builder()
                        .conversation(conversation)
                        .user(participant)
                        .build());
            }
        }

        ConversationParticipant currentParticipant = participantRepository
                .findByConversationAndUser(conversation, user)
                .orElse(null);

        return ConversationResponse.fromEntity(conversation, currentParticipant);
    }

    @Transactional
    public void removeGroupParticipant(User user, UUID conversationId, UUID userId) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));

        if (!participantRepository.existsByConversationAndUser(conversation, user)) {
            throw new ForbiddenException("You are not a participant of this conversation");
        }

        if (conversation.getType() != ConversationType.GROUP) {
            throw new BadRequestException("Can only remove participants from group chats");
        }

        User userToRemove = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        ConversationParticipant participant = participantRepository
                .findByConversationAndUser(conversation, userToRemove)
                .orElseThrow(() -> new ResourceNotFoundException("User is not a participant"));

        participantRepository.delete(participant);
    }

    private static class BuddyData {
        private final User user;
        private final List<Event> sharedEvents = new ArrayList<>();

        BuddyData(User user) {
            this.user = user;
        }

        void addSharedEvent(Event event) {
            sharedEvents.add(event);
        }

        int getSharedEventsCount() {
            return sharedEvents.size();
        }

        EventBuddyResponse toResponse() {
            List<EventBuddyResponse.SharedEventInfo> sharedEventInfos = sharedEvents.stream()
                    .map(e -> EventBuddyResponse.SharedEventInfo.builder()
                            .eventId(e.getId())
                            .eventTitle(e.getTitle())
                            .eventDate(e.getStartTime())
                            .eventImageUrl(e.getImageUrl())
                            .build())
                    .collect(Collectors.toList());

            return EventBuddyResponse.builder()
                    .userId(user.getId())
                    .fullName(user.getFullName())
                    .avatarUrl(user.getAvatarUrl())
                    .sharedEventsCount(sharedEvents.size())
                    .sharedEvents(sharedEventInfos)
                    .lastEventDate(sharedEvents.stream()
                            .map(Event::getStartTime)
                            .max(LocalDateTime::compareTo)
                            .orElse(null))
                    .build();
        }
    }

    @Transactional
    public void blockUser(User blocker, UUID blockedUserId, String reason) {
        if (blocker.getId().equals(blockedUserId)) {
            throw new BadRequestException("You cannot block yourself");
        }

        User blocked = userRepository.findById(blockedUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        if (blockedUserRepository.existsByBlockerAndBlocked(blocker, blocked)) {
            throw new BadRequestException("User is already blocked");
        }

        BlockedUser blockedUser = BlockedUser.builder()
                .blocker(blocker)
                .blocked(blocked)
                .reason(reason)
                .build();

        blockedUserRepository.save(blockedUser);
    }

    @Transactional
    public void unblockUser(User blocker, UUID blockedUserId) {
        User blocked = userRepository.findById(blockedUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        BlockedUser blockedUser = blockedUserRepository.findByBlockerAndBlocked(blocker, blocked)
                .orElseThrow(() -> new ResourceNotFoundException("User is not blocked"));

        blockedUserRepository.delete(blockedUser);
    }

    public List<BlockedUserResponse> getBlockedUsers(User user) {
        return blockedUserRepository.findByBlocker(user).stream()
                .map(BlockedUserResponse::fromEntity)
                .collect(Collectors.toList());
    }

    public boolean isUserBlocked(User user, UUID otherUserId) {
        User otherUser = userRepository.findById(otherUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        return blockedUserRepository.isBlockedBetween(user, otherUser);
    }
}

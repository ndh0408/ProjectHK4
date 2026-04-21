package com.luma.service;

import com.luma.dto.request.CreateGroupChatRequest;
import com.luma.dto.response.ConversationResponse;
import com.luma.dto.response.EventBuddyResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.*;
import com.luma.entity.enums.ConversationType;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.exception.BadRequestException;
import com.luma.exception.ForbiddenException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class OrganiserChatService {

    private final ConversationRepository conversationRepository;
    private final ConversationParticipantRepository participantRepository;
    private final EventRepository eventRepository;
    private final RegistrationRepository registrationRepository;
    private final UserRepository userRepository;
    private final ChatService chatService;

    @Transactional
    public void muteAttendee(User organiser, UUID conversationId, UUID attendeeId, boolean mute) {
        chatService.muteAttendee(organiser, conversationId, attendeeId, mute);
    }

    @Transactional
    public void banAttendee(User organiser, UUID conversationId, UUID attendeeId) {
        chatService.banAttendee(organiser, conversationId, attendeeId);
    }

    @Transactional
    public void deleteAnyMessage(User organiser, UUID messageId) {
        chatService.deleteMessage(organiser, messageId);
    }

    @Transactional
    public ConversationResponse pinMessage(User organiser, UUID conversationId, UUID messageId) {
        return chatService.pinMessage(organiser, conversationId, messageId);
    }

    @Transactional
    public ConversationResponse unpinMessage(User organiser, UUID conversationId) {
        return chatService.unpinMessage(organiser, conversationId);
    }

    public PageResponse<EventBuddyResponse> getEventBuddies(User organiser, Pageable pageable) {
        Page<Event> eventPage = eventRepository.findByOrganiser(organiser, Pageable.unpaged());
        List<Event> organiserEvents = eventPage.getContent();

        if (organiserEvents.isEmpty()) {
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

        Map<UUID, EventBuddyData> buddyDataMap = new HashMap<>();

        for (Event event : organiserEvents) {
            List<Registration> approvedRegs = registrationRepository.findByEventAndStatus(event, RegistrationStatus.APPROVED);

            for (Registration reg : approvedRegs) {
                User attendee = reg.getUser();
                if (attendee.getId().equals(organiser.getId())) {
                    continue;
                }

                EventBuddyData data = buddyDataMap.computeIfAbsent(attendee.getId(),
                    k -> new EventBuddyData(attendee));

                data.addSharedEvent(event);
            }
        }

        List<EventBuddyResponse> buddies = buddyDataMap.values().stream()
                .sorted((a, b) -> Integer.compare(b.getSharedEventsCount(), a.getSharedEventsCount()))
                .map(EventBuddyData::toResponse)
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

    public List<EventBuddyResponse> getEventBuddiesByEvent(User organiser, UUID eventId) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        if (!event.getOrganiser().getId().equals(organiser.getId())) {
            throw new ForbiddenException("You can only view buddies for your own events");
        }

        List<Registration> approvedRegs = registrationRepository.findByEventAndStatus(event, RegistrationStatus.APPROVED);

        return approvedRegs.stream()
                .filter(reg -> !reg.getUser().getId().equals(organiser.getId()))
                .map(reg -> {
                    User attendee = reg.getUser();
                    return EventBuddyResponse.builder()
                            .userId(attendee.getId())
                            .fullName(attendee.getFullName())
                            .avatarUrl(attendee.getAvatarUrl())
                            .sharedEventsCount(1)
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
    public ConversationResponse createGroupChat(User organiser, CreateGroupChatRequest request) {
        if (request.getParticipantIds().size() < 2) {
            throw new BadRequestException("At least 2 participants are required for a group chat");
        }

        Conversation conversation = Conversation.builder()
                .type(ConversationType.GROUP)
                .name(request.getName())
                .imageUrl(request.getImageUrl())
                .build();
        conversation = conversationRepository.save(conversation);

        participantRepository.save(ConversationParticipant.builder()
                .conversation(conversation)
                .user(organiser)
                .build());

        for (UUID userId : request.getParticipantIds()) {
            User participant = userRepository.findById(userId)
                    .orElseThrow(() -> new ResourceNotFoundException("User not found: " + userId));

            participantRepository.save(ConversationParticipant.builder()
                    .conversation(conversation)
                    .user(participant)
                    .build());
        }

        ConversationParticipant currentParticipant = participantRepository
                .findByConversationAndUser(conversation, organiser)
                .orElse(null);

        return ConversationResponse.fromEntity(conversation, currentParticipant);
    }

    public PageResponse<ConversationResponse> getGroupChats(User organiser, Pageable pageable) {
        Page<Conversation> conversations = conversationRepository.findByUserAndType(organiser, ConversationType.GROUP, pageable);

        List<ConversationResponse> responses = conversations.getContent().stream()
                .map(conv -> {
                    ConversationParticipant participant = participantRepository
                            .findByConversationAndUser(conv, organiser)
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

    @Transactional
    public ConversationResponse addParticipants(User organiser, UUID conversationId, List<UUID> userIds) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));

        if (!participantRepository.existsByConversationAndUser(conversation, organiser)) {
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
                .findByConversationAndUser(conversation, organiser)
                .orElse(null);

        return ConversationResponse.fromEntity(conversation, currentParticipant);
    }

    @Transactional
    public void removeParticipant(User organiser, UUID conversationId, UUID userId) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));

        if (!participantRepository.existsByConversationAndUser(conversation, organiser)) {
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

    @Transactional
    public ConversationResponse getOrCreateDirectChat(User organiser, UUID otherUserId) {
        User otherUser = userRepository.findById(otherUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        if (organiser.getId().equals(otherUserId)) {
            throw new BadRequestException("Cannot create chat with yourself");
        }

        Conversation conversation = conversationRepository.findDirectConversation(organiser, otherUser)
                .orElseGet(() -> createDirectChat(organiser, otherUser));

        ConversationParticipant currentParticipant = participantRepository
                .findByConversationAndUser(conversation, organiser)
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

    public PageResponse<ConversationResponse> getConversations(User organiser, Pageable pageable) {
        Page<Conversation> conversations = conversationRepository.findByUser(organiser, pageable);

        List<ConversationResponse> responses = conversations.getContent().stream()
                .map(conv -> {
                    ConversationParticipant participant = participantRepository
                            .findByConversationAndUser(conv, organiser)
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

    private static class EventBuddyData {
        private final User user;
        private final List<Event> sharedEvents = new ArrayList<>();

        EventBuddyData(User user) {
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
                            .max(java.time.LocalDateTime::compareTo)
                            .orElse(null))
                    .build();
        }
    }
}

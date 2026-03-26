package com.luma.service;

import com.luma.dto.request.SendMessageRequest;
import com.luma.dto.response.ConversationResponse;
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

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class ChatService {

    private final ConversationRepository conversationRepository;
    private final ConversationParticipantRepository participantRepository;
    private final MessageRepository messageRepository;
    private final EventRepository eventRepository;
    private final RegistrationRepository registrationRepository;
    private final UserRepository userRepository;
    private final ChatWebSocketService webSocketService;

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

    @Transactional
    public ConversationResponse getOrCreateEventChat(User user, UUID eventId) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        boolean isRegistered = registrationRepository.existsByEventAndUserAndStatus(event, user, RegistrationStatus.APPROVED);
        boolean isOrganiser = event.getOrganiser().getId().equals(user.getId());

        if (!isRegistered && !isOrganiser) {
            throw new ForbiddenException("You must be registered for this event to access the chat");
        }

        Conversation conversation = conversationRepository.findByEventAndType(event, ConversationType.EVENT_GROUP)
                .orElseGet(() -> createEventGroupChat(event));

        if (!participantRepository.existsByConversationAndUser(conversation, user)) {
            ConversationParticipant participant = ConversationParticipant.builder()
                    .conversation(conversation)
                    .user(user)
                    .build();
            participantRepository.save(participant);
        }

        ConversationParticipant currentParticipant = participantRepository
                .findByConversationAndUser(conversation, user)
                .orElse(null);

        return ConversationResponse.fromEntity(conversation, currentParticipant);
    }

    private Conversation createEventGroupChat(Event event) {
        Conversation conversation = Conversation.builder()
                .type(ConversationType.EVENT_GROUP)
                .name(event.getTitle())
                .imageUrl(event.getImageUrl())
                .event(event)
                .build();
        return conversationRepository.save(conversation);
    }

    @Transactional
    public ConversationResponse getOrCreateDirectChat(User currentUser, UUID otherUserId) {
        User otherUser = userRepository.findById(otherUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        if (currentUser.getId().equals(otherUserId)) {
            throw new BadRequestException("Cannot create chat with yourself");
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

        List<MessageResponse> responses = messages.getContent().stream()
                .map(MessageResponse::fromEntity)
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

        if (!participantRepository.existsByConversationAndUser(conversation, user)) {
            throw new ForbiddenException("You are not a participant of this conversation");
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

        webSocketService.broadcastNewMessage(conversation, response);

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

    public long getUnreadCount(User user) {
        return participantRepository.getTotalUnreadCount(user);
    }

    @Transactional
    public void deleteMessage(User user, UUID messageId) {
        Message message = messageRepository.findById(messageId)
                .orElseThrow(() -> new ResourceNotFoundException("Message not found"));

        if (!message.getSender().getId().equals(user.getId())) {
            throw new ForbiddenException("You can only delete your own messages");
        }

        UUID conversationId = message.getConversation().getId();

        message.setDeleted(true);
        message.setContent("This message was deleted");
        message.setMediaUrl(null);
        messageRepository.save(message);

        webSocketService.broadcastMessageDeleted(conversationId, messageId);
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
}

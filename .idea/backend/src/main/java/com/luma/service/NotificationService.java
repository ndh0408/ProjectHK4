package com.luma.service;

import com.luma.dto.response.NotificationResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.Event;
import com.luma.entity.Notification;
import com.luma.entity.Question;
import com.luma.entity.Registration;
import com.luma.entity.User;
import com.luma.entity.enums.NotificationType;
import com.luma.entity.enums.UserRole;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.FollowRepository;
import com.luma.repository.NotificationRepository;
import com.luma.repository.RegistrationRepository;
import com.luma.repository.UserRepository;
import com.luma.entity.enums.RegistrationStatus;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final UserRepository userRepository;
    private final RegistrationRepository registrationRepository;
    private final FollowRepository followRepository;
    private final WebSocketNotificationService webSocketNotificationService;
    private final EmailService emailService;

    @Transactional(readOnly = true)
    public PageResponse<NotificationResponse> getUserNotifications(User user, Pageable pageable) {
        Page<Notification> notifications = notificationRepository.findByUserOrderByCreatedAtDesc(user, pageable);
        return PageResponse.from(notifications, NotificationResponse::fromEntity);
    }

    @Transactional(readOnly = true)
    public PageResponse<NotificationResponse> getUnreadNotifications(User user, Pageable pageable) {
        Page<Notification> notifications = notificationRepository.findByUserAndIsReadOrderByCreatedAtDesc(user, false, pageable);
        return PageResponse.from(notifications, NotificationResponse::fromEntity);
    }

    @Transactional(readOnly = true)
    public long getUnreadCount(User user) {
        return notificationRepository.countByUserAndIsRead(user, false);
    }

    @Transactional
    public void markAsRead(UUID notificationId) {
        notificationRepository.markAsRead(notificationId);
    }

    @Transactional
    public void markAllAsRead(User user) {
        notificationRepository.markAllAsRead(user);
    }

    @Transactional
    public Notification sendNotification(User user, String title, String message, NotificationType type, UUID referenceId, String referenceType) {
        return sendNotification(user, title, message, type, referenceId, referenceType, null, null);
    }

    @Transactional
    public Notification sendNotification(User user, String title, String message, NotificationType type,
                                         UUID referenceId, String referenceType, User sender) {
        return sendNotification(user, title, message, type, referenceId, referenceType,
                               sender != null ? sender.getId() : null,
                               sender != null ? sender.getFullName() : null);
    }

    @Transactional
    public Notification sendNotification(User user, String title, String message, NotificationType type,
                                         UUID referenceId, String referenceType, UUID senderId, String senderName) {
        Notification notification = Notification.builder()
                .user(user)
                .title(title)
                .message(message)
                .type(type)
                .referenceId(referenceId)
                .referenceType(referenceType)
                .senderId(senderId)
                .senderName(senderName)
                .build();

        notification = notificationRepository.save(notification);

        webSocketNotificationService.sendToUser(user.getId(), notification);

        return notification;
    }

    @Transactional
    public void sendRegistrationApprovedNotification(Registration registration) {
        User user = registration.getUser();
        Event event = registration.getEvent();
        User organiser = event.getOrganiser();

        sendNotification(
                user,
                "Registration Approved",
                "Your registration for event \"" + event.getTitle() + "\" has been approved.",
                NotificationType.REGISTRATION_APPROVED,
                event.getId(),
                "EVENT"
        );

        emailService.sendRegistrationApprovedEmail(
                user.getEmail(),
                user.getFullName(),
                user.isEmailVerified(),
                user.isEmailNotificationsEnabled(),
                event.getTitle(),
                event.getStartTime(),
                event.getEndTime(),
                event.getVenue(),
                event.getId(),
                organiser.getFullName()
        );
    }

    @Transactional
    public void sendPromotedFromWaitingListNotification(Registration registration) {
        sendNotification(
                registration.getUser(),
                "You're In!",
                "Great news! A spot opened up and you've been moved from the waiting list. " +
                        "Your registration for \"" + registration.getEvent().getTitle() + "\" is now approved!",
                NotificationType.REGISTRATION_APPROVED,
                registration.getEvent().getId(),
                "EVENT"
        );
    }

    @Transactional
    public void sendRegistrationRejectedNotification(Registration registration) {
        User user = registration.getUser();
        Event event = registration.getEvent();
        String rejectionReason = registration.getRejectionReason();

        String message = "Your registration for event \"" + event.getTitle() + "\" has been rejected.";
        if (rejectionReason != null) {
            message += " Reason: " + rejectionReason;
        }

        sendNotification(
                user,
                "Registration Rejected",
                message,
                NotificationType.REGISTRATION_REJECTED,
                event.getId(),
                "EVENT"
        );

        emailService.sendRegistrationRejectedEmail(
                user.getEmail(),
                user.getFullName(),
                user.isEmailVerified(),
                user.isEmailNotificationsEnabled(),
                event.getTitle(),
                rejectionReason
        );
    }

    @Transactional
    public void sendQuestionAnsweredNotification(Question question) {
        String message = "Your question about event \"" + question.getEvent().getTitle() + "\" has been answered.\n\n" +
                "Q: " + question.getQuestion() + "\n" +
                "A: " + question.getAnswer();
        sendNotification(
                question.getUser(),
                "Question Answered",
                message,
                NotificationType.QUESTION_ANSWERED,
                question.getEvent().getId(),
                "EVENT"
        );
    }

    @Transactional
    public void notifyAdminsEventCreated(Event event) {
        List<User> admins = userRepository.findAllByRole(UserRole.ADMIN);
        String title = "New Event Pending Review";
        String message = "Organiser \"" + event.getOrganiser().getFullName() + "\" created a new event: \"" + event.getTitle() + "\". Please review.";

        List<Notification> notifications = new ArrayList<>(admins.size());
        for (User admin : admins) {
            notifications.add(Notification.builder()
                    .user(admin)
                    .title(title)
                    .message(message)
                    .type(NotificationType.EVENT_CREATED)
                    .referenceId(event.getId())
                    .referenceType("EVENT")
                    .build());
        }
        notificationRepository.saveAll(notifications);
        for (Notification notification : notifications) {
            webSocketNotificationService.sendToUser(notification.getUser().getId(), notification);
        }
    }

    @Transactional
    public void notifyOrganiserEventApproved(Event event) {
        User organiser = event.getOrganiser();

        sendNotification(
                organiser,
                "Event Approved",
                "Your event \"" + event.getTitle() + "\" has been approved and is now published.",
                NotificationType.EVENT_APPROVED,
                event.getId(),
                "EVENT"
        );

        emailService.sendEventApprovedEmail(
                organiser.getEmail(),
                organiser.getFullName(),
                organiser.isEmailVerified(),
                organiser.isEmailNotificationsEnabled(),
                event.getTitle(),
                event.getStartTime(),
                event.getId()
        );
    }

    @Transactional
    public void notifyOrganiserEventRejected(Event event, String reason) {
        User organiser = event.getOrganiser();

        String message = "Your event \"" + event.getTitle() + "\" has been rejected.";
        if (reason != null && !reason.isEmpty()) {
            message += " Reason: " + reason;
        }

        sendNotification(
                organiser,
                "Event Rejected",
                message,
                NotificationType.EVENT_REJECTED,
                event.getId(),
                "EVENT"
        );

        emailService.sendEventRejectedEmail(
                organiser.getEmail(),
                organiser.getFullName(),
                organiser.isEmailVerified(),
                organiser.isEmailNotificationsEnabled(),
                event.getTitle(),
                reason,
                event.getId()
        );
    }

    @Transactional
    public void notifyAdminEventResubmitted(Event event) {
        List<User> admins = userRepository.findAllByRole(UserRole.ADMIN);
        String title = "Event Resubmitted";
        String message = "\"" + event.getTitle() + "\" by " + event.getOrganiser().getFullName() + " has been edited and resubmitted for approval.";

        List<Notification> notifications = new ArrayList<>(admins.size());
        for (User admin : admins) {
            notifications.add(Notification.builder()
                    .user(admin)
                    .title(title)
                    .message(message)
                    .type(NotificationType.EVENT_CREATED)
                    .referenceId(event.getId())
                    .referenceType("EVENT")
                    .build());
        }
        notificationRepository.saveAll(notifications);
        for (Notification notification : notifications) {
            webSocketNotificationService.sendToUser(notification.getUser().getId(), notification);
        }
    }

    @Transactional
    public int notifyAttendeesEventCancelled(Event event, String reason) {
        List<Registration> registrations = registrationRepository.findByEventAndStatusIn(
                event,
                List.of(RegistrationStatus.APPROVED, RegistrationStatus.PENDING, RegistrationStatus.WAITING_LIST)
        );

        String title = "Event Cancelled";
        String message = "The event \"" + event.getTitle() + "\" has been cancelled by the organiser.";
        if (reason != null && !reason.trim().isEmpty()) {
            message += " Reason: " + reason;
        }

        List<Notification> notifications = new ArrayList<>(registrations.size());
        for (Registration registration : registrations) {
            notifications.add(Notification.builder()
                    .user(registration.getUser())
                    .title(title)
                    .message(message)
                    .type(NotificationType.EVENT_UPDATE)
                    .referenceId(event.getId())
                    .referenceType("EVENT")
                    .senderId(event.getOrganiser().getId())
                    .senderName(event.getOrganiser().getFullName())
                    .build());
        }
        notificationRepository.saveAll(notifications);

        for (int i = 0; i < registrations.size(); i++) {
            User attendee = registrations.get(i).getUser();
            webSocketNotificationService.sendToUser(attendee.getId(), notifications.get(i));

            emailService.sendEventCancelledEmail(
                    attendee.getEmail(),
                    attendee.getFullName(),
                    attendee.isEmailVerified(),
                    attendee.isEmailNotificationsEnabled(),
                    event.getTitle(),
                    event.getStartTime(),
                    reason
            );
        }

        return registrations.size();
    }

    @Transactional
    public void notifyOrganiserNewRegistration(Registration registration) {
        Event event = registration.getEvent();
        User organiser = event.getOrganiser();
        User registrant = registration.getUser();
        String userName = registrant.getFullName();
        String eventTitle = event.getTitle();

        sendNotification(
                organiser,
                "New Registration",
                userName + " has registered for your event \"" + eventTitle + "\".",
                NotificationType.NEW_REGISTRATION,
                event.getId(),
                "EVENT",
                registrant
        );

        emailService.sendNewRegistrationEmail(
                organiser.getEmail(),
                organiser.getFullName(),
                organiser.isEmailVerified(),
                organiser.isEmailNotificationsEnabled(),
                registrant.getFullName(),
                registrant.getEmail(),
                eventTitle,
                event.getId()
        );
    }

    @Transactional
    public void notifyOrganiserNewQuestion(Question question) {
        User organiser = question.getEvent().getOrganiser();
        User sender = question.getUser();

        sendNotification(
                organiser,
                "New Question",
                question.getQuestion(),
                NotificationType.NEW_QUESTION,
                question.getEvent().getId(),
                "EVENT",
                sender
        );
    }

    @Transactional
    public void notifyOrganiserRegistrationCancelled(Registration registration) {
        User organiser = registration.getEvent().getOrganiser();
        User registrant = registration.getUser();
        String userName = registrant.getFullName();
        String eventTitle = registration.getEvent().getTitle();

        sendNotification(
                organiser,
                "Registration Cancelled",
                userName + " has cancelled their registration for your event \"" + eventTitle + "\".",
                NotificationType.REGISTRATION_CANCELLED,
                registration.getEvent().getId(),
                "EVENT",
                registrant
        );
    }

    @Transactional
    public Notification sendReplyToUser(User sender, UUID recipientId, String message, UUID eventId) {
        User recipient = userRepository.findById(recipientId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        return sendNotification(
                recipient,
                "Reply from " + sender.getFullName(),
                message,
                NotificationType.REPLY_MESSAGE,
                eventId,
                "EVENT",
                sender.getId(),
                sender.getFullName()
        );
    }

    @Transactional
    public void broadcastNotification(String title, String message) {
        List<User> users = userRepository.findAll();
        List<Notification> notifications = new ArrayList<>(users.size());
        for (User user : users) {
            notifications.add(Notification.builder()
                    .user(user)
                    .title(title)
                    .message(message)
                    .type(NotificationType.BROADCAST)
                    .build());
        }
        notificationRepository.saveAll(notifications);
        for (Notification notification : notifications) {
            webSocketNotificationService.sendToUser(notification.getUser().getId(), notification);
        }
    }

    @Transactional
    public void sendNotificationToRole(String title, String message, UserRole role) {
        List<User> users = userRepository.findAllByRole(role);
        List<Notification> notifications = new ArrayList<>(users.size());
        for (User user : users) {
            notifications.add(Notification.builder()
                    .user(user)
                    .title(title)
                    .message(message)
                    .type(NotificationType.BROADCAST)
                    .build());
        }
        notificationRepository.saveAll(notifications);
        for (Notification notification : notifications) {
            webSocketNotificationService.sendToUser(notification.getUser().getId(), notification);
        }
    }

    @Transactional
    public int sendNotificationToEventAttendees(Event event, User sender, String title, String message) {
        List<Registration> registrations = registrationRepository.findByEventAndStatus(event, RegistrationStatus.APPROVED);
        List<Notification> notifications = new ArrayList<>(registrations.size());
        for (Registration registration : registrations) {
            notifications.add(Notification.builder()
                    .user(registration.getUser())
                    .title(title)
                    .message(message)
                    .type(NotificationType.EVENT_UPDATE)
                    .referenceId(event.getId())
                    .referenceType("EVENT")
                    .senderId(sender.getId())
                    .senderName(sender.getFullName())
                    .build());
        }
        notificationRepository.saveAll(notifications);
        for (Notification notification : notifications) {
            webSocketNotificationService.sendToUser(notification.getUser().getId(), notification);
        }
        return notifications.size();
    }

    @Transactional
    public int sendNotificationByType(Event event, User sender, String title, String message, String notificationType) {
        java.util.Set<UUID> notifiedUserIds = new java.util.HashSet<>();
        List<Notification> notifications = new ArrayList<>();

        List<User> recipients = new ArrayList<>();

        switch (notificationType) {
            case "EVENT_REMINDER":
            case "THANK_YOU":
                List<Registration> approvedRegs = registrationRepository.findByEventAndStatus(event, RegistrationStatus.APPROVED);
                for (Registration reg : approvedRegs) {
                    if (notifiedUserIds.add(reg.getUser().getId())) {
                        recipients.add(reg.getUser());
                    }
                }
                break;

            case "EVENT_UPDATE":
                List<Registration> updateRegs = registrationRepository.findByEventAndStatusIn(event,
                        List.of(RegistrationStatus.APPROVED, RegistrationStatus.PENDING));
                for (Registration reg : updateRegs) {
                    if (notifiedUserIds.add(reg.getUser().getId())) {
                        recipients.add(reg.getUser());
                    }
                }
                break;

            case "ANNOUNCEMENT":
                List<Registration> announcementRegs = registrationRepository.findByEventAndStatusIn(event,
                        List.of(RegistrationStatus.APPROVED, RegistrationStatus.PENDING));
                for (Registration reg : announcementRegs) {
                    if (notifiedUserIds.add(reg.getUser().getId())) {
                        recipients.add(reg.getUser());
                    }
                }
                List<com.luma.entity.Follow> followers = followRepository.findAllByOrganiserUser(sender);
                for (com.luma.entity.Follow follow : followers) {
                    if (notifiedUserIds.add(follow.getFollower().getId())) {
                        recipients.add(follow.getFollower());
                    }
                }
                break;

            case "FEEDBACK_REQUEST":
                List<Registration> checkedInRegs = registrationRepository.findCheckedInByEvent(event);
                for (Registration reg : checkedInRegs) {
                    if (notifiedUserIds.add(reg.getUser().getId())) {
                        recipients.add(reg.getUser());
                    }
                }
                break;

            default:
                List<Registration> defaultRegs = registrationRepository.findByEventAndStatus(event, RegistrationStatus.APPROVED);
                for (Registration reg : defaultRegs) {
                    if (notifiedUserIds.add(reg.getUser().getId())) {
                        recipients.add(reg.getUser());
                    }
                }
        }

        for (User recipient : recipients) {
            notifications.add(Notification.builder()
                    .user(recipient)
                    .title(title)
                    .message(message)
                    .type(NotificationType.EVENT_UPDATE)
                    .referenceId(event.getId())
                    .referenceType("EVENT")
                    .senderId(sender.getId())
                    .senderName(sender.getFullName())
                    .build());
        }
        notificationRepository.saveAll(notifications);
        for (Notification notification : notifications) {
            webSocketNotificationService.sendToUser(notification.getUser().getId(), notification);
        }

        return notifications.size();
    }

    @Transactional(readOnly = true)
    public long getRecipientCountByType(Event event, User organiser, String notificationType) {
        java.util.Set<UUID> userIds = new java.util.HashSet<>();

        switch (notificationType) {
            case "EVENT_REMINDER":
            case "THANK_YOU":
                return registrationRepository.countByEventAndStatus(event, RegistrationStatus.APPROVED);

            case "EVENT_UPDATE":
                return registrationRepository.countByEventAndStatusIn(event,
                        List.of(RegistrationStatus.APPROVED, RegistrationStatus.PENDING));

            case "ANNOUNCEMENT":
                List<Registration> regs = registrationRepository.findByEventAndStatusIn(event,
                        List.of(RegistrationStatus.APPROVED, RegistrationStatus.PENDING));
                for (Registration reg : regs) {
                    userIds.add(reg.getUser().getId());
                }
                List<com.luma.entity.Follow> followers = followRepository.findAllByOrganiserUser(organiser);
                for (com.luma.entity.Follow follow : followers) {
                    userIds.add(follow.getFollower().getId());
                }
                return userIds.size();

            case "FEEDBACK_REQUEST":
                return registrationRepository.countCheckedInByEvent(event);

            default:
                return registrationRepository.countByEventAndStatus(event, RegistrationStatus.APPROVED);
        }
    }

    @Transactional
    public void sendWaitlistOfferNotification(com.luma.entity.WaitlistOffer offer) {
        long minutes = offer.getRemainingMinutes();
        sendNotification(
                offer.getUser(),
                "A Spot Opened Up!",
                "Great news! A spot is available for \"" + offer.getEvent().getTitle() +
                        "\". You have " + minutes + " minutes to accept. Act fast before it expires!",
                NotificationType.WAITLIST_OFFER,
                offer.getEvent().getId(),
                "EVENT"
        );
    }

    @Transactional
    public void sendWaitlistOfferExpiredNotification(com.luma.entity.WaitlistOffer offer) {
        sendNotification(
                offer.getUser(),
                "Waitlist Offer Expired",
                "Your waitlist offer for \"" + offer.getEvent().getTitle() +
                        "\" has expired. You have been moved back in the queue.",
                NotificationType.WAITLIST_OFFER_EXPIRED,
                offer.getEvent().getId(),
                "EVENT"
        );
    }
}

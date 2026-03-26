package com.luma.service;

import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.thymeleaf.TemplateEngine;
import org.thymeleaf.context.Context;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmailService {

    private final JavaMailSender mailSender;
    private final TemplateEngine templateEngine;

    @Value("${spring.mail.username}")
    private String fromEmail;

    @Value("${app.base-url}")
    private String baseUrl;

    private static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ofPattern("EEEE, MMMM d, yyyy");
    private static final DateTimeFormatter TIME_FORMATTER = DateTimeFormatter.ofPattern("h:mm a");

    @Async
    public void sendRegistrationApprovedEmail(String userEmail, String userName, boolean emailVerified,
                                               boolean emailNotificationsEnabled, String eventTitle,
                                               LocalDateTime startTime, LocalDateTime endTime,
                                               String venue, UUID eventId, String organiserName) {
        if (!canSendEmail(userEmail, emailVerified, emailNotificationsEnabled)) {
            return;
        }

        Context context = new Context();
        context.setVariable("userName", userName != null ? userName : "there");
        context.setVariable("eventTitle", eventTitle);
        context.setVariable("eventDate", startTime.format(DATE_FORMATTER));
        context.setVariable("eventTime", startTime.format(TIME_FORMATTER) + " - " + endTime.format(TIME_FORMATTER));
        context.setVariable("eventLocation", venue != null ? venue : "TBA");
        context.setVariable("eventUrl", baseUrl + "/event/" + eventId);
        context.setVariable("organiserName", organiserName);

        sendHtmlEmail(
                userEmail,
                "Registration Approved - " + eventTitle,
                "email/registration-approved",
                context
        );
    }

    @Async
    public void sendRegistrationRejectedEmail(String userEmail, String userName, boolean emailVerified,
                                               boolean emailNotificationsEnabled, String eventTitle,
                                               String rejectionReason) {
        if (!canSendEmail(userEmail, emailVerified, emailNotificationsEnabled)) {
            return;
        }

        Context context = new Context();
        context.setVariable("userName", userName != null ? userName : "there");
        context.setVariable("eventTitle", eventTitle);
        context.setVariable("rejectionReason", rejectionReason);

        sendHtmlEmail(
                userEmail,
                "Registration Update - " + eventTitle,
                "email/registration-rejected",
                context
        );
    }

    @Async
    public void sendEventReminderEmail(String userEmail, String userName, boolean emailVerified,
                                        boolean emailNotificationsEnabled, boolean emailEventReminders,
                                        String eventTitle, LocalDateTime startTime, String venue,
                                        String address, UUID eventId, String organiserName) {
        if (!canSendReminderEmail(userEmail, emailVerified, emailNotificationsEnabled, emailEventReminders)) {
            return;
        }

        Context context = new Context();
        context.setVariable("userName", userName != null ? userName : "there");
        context.setVariable("eventTitle", eventTitle);
        context.setVariable("eventDate", startTime.format(DATE_FORMATTER));
        context.setVariable("eventTime", startTime.format(TIME_FORMATTER));
        context.setVariable("eventLocation", venue != null ? venue : "TBA");
        context.setVariable("eventAddress", address);
        context.setVariable("eventUrl", baseUrl + "/event/" + eventId);
        context.setVariable("organiserName", organiserName);

        sendHtmlEmail(
                userEmail,
                "Reminder: " + eventTitle + " is tomorrow!",
                "email/event-reminder",
                context
        );
    }

    @Async
    public void sendEventApprovedEmail(String organiserEmail, String organiserName, boolean emailVerified,
                                        boolean emailNotificationsEnabled, String eventTitle,
                                        LocalDateTime startTime, UUID eventId) {
        if (!canSendEmail(organiserEmail, emailVerified, emailNotificationsEnabled)) {
            return;
        }

        Context context = new Context();
        context.setVariable("organiserName", organiserName != null ? organiserName : "there");
        context.setVariable("eventTitle", eventTitle);
        context.setVariable("eventDate", startTime.format(DATE_FORMATTER));
        context.setVariable("eventUrl", baseUrl + "/event/" + eventId);

        sendHtmlEmail(
                organiserEmail,
                "Your event has been approved - " + eventTitle,
                "email/event-approved",
                context
        );
    }

    @Async
    public void sendEventRejectedEmail(String organiserEmail, String organiserName, boolean emailVerified,
                                        boolean emailNotificationsEnabled, String eventTitle,
                                        String reason, UUID eventId) {
        if (!canSendEmail(organiserEmail, emailVerified, emailNotificationsEnabled)) {
            return;
        }

        Context context = new Context();
        context.setVariable("organiserName", organiserName != null ? organiserName : "there");
        context.setVariable("eventTitle", eventTitle);
        context.setVariable("rejectionReason", reason);
        context.setVariable("editUrl", baseUrl + "/edit-event/" + eventId);

        sendHtmlEmail(
                organiserEmail,
                "Event Review Update - " + eventTitle,
                "email/event-rejected",
                context
        );
    }

    @Async
    public void sendNewRegistrationEmail(String organiserEmail, String organiserName, boolean emailVerified,
                                          boolean emailNotificationsEnabled, String registrantName,
                                          String registrantEmail, String eventTitle, UUID eventId) {
        if (!canSendEmail(organiserEmail, emailVerified, emailNotificationsEnabled)) {
            return;
        }

        Context context = new Context();
        context.setVariable("organiserName", organiserName != null ? organiserName : "there");
        context.setVariable("registrantName", registrantName != null ? registrantName : "Someone");
        context.setVariable("registrantEmail", registrantEmail);
        context.setVariable("eventTitle", eventTitle);
        context.setVariable("registrationsUrl", baseUrl + "/event-registrations/" + eventId);

        sendHtmlEmail(
                organiserEmail,
                "New Registration - " + eventTitle,
                "email/new-registration",
                context
        );
    }

    @Async
    public void sendWelcomeEmail(String userEmail, String userName) {
        if (userEmail == null) {
            return;
        }

        Context context = new Context();
        context.setVariable("userName", userName != null ? userName : "there");
        context.setVariable("exploreUrl", baseUrl + "/explore");

        sendHtmlEmail(
                userEmail,
                "Welcome to LUMA!",
                "email/welcome",
                context
        );
    }

    @Async
    public void sendEventCancelledEmail(String userEmail, String userName, boolean emailVerified,
                                         boolean emailNotificationsEnabled, String eventTitle,
                                         LocalDateTime startTime, String reason) {
        if (!canSendEmail(userEmail, emailVerified, emailNotificationsEnabled)) {
            return;
        }

        Context context = new Context();
        context.setVariable("userName", userName != null ? userName : "there");
        context.setVariable("eventTitle", eventTitle);
        context.setVariable("eventDate", startTime.format(DATE_FORMATTER));
        context.setVariable("eventTime", startTime.format(TIME_FORMATTER));
        context.setVariable("cancellationReason", reason);
        context.setVariable("exploreUrl", baseUrl + "/explore");

        sendHtmlEmail(
                userEmail,
                "Event Cancelled - " + eventTitle,
                "email/event-cancelled",
                context
        );
    }

    private boolean canSendEmail(String email, boolean emailVerified, boolean emailNotificationsEnabled) {
        if (email == null || email.isEmpty()) {
            return false;
        }
        if (!emailVerified) {
            return false;
        }
        if (!emailNotificationsEnabled) {
            return false;
        }
        return true;
    }

    private boolean canSendReminderEmail(String email, boolean emailVerified,
                                          boolean emailNotificationsEnabled, boolean emailEventReminders) {
        if (!canSendEmail(email, emailVerified, emailNotificationsEnabled)) {
            return false;
        }
        if (!emailEventReminders) {
            return false;
        }
        return true;
    }

    private void sendHtmlEmail(String to, String subject, String templateName, Context context) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");

            helper.setFrom(fromEmail, "LUMA Events");
            helper.setTo(to);
            helper.setSubject(subject);

            String htmlContent = templateEngine.process(templateName, context);
            helper.setText(htmlContent, true);

            mailSender.send(message);
            log.info("Email sent to {} with subject: {}", to, subject);
        } catch (MessagingException e) {
            log.error("Failed to send email to {}: {}", to, e.getMessage());
        } catch (Exception e) {
            log.error("Unexpected error sending email to {}: {}", to, e.getMessage());
        }
    }
}

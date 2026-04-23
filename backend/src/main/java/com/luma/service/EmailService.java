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

    /**
     * OTP intentionally bypasses {@link #canSendEmail} — the user is not
     * verified yet, which is exactly why we are sending this mail.
     */
    @Async
    public void sendOtpEmail(String userEmail, String userName, String otp, int expiryMinutes) {
        if (userEmail == null || userEmail.isEmpty()) {
            log.warn("Cannot send OTP email: recipient email is null or empty");
            return;
        }

        Context context = new Context();
        context.setVariable("userName", userName != null && !userName.isEmpty() ? userName : "there");
        context.setVariable("otp", otp);
        context.setVariable("expiryMinutes", expiryMinutes);

        sendHtmlEmail(
                userEmail,
                "Your LUMA verification code: " + otp,
                "email/otp-verification",
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

    @Async
    public void sendCertificateEmail(String userEmail, String userName, String eventTitle,
                                      LocalDateTime eventDate, String organiserName, String eventLocation,
                                      String certificateCode, String certificateUrl) {
        if (userEmail == null || userEmail.isEmpty()) {
            log.warn("Cannot send certificate email: user email is null or empty");
            return;
        }

        Context context = new Context();
        context.setVariable("userName", userName != null ? userName : "there");
        context.setVariable("eventTitle", eventTitle);
        context.setVariable("eventDate", eventDate.format(DATE_FORMATTER));
        context.setVariable("organiserName", organiserName);
        context.setVariable("eventLocation", eventLocation != null ? eventLocation : "N/A");
        context.setVariable("certificateCode", certificateCode);
        context.setVariable("downloadUrl", certificateUrl);
        context.setVariable("verifyUrl", baseUrl + "/verify-certificate?code=" + certificateCode);

        sendHtmlEmail(
                userEmail,
                "🏆 Your Certificate of Attendance - " + eventTitle,
                "email/certificate",
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

    @Async
    public void sendOrganiserApplicationApprovedEmail(String userEmail, String userName, String organisationName) {
        if (userEmail == null || userEmail.isEmpty()) {
            return;
        }
        String who = userName != null && !userName.isEmpty() ? userName : "there";
        String org = organisationName != null && !organisationName.isEmpty() ? organisationName : "your organisation";
        String html = ""
                + "<div style=\"font-family: Inter, -apple-system, Segoe UI, sans-serif; max-width: 560px; margin: 0 auto; padding: 24px;\">"
                + "<h2 style=\"color: #1D4ED8;\">Welcome to LUMA, " + escape(who) + "!</h2>"
                + "<p>Your application to become an organiser has been approved.</p>"
                + "<p><strong>" + escape(org) + "</strong> can now publish events, sell tickets and manage attendees on LUMA.</p>"
                + "<div style=\"background: #f3f4f6; border-radius: 8px; padding: 14px 16px; margin: 16px 0;\">"
                + "<p style=\"margin: 0; font-weight: 600;\">About the Verified badge</p>"
                + "<p style=\"margin: 6px 0 0 0; color: #374151;\">Your account does not yet have the blue Verified badge. This tier is reserved for established brands with a business licence, an active public presence and a track record of events. You can apply later from your organiser profile.</p>"
                + "</div>"
                + "<p><a href=\"" + baseUrl + "/login\" style=\"display: inline-block; padding: 12px 20px; background: #1D4ED8; color: white; text-decoration: none; border-radius: 8px;\">Sign in to your organiser dashboard</a></p>"
                + "<p style=\"color: #6b7280; font-size: 13px; margin-top: 32px;\">— The LUMA team</p>"
                + "</div>";
        sendInlineHtml(userEmail, "Your LUMA organiser application has been approved", html);
    }

    @Async
    public void sendOrganiserApplicationApprovedWithBadgeEmail(String userEmail, String userName, String organisationName) {
        if (userEmail == null || userEmail.isEmpty()) {
            return;
        }
        String who = userName != null && !userName.isEmpty() ? userName : "there";
        String org = organisationName != null && !organisationName.isEmpty() ? organisationName : "your organisation";
        String html = ""
                + "<div style=\"font-family: Inter, -apple-system, Segoe UI, sans-serif; max-width: 560px; margin: 0 auto; padding: 24px;\">"
                + "<h2 style=\"color: #059669;\">Welcome to LUMA, " + escape(who) + "!</h2>"
                + "<p>Your application has been approved AND your organisation is now <strong>Verified</strong>.</p>"
                + "<div style=\"background: #ecfdf5; border-left: 3px solid #059669; padding: 12px 16px; border-radius: 6px; margin: 16px 0;\">"
                + "<p style=\"margin: 0; font-weight: 600;\">&#10003; Verified badge granted</p>"
                + "<p style=\"margin: 6px 0 0 0;\"><strong>" + escape(org) + "</strong> will display a blue Verified tick across LUMA — a signal of trust to attendees.</p>"
                + "</div>"
                + "<p><a href=\"" + baseUrl + "/login\" style=\"display: inline-block; padding: 12px 20px; background: #1D4ED8; color: white; text-decoration: none; border-radius: 8px;\">Sign in to your dashboard</a></p>"
                + "<p style=\"color: #6b7280; font-size: 13px; margin-top: 32px;\">— The LUMA team</p>"
                + "</div>";
        sendInlineHtml(userEmail, "Welcome to LUMA — you're verified!", html);
    }

    @Async
    public void sendOrganiserBadgeNotGrantedEmail(String userEmail, String userName) {
        if (userEmail == null || userEmail.isEmpty()) {
            return;
        }
        String who = userName != null && !userName.isEmpty() ? userName : "there";
        String html = ""
                + "<div style=\"font-family: Inter, -apple-system, Segoe UI, sans-serif; max-width: 560px; margin: 0 auto; padding: 24px;\">"
                + "<h2 style=\"color: #0369a1;\">Hi " + escape(who) + ",</h2>"
                + "<p>We reviewed your verification submission. Your documents were valid, but we're not granting the Verified badge at this time.</p>"
                + "<div style=\"background: #f3f4f6; border-radius: 8px; padding: 14px 16px; margin: 16px 0;\">"
                + "<p style=\"margin: 0; font-weight: 600;\">What makes a good Verified candidate</p>"
                + "<ul style=\"margin: 8px 0 0 0; padding-left: 20px; color: #374151;\">"
                + "<li>A business licence (not just an individual ID)</li>"
                + "<li>An official website and public contact details</li>"
                + "<li>A history of successfully organised events on LUMA</li>"
                + "<li>Clear, consistent branding</li>"
                + "</ul>"
                + "</div>"
                + "<p>You can keep organising events as usual and re-apply from your profile once the points above are stronger.</p>"
                + "<p><a href=\"" + baseUrl + "/organiser/profile\" style=\"display: inline-block; padding: 12px 20px; background: #1D4ED8; color: white; text-decoration: none; border-radius: 8px;\">Open profile</a></p>"
                + "<p style=\"color: #6b7280; font-size: 13px; margin-top: 32px;\">— The LUMA team</p>"
                + "</div>";
        sendInlineHtml(userEmail, "Update on your LUMA Verified badge request", html);
    }

    @Async
    public void sendOrganiserApplicationRejectedEmail(String userEmail, String userName,
                                                       String organisationName, String reason) {
        if (userEmail == null || userEmail.isEmpty()) {
            return;
        }
        String who = userName != null && !userName.isEmpty() ? userName : "there";
        String org = organisationName != null && !organisationName.isEmpty() ? organisationName : "your organisation";
        String safeReason = escape(reason != null ? reason : "Please review the submission and try again.");
        String html = ""
                + "<div style=\"font-family: Inter, -apple-system, Segoe UI, sans-serif; max-width: 560px; margin: 0 auto; padding: 24px;\">"
                + "<h2 style=\"color: #b45309;\">Hi " + escape(who) + ",</h2>"
                + "<p>Thanks for applying to organise events on LUMA with <strong>" + escape(org) + "</strong>.</p>"
                + "<p>Unfortunately, we were unable to approve your application at this time.</p>"
                + "<div style=\"background: #fef3c7; border-left: 3px solid #f59e0b; padding: 12px 16px; border-radius: 6px; margin: 16px 0;\">"
                + "<p style=\"margin: 0; font-weight: 600;\">Admin feedback</p>"
                + "<p style=\"margin: 6px 0 0 0; white-space: pre-line;\">" + safeReason + "</p>"
                + "</div>"
                + "<p>You are welcome to reapply once the issues above are addressed.</p>"
                + "<p><a href=\"" + baseUrl + "/apply-organiser\" style=\"display: inline-block; padding: 12px 20px; background: #1D4ED8; color: white; text-decoration: none; border-radius: 8px;\">Reapply</a></p>"
                + "<p style=\"color: #6b7280; font-size: 13px; margin-top: 32px;\">— The LUMA team</p>"
                + "</div>";
        sendInlineHtml(userEmail, "Update on your LUMA organiser application", html);
    }

    @Async
    public void sendOrganiserVerifiedEmail(String userEmail, String userName) {
        if (userEmail == null || userEmail.isEmpty()) {
            return;
        }
        String who = userName != null && !userName.isEmpty() ? userName : "there";
        String html = ""
                + "<div style=\"font-family: Inter, -apple-system, Segoe UI, sans-serif; max-width: 560px; margin: 0 auto; padding: 24px;\">"
                + "<h2 style=\"color: #059669;\">You're verified, " + escape(who) + "!</h2>"
                + "<p>Your verification documents have been approved. Your organiser profile now displays a <strong>Verified</strong> badge to attendees.</p>"
                + "<p><a href=\"" + baseUrl + "/organiser/profile\" style=\"display: inline-block; padding: 12px 20px; background: #1D4ED8; color: white; text-decoration: none; border-radius: 8px;\">View your profile</a></p>"
                + "<p style=\"color: #6b7280; font-size: 13px; margin-top: 32px;\">— The LUMA team</p>"
                + "</div>";
        sendInlineHtml(userEmail, "Your LUMA organiser profile is now verified", html);
    }

    @Async
    public void sendOrganiserVerificationRejectedEmail(String userEmail, String userName, String reason) {
        if (userEmail == null || userEmail.isEmpty()) {
            return;
        }
        String who = userName != null && !userName.isEmpty() ? userName : "there";
        String safeReason = escape(reason != null ? reason : "Please review the submission and try again.");
        String html = ""
                + "<div style=\"font-family: Inter, -apple-system, Segoe UI, sans-serif; max-width: 560px; margin: 0 auto; padding: 24px;\">"
                + "<h2 style=\"color: #b45309;\">Hi " + escape(who) + ",</h2>"
                + "<p>Your verification submission could not be approved this time.</p>"
                + "<div style=\"background: #fef3c7; border-left: 3px solid #f59e0b; padding: 12px 16px; border-radius: 6px; margin: 16px 0;\">"
                + "<p style=\"margin: 0; font-weight: 600;\">Admin feedback</p>"
                + "<p style=\"margin: 6px 0 0 0; white-space: pre-line;\">" + safeReason + "</p>"
                + "</div>"
                + "<p>You can submit new documents from your profile page when ready.</p>"
                + "<p><a href=\"" + baseUrl + "/organiser/profile\" style=\"display: inline-block; padding: 12px 20px; background: #1D4ED8; color: white; text-decoration: none; border-radius: 8px;\">Open profile</a></p>"
                + "<p style=\"color: #6b7280; font-size: 13px; margin-top: 32px;\">— The LUMA team</p>"
                + "</div>";
        sendInlineHtml(userEmail, "Update on your LUMA verification request", html);
    }

    private void sendInlineHtml(String to, String subject, String html) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            helper.setFrom(fromEmail, "LUMA Events");
            helper.setTo(to);
            helper.setSubject(subject);
            helper.setText(html, true);
            mailSender.send(message);
            log.info("Email sent to {} with subject: {}", to, subject);
        } catch (MessagingException e) {
            log.error("Failed to send email to {}: {}", to, e.getMessage());
        } catch (Exception e) {
            log.error("Unexpected error sending email to {}: {}", to, e.getMessage());
        }
    }

    private String escape(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;");
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

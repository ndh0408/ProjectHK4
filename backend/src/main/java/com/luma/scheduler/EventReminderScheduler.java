package com.luma.scheduler;

import com.luma.entity.Event;
import com.luma.entity.Registration;
import com.luma.entity.User;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.repository.RegistrationRepository;
import com.luma.service.EmailService;
import jakarta.annotation.PostConstruct;
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
public class EventReminderScheduler {

    private final RegistrationRepository registrationRepository;
    private final EmailService emailService;

    @PostConstruct
    public void onStartup() {
        log.info("Server started - checking for missed event reminders...");
        sendMissedReminders();
    }

    @Scheduled(cron = "0 0 9 * * *")
    public void sendEventReminders() {
        log.info("Starting scheduled event reminder job...");
        sendRemindersForTomorrow();
    }

    @Transactional
    public void sendMissedReminders() {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime tomorrowStart = now.plusDays(1).withHour(0).withMinute(0).withSecond(0).withNano(0);
        LocalDateTime tomorrowEnd = tomorrowStart.plusDays(1);

        log.info("Checking reminders for events starting tomorrow between {} and {}", tomorrowStart, tomorrowEnd);

        // Only send reminders for events starting TOMORROW (not today or past)
        // This ensures we only send reminders 1 day before the event
        List<Registration> missedRegistrations = registrationRepository
                .findByEventStartTimeBetweenAndStatusAndReminderNotSent(tomorrowStart, tomorrowEnd, RegistrationStatus.APPROVED);

        if (missedRegistrations.isEmpty()) {
            log.info("No missed reminders to send");
            return;
        }

        log.info("Found {} missed reminders to send", missedRegistrations.size());

        for (Registration registration : missedRegistrations) {
            sendReminderAndMark(registration);
        }

        log.info("Missed reminders job completed");
    }

    @Transactional
    public void sendRemindersForTomorrow() {
        LocalDateTime tomorrowStart = LocalDateTime.now().plusDays(1).withHour(0).withMinute(0).withSecond(0).withNano(0);
        LocalDateTime tomorrowEnd = tomorrowStart.plusDays(1);

        List<Registration> registrations = registrationRepository
                .findByEventStartTimeBetweenAndStatusAndReminderNotSent(tomorrowStart, tomorrowEnd, RegistrationStatus.APPROVED);

        log.info("Found {} registrations for events tomorrow", registrations.size());

        for (Registration registration : registrations) {
            sendReminderAndMark(registration);
        }

        log.info("Event reminder job completed");
    }

    private void sendReminderAndMark(Registration registration) {
        try {
            User user = registration.getUser();
            Event event = registration.getEvent();
            User organiser = event.getOrganiser();

            log.info("Sending reminder to {} for event '{}' (startTime: {})",
                    user.getEmail(), event.getTitle(), event.getStartTime());
            log.info("User settings - emailVerified: {}, notificationsEnabled: {}, eventReminders: {}",
                    user.isEmailVerified(), user.isEmailNotificationsEnabled(), user.isEmailEventReminders());

            emailService.sendEventReminderEmail(
                    user.getEmail(),
                    user.getFullName(),
                    user.isEmailVerified(),
                    user.isEmailNotificationsEnabled(),
                    user.isEmailEventReminders(),
                    event.getTitle(),
                    event.getStartTime(),
                    event.getVenue(),
                    event.getAddress(),
                    event.getId(),
                    organiser.getFullName()
            );

            registrationRepository.markReminderSent(registration.getId(), LocalDateTime.now());
            log.info("Reminder sent and marked for registration {}", registration.getId());
        } catch (Exception e) {
            log.error("Failed to send reminder for registration {}: {}", registration.getId(), e.getMessage(), e);
        }
    }
}

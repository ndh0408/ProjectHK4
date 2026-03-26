package com.luma.service;

import com.google.api.client.googleapis.auth.oauth2.GoogleAuthorizationCodeTokenRequest;
import com.google.api.client.googleapis.auth.oauth2.GoogleCredential;
import com.google.api.client.googleapis.auth.oauth2.GoogleRefreshTokenRequest;
import com.google.api.client.googleapis.auth.oauth2.GoogleTokenResponse;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import com.google.api.client.util.DateTime;
import com.google.api.services.calendar.Calendar;
import com.google.api.services.calendar.model.*;
import com.luma.dto.request.CalendarSyncRequest;
import com.luma.dto.request.GoogleCalendarAuthRequest;
import com.luma.dto.response.CalendarSyncResponse;
import com.luma.dto.response.GoogleCalendarStatusResponse;
import com.luma.entity.CalendarSync;
import com.luma.entity.Event;
import com.luma.entity.GoogleCalendarToken;
import com.luma.entity.Registration;
import com.luma.entity.User;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.CalendarSyncRepository;
import com.luma.repository.GoogleCalendarTokenRepository;
import com.luma.repository.RegistrationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.IOException;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class GoogleCalendarService {

    private final GoogleCalendarTokenRepository tokenRepository;
    private final CalendarSyncRepository calendarSyncRepository;
    private final RegistrationRepository registrationRepository;

    @Value("${google.calendar.client-id:}")
    private String clientId;

    @Value("${google.calendar.client-secret:}")
    private String clientSecret;

    @Value("${google.calendar.redirect-uri:}")
    private String defaultRedirectUri;

    private static final String APPLICATION_NAME = "LUMA Event Management";
    private static final NetHttpTransport HTTP_TRANSPORT = new NetHttpTransport();
    private static final GsonFactory JSON_FACTORY = GsonFactory.getDefaultInstance();

    /**
     * Generate OAuth2 authorization URL
     */
    public String getAuthorizationUrl(String redirectUri) {
        String effectiveRedirectUri = redirectUri != null ? redirectUri : defaultRedirectUri;
        return "https://accounts.google.com/o/oauth2/v2/auth?" +
                "client_id=" + clientId +
                "&redirect_uri=" + effectiveRedirectUri +
                "&response_type=code" +
                "&scope=https://www.googleapis.com/auth/calendar.events https://www.googleapis.com/auth/userinfo.email" +
                "&access_type=offline" +
                "&prompt=consent";
    }

    /**
     * Exchange authorization code for tokens and save
     */
    @Transactional
    public void connectGoogleCalendar(User user, GoogleCalendarAuthRequest request) {
        try {
            String effectiveRedirectUri = request.getRedirectUri() != null ?
                    request.getRedirectUri() : defaultRedirectUri;

            GoogleTokenResponse tokenResponse = new GoogleAuthorizationCodeTokenRequest(
                    HTTP_TRANSPORT,
                    JSON_FACTORY,
                    "https://oauth2.googleapis.com/token",
                    clientId,
                    clientSecret,
                    request.getCode(),
                    effectiveRedirectUri
            ).execute();

            // Remove existing token if any
            tokenRepository.deleteByUserId(user.getId());

            // Save new token
            GoogleCalendarToken token = GoogleCalendarToken.builder()
                    .user(user)
                    .accessToken(tokenResponse.getAccessToken())
                    .refreshToken(tokenResponse.getRefreshToken())
                    .expiresAt(LocalDateTime.now().plusSeconds(tokenResponse.getExpiresInSeconds()))
                    .scope(tokenResponse.getScope())
                    .isActive(true)
                    .build();

            tokenRepository.save(token);
            log.info("Google Calendar connected for user: {}", user.getEmail());
        } catch (IOException e) {
            log.error("Failed to connect Google Calendar: {}", e.getMessage());
            throw new BadRequestException("Failed to connect Google Calendar: " + e.getMessage());
        }
    }

    /**
     * Disconnect Google Calendar
     */
    @Transactional
    public void disconnectGoogleCalendar(User user) {
        // Delete all synced events from Google Calendar first
        List<CalendarSync> syncs = calendarSyncRepository.findByUserId(user.getId());
        for (CalendarSync sync : syncs) {
            try {
                deleteGoogleEvent(user, sync.getGoogleEventId(), sync.getCalendarId());
            } catch (Exception e) {
                log.warn("Failed to delete Google event: {}", e.getMessage());
            }
        }

        // Delete all sync records
        calendarSyncRepository.deleteAllByUserId(user.getId());

        // Delete token
        tokenRepository.deleteByUserId(user.getId());
        log.info("Google Calendar disconnected for user: {}", user.getEmail());
    }

    /**
     * Get Google Calendar connection status
     */
    public GoogleCalendarStatusResponse getConnectionStatus(User user) {
        return tokenRepository.findByUserIdAndIsActiveTrue(user.getId())
                .map(token -> {
                    int syncedCount = calendarSyncRepository.findByUserIdAndIsSyncedTrue(user.getId()).size();
                    return GoogleCalendarStatusResponse.builder()
                            .connected(true)
                            .connectedAt(token.getCreatedAt())
                            .expiresAt(token.getExpiresAt())
                            .syncedEventsCount(syncedCount)
                            .build();
                })
                .orElse(GoogleCalendarStatusResponse.builder()
                        .connected(false)
                        .syncedEventsCount(0)
                        .build());
    }

    /**
     * Sync a registered event to Google Calendar
     */
    @Transactional
    public CalendarSyncResponse syncEventToCalendar(User user, CalendarSyncRequest request) {
        // Check if already synced
        if (calendarSyncRepository.existsByUserIdAndRegistrationId(user.getId(), request.getRegistrationId())) {
            throw new BadRequestException("Event is already synced to Google Calendar");
        }

        // Get registration
        Registration registration = registrationRepository.findById(request.getRegistrationId())
                .orElseThrow(() -> new ResourceNotFoundException("Registration not found"));

        if (!registration.getUser().getId().equals(user.getId())) {
            throw new BadRequestException("You can only sync your own registrations");
        }

        Event event = registration.getEvent();
        String calendarId = request.getCalendarId() != null ? request.getCalendarId() : "primary";

        // Create Google Calendar event
        String googleEventId = createGoogleEvent(user, event, calendarId);

        // Save sync record
        CalendarSync sync = CalendarSync.builder()
                .user(user)
                .registration(registration)
                .googleEventId(googleEventId)
                .calendarId(calendarId)
                .isSynced(true)
                .lastSyncedAt(LocalDateTime.now())
                .build();

        calendarSyncRepository.save(sync);
        log.info("Event synced to Google Calendar: {} for user: {}", event.getTitle(), user.getEmail());

        return mapToResponse(sync);
    }

    /**
     * Remove event from Google Calendar
     */
    @Transactional
    public void unsyncEventFromCalendar(User user, UUID registrationId) {
        CalendarSync sync = calendarSyncRepository.findByUserIdAndRegistrationId(user.getId(), registrationId)
                .orElseThrow(() -> new ResourceNotFoundException("Calendar sync not found"));

        // Delete from Google Calendar
        deleteGoogleEvent(user, sync.getGoogleEventId(), sync.getCalendarId());

        // Delete sync record
        calendarSyncRepository.delete(sync);
        log.info("Event unsynced from Google Calendar for user: {}", user.getEmail());
    }

    /**
     * Get all synced events for user
     */
    public List<CalendarSyncResponse> getSyncedEvents(User user) {
        return calendarSyncRepository.findByUserId(user.getId()).stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    /**
     * Sync all registered events to Google Calendar
     */
    @Transactional
    public int syncAllEventsToCalendar(User user) {
        List<Registration> registrations = registrationRepository.findByUserIdAndStatusIn(
                user.getId(),
                Arrays.asList(
                        com.luma.entity.enums.RegistrationStatus.APPROVED
                )
        );

        int syncedCount = 0;
        for (Registration registration : registrations) {
            if (!calendarSyncRepository.existsByUserIdAndRegistrationId(user.getId(), registration.getId())) {
                try {
                    CalendarSyncRequest request = CalendarSyncRequest.builder()
                            .registrationId(registration.getId())
                            .build();
                    syncEventToCalendar(user, request);
                    syncedCount++;
                } catch (Exception e) {
                    log.warn("Failed to sync event {}: {}", registration.getEvent().getTitle(), e.getMessage());
                }
            }
        }

        return syncedCount;
    }

    /**
     * Update synced event when event details change
     */
    @Transactional
    public void updateSyncedEvent(UUID eventId) {
        List<CalendarSync> syncs = calendarSyncRepository.findByEventId(eventId);
        for (CalendarSync sync : syncs) {
            try {
                Event event = sync.getRegistration().getEvent();
                updateGoogleEvent(sync.getUser(), event, sync.getGoogleEventId(), sync.getCalendarId());
                sync.setLastSyncedAt(LocalDateTime.now());
                calendarSyncRepository.save(sync);
            } catch (Exception e) {
                log.warn("Failed to update synced event: {}", e.getMessage());
            }
        }
    }

    // Private helper methods

    private String createGoogleEvent(User user, Event event, String calendarId) {
        try {
            Calendar service = getCalendarService(user);

            com.google.api.services.calendar.model.Event googleEvent = buildGoogleEvent(event);

            com.google.api.services.calendar.model.Event createdEvent = service.events()
                    .insert(calendarId, googleEvent)
                    .execute();

            return createdEvent.getId();
        } catch (IOException e) {
            log.error("Failed to create Google Calendar event: {}", e.getMessage());
            throw new BadRequestException("Failed to create Google Calendar event: " + e.getMessage());
        }
    }

    private void updateGoogleEvent(User user, Event event, String googleEventId, String calendarId) {
        try {
            Calendar service = getCalendarService(user);

            com.google.api.services.calendar.model.Event googleEvent = buildGoogleEvent(event);

            service.events()
                    .update(calendarId, googleEventId, googleEvent)
                    .execute();
        } catch (IOException e) {
            log.error("Failed to update Google Calendar event: {}", e.getMessage());
            throw new BadRequestException("Failed to update Google Calendar event: " + e.getMessage());
        }
    }

    private void deleteGoogleEvent(User user, String googleEventId, String calendarId) {
        try {
            Calendar service = getCalendarService(user);
            service.events().delete(calendarId, googleEventId).execute();
        } catch (IOException e) {
            log.warn("Failed to delete Google Calendar event: {}", e.getMessage());
        }
    }

    private com.google.api.services.calendar.model.Event buildGoogleEvent(Event event) {
        com.google.api.services.calendar.model.Event googleEvent = new com.google.api.services.calendar.model.Event()
                .setSummary(event.getTitle())
                .setDescription(buildEventDescription(event));

        // Set start time
        DateTime startDateTime = new DateTime(
                java.util.Date.from(event.getStartTime().atZone(ZoneId.systemDefault()).toInstant())
        );
        EventDateTime start = new EventDateTime()
                .setDateTime(startDateTime)
                .setTimeZone(ZoneId.systemDefault().getId());
        googleEvent.setStart(start);

        // Set end time
        DateTime endDateTime = new DateTime(
                java.util.Date.from(event.getEndTime().atZone(ZoneId.systemDefault()).toInstant())
        );
        EventDateTime end = new EventDateTime()
                .setDateTime(endDateTime)
                .setTimeZone(ZoneId.systemDefault().getId());
        googleEvent.setEnd(end);

        // Set location if available
        if (event.getAddress() != null && !event.getAddress().isEmpty()) {
            googleEvent.setLocation(event.getAddress());
        } else if (event.getVenue() != null && !event.getVenue().isEmpty()) {
            googleEvent.setLocation(event.getVenue());
        }

        // Set reminder
        EventReminder[] reminderOverrides = new EventReminder[]{
                new EventReminder().setMethod("popup").setMinutes(60),
                new EventReminder().setMethod("popup").setMinutes(1440) // 1 day before
        };
        com.google.api.services.calendar.model.Event.Reminders reminders =
                new com.google.api.services.calendar.model.Event.Reminders()
                        .setUseDefault(false)
                        .setOverrides(Arrays.asList(reminderOverrides));
        googleEvent.setReminders(reminders);

        return googleEvent;
    }

    private String buildEventDescription(Event event) {
        StringBuilder desc = new StringBuilder();

        if (event.getDescription() != null) {
            desc.append(event.getDescription()).append("\n\n");
        }

        desc.append("📍 Venue: ").append(event.getVenue() != null ? event.getVenue() : "TBA").append("\n");

        if (event.getAddress() != null) {
            desc.append("📌 Address: ").append(event.getAddress()).append("\n");
        }

        desc.append("\n---\n");
        desc.append("Managed by LUMA Event Management");

        return desc.toString();
    }

    @SuppressWarnings("deprecation")
    private Calendar getCalendarService(User user) {
        GoogleCalendarToken token = tokenRepository.findByUserIdAndIsActiveTrue(user.getId())
                .orElseThrow(() -> new BadRequestException("Google Calendar not connected"));

        // Refresh token if expired
        if (token.isExpired()) {
            refreshAccessToken(token);
        }

        GoogleCredential credential = new GoogleCredential().setAccessToken(token.getAccessToken());

        return new Calendar.Builder(HTTP_TRANSPORT, JSON_FACTORY, credential)
                .setApplicationName(APPLICATION_NAME)
                .build();
    }

    private void refreshAccessToken(GoogleCalendarToken token) {
        try {
            GoogleTokenResponse response = new GoogleRefreshTokenRequest(
                    HTTP_TRANSPORT,
                    JSON_FACTORY,
                    token.getRefreshToken(),
                    clientId,
                    clientSecret
            ).execute();

            token.setAccessToken(response.getAccessToken());
            token.setExpiresAt(LocalDateTime.now().plusSeconds(response.getExpiresInSeconds()));
            tokenRepository.save(token);
        } catch (IOException e) {
            log.error("Failed to refresh access token: {}", e.getMessage());
            token.setIsActive(false);
            tokenRepository.save(token);
            throw new BadRequestException("Google Calendar session expired. Please reconnect.");
        }
    }

    private CalendarSyncResponse mapToResponse(CalendarSync sync) {
        Event event = sync.getRegistration().getEvent();
        return CalendarSyncResponse.builder()
                .id(sync.getId())
                .registrationId(sync.getRegistration().getId())
                .eventId(event.getId())
                .eventTitle(event.getTitle())
                .eventStartTime(event.getStartTime())
                .eventEndTime(event.getEndTime())
                .googleEventId(sync.getGoogleEventId())
                .calendarId(sync.getCalendarId())
                .isSynced(sync.getIsSynced())
                .lastSyncedAt(sync.getLastSyncedAt())
                .build();
    }
}

package com.luma.service;

import com.luma.dto.request.EventCreateRequest;
import com.luma.dto.request.EventUpdateRequest;
import com.luma.dto.request.SpeakerRequest;
import com.luma.dto.request.TicketTypeRequest;
import com.luma.dto.response.EventResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.Category;
import com.luma.entity.City;
import com.luma.entity.Event;
import com.luma.entity.Speaker;
import com.luma.entity.TicketType;
import com.luma.entity.User;
import com.luma.entity.enums.EventStatus;
import com.luma.entity.enums.RecurrenceType;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.entity.OrganiserProfile;
import com.luma.repository.EventRepository;
import com.luma.repository.EventBoostRepository;
import com.luma.entity.EventSession;
import com.luma.repository.EventSessionRepository;
import com.luma.repository.OrganiserProfileRepository;
import com.luma.repository.ReviewRepository;
import com.luma.repository.SeatZoneRepository;
import com.luma.repository.TicketTypeRepository;
import com.luma.entity.enums.BoostPackage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDateTime;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class EventService {

    private final EventRepository eventRepository;
    private final EventBoostRepository eventBoostRepository;
    private final SeatZoneRepository seatZoneRepository;
    private final EventSessionRepository eventSessionRepository;
    private final TicketTypeRepository ticketTypeRepository;
    private final CategoryService categoryService;
    private final CityService cityService;
    private final NotificationService notificationService;
    private final OrganiserProfileRepository organiserProfileRepository;
    private final ReviewRepository reviewRepository;
    private final OrganiserSubscriptionService subscriptionService;

    @Transactional(readOnly = true)
    public Event getEntityById(UUID id) {
        return eventRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));
    }

    @Transactional(readOnly = true)
    public Event getEntityByIdWithRelationships(UUID id) {
        Event event = eventRepository.findByIdWithBasicRelationships(id)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));
        eventRepository.findByIdWithSpeakers(id);
        eventRepository.findByIdWithRegistrationQuestions(id);
        return event;
    }

    @Transactional(readOnly = true)
    public EventResponse getEventById(UUID id) {
        Event event = getEntityById(id);
        EventResponse response = enrichEventResponseWithBoostInfo(event);
        enrichWithReviewStats(response, id);
        return response;
    }

    private void enrichWithReviewStats(EventResponse response, UUID eventId) {
        try {
            Double avgRating = reviewRepository.getAverageRatingByEventId(eventId);
            long reviewCount = reviewRepository.countByEventId(eventId);
            response.setAverageRating(avgRating);
            response.setReviewCount((int) reviewCount);
        } catch (Exception e) {
            log.warn("Failed to fetch review stats for event {}: {}", eventId, e.getMessage());
            response.setAverageRating(null);
            response.setReviewCount(0);
        }
    }

    @Transactional(readOnly = true)
    public PageResponse<EventResponse> getUpcomingEvents(Pageable pageable) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime endDate = now.plusMonths(2);
        Page<Event> events = eventRepository.findUpcomingEventsWithBoostPriority(now, endDate, pageable);
        return PageResponse.from(events, event -> enrichEventResponseWithBoostInfo(event));
    }

    @Transactional(readOnly = true)
    public PageResponse<EventResponse> getFeaturedEvents(Pageable pageable) {
        LocalDateTime now = LocalDateTime.now();
        Page<Event> events = eventRepository.findFeaturedPublicEvents(now, pageable);
        return PageResponse.from(events, event -> enrichEventResponseWithBoostInfo(event));
    }

    @Transactional(readOnly = true)
    public PageResponse<EventResponse> getEventsByCity(Long cityId, Pageable pageable) {
        City city = cityService.getEntityById(cityId);
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime endDate = now.plusMonths(2);
        Page<Event> events = eventRepository.findEventsByCityWithBoostPriority(city.getId(), now, endDate, pageable);
        return PageResponse.from(events, event -> enrichEventResponseWithBoostInfo(event));
    }

    @Transactional(readOnly = true)
    public PageResponse<EventResponse> getEventsByCountry(String country, Pageable pageable) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime endDate = now.plusMonths(2);
        Page<Event> events = eventRepository.findUpcomingEventsByCountryWithBoostPriority(country, now, endDate, pageable);
        return PageResponse.from(events, event -> enrichEventResponseWithBoostInfo(event));
    }

    @Transactional(readOnly = true)
    public PageResponse<EventResponse> getEventsByCategory(Long categoryId, Pageable pageable) {
        Category category = categoryService.getEntityById(categoryId);
        LocalDateTime now = LocalDateTime.now();
        Page<Event> events = eventRepository.findEventsByCategoryWithBoostPriority(category.getId(), now, pageable);
        return PageResponse.from(events, event -> enrichEventResponseWithBoostInfo(event));
    }

    @Transactional(readOnly = true)
    public PageResponse<EventResponse> searchEvents(String query, Pageable pageable) {
        LocalDateTime now = LocalDateTime.now();
        Page<Event> events = eventRepository.searchEventsWithBoostPriority(query, now, pageable);
        return PageResponse.from(events, event -> enrichEventResponseWithBoostInfo(event));
    }

    private EventResponse enrichEventResponseWithBoostInfo(Event event) {
        EventResponse response = EventResponse.fromEntity(event);

        List<com.luma.entity.EventBoost> activeBoosts = eventBoostRepository.findByEventIdAndStatus(
                event.getId(), com.luma.entity.enums.BoostStatus.ACTIVE);

        if (!activeBoosts.isEmpty()) {
            com.luma.entity.EventBoost boost = activeBoosts.stream()
                    .filter(com.luma.entity.EventBoost::isActive)
                    .findFirst()
                    .orElse(null);

            if (boost != null) {
                response.setIsBoosted(true);
                response.setBoostPackage(boost.getBoostPackage().name());
                response.setBoostBadge(boost.getBoostPackage().getBadgeText());
            } else {
                response.setIsBoosted(false);
                response.setBoostPackage(null);
                response.setBoostBadge(null);
            }
        } else {
            response.setIsBoosted(false);
            response.setBoostPackage(null);
            response.setBoostBadge(null);
        }

        response.setHasSeatMap(!seatZoneRepository.findByEventOrderByDisplayOrderAsc(event).isEmpty());
        response.setHasSchedule(!eventSessionRepository.findByEventOrderByStartTimeAscDisplayOrderAsc(event).isEmpty());

        return response;
    }

    @Transactional(readOnly = true)
    public PageResponse<EventResponse> getEventsByOrganiser(User organiser, Pageable pageable) {
        Page<Event> events = eventRepository.findByOrganiser(organiser, pageable);
        return PageResponse.from(events, event -> enrichEventResponseWithBoostInfo(event));
    }

    @Transactional(readOnly = true)
    public PageResponse<EventResponse> getEventsByOrganiserAndStatus(User organiser, EventStatus status, Pageable pageable) {
        Page<Event> events = eventRepository.findByOrganiserAndStatus(organiser, status, pageable);
        return PageResponse.from(events, event -> enrichEventResponseWithBoostInfo(event));
    }

    @Transactional(readOnly = true)
    public PageResponse<EventResponse> getUpcomingEventsByOrganiserId(UUID organiserId, Pageable pageable) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime endDate = now.plusMonths(2);
        Page<Event> events = eventRepository.findUpcomingEventsByOrganiser(organiserId, now, endDate, pageable);
        return PageResponse.from(events, event -> enrichEventResponseWithBoostInfo(event));
    }

    @Transactional(readOnly = true)
    public PageResponse<EventResponse> getPastEventsByOrganiserId(UUID organiserId, Pageable pageable) {
        Page<Event> events = eventRepository.findPastEventsByOrganiser(organiserId, pageable);
        return PageResponse.from(events, EventResponse::fromEntity);
    }

    @Transactional
    public EventResponse createEvent(User organiser, EventCreateRequest request) {
        subscriptionService.validateEventCreation(organiser.getId());

        LocalDateTime cutoffTime = LocalDateTime.now().minusMinutes(5);
        if (request.getStartTime().isBefore(cutoffTime)) {
            throw new BadRequestException("Start time must be in the future");
        }
        if (request.getEndTime().isBefore(request.getStartTime())) {
            throw new BadRequestException("End time must be after start time");
        }

        ensureOrganiserProfile(organiser);

        String recurrenceDaysStr = null;
        if (request.getRecurrenceDaysOfWeek() != null && !request.getRecurrenceDaysOfWeek().isEmpty()) {
            recurrenceDaysStr = String.join(",", request.getRecurrenceDaysOfWeek());
        }

        Event event = Event.builder()
                .title(request.getTitle())
                .description(request.getDescription())
                .imageUrl(request.getImageUrl())
                .startTime(request.getStartTime())
                .endTime(request.getEndTime())
                .registrationDeadline(request.getRegistrationDeadline())
                .venue(request.getVenue())
                .address(request.getAddress())
                .latitude(request.getLatitude())
                .longitude(request.getLongitude())
                .ticketPrice(request.getTicketPrice() != null ? request.getTicketPrice() : BigDecimal.ZERO)
                .isFree(request.isFree())
                .capacity(request.getCapacity())
                .visibility(request.getVisibility())
                .requiresApproval(request.isRequiresApproval())
                .status(EventStatus.DRAFT)
                .organiser(organiser)
                .recurrenceType(request.getRecurrenceType() != null ? request.getRecurrenceType() : RecurrenceType.NONE)
                .recurrenceInterval(request.getRecurrenceInterval())
                .recurrenceDaysOfWeek(recurrenceDaysStr)
                .recurrenceEndDate(request.getRecurrenceEndDate())
                .recurrenceCount(request.getRecurrenceCount())
                .occurrenceIndex(1)
                .build();

        if (request.getCityId() != null) {
            event.setCity(cityService.getEntityById(request.getCityId()));
        }
        if (request.getCategoryId() != null) {
            event.setCategory(categoryService.getEntityById(request.getCategoryId()));
        }

        Event savedEvent = eventRepository.save(event);

        if (request.getSpeakers() != null && !request.getSpeakers().isEmpty()) {
            for (SpeakerRequest speakerRequest : request.getSpeakers()) {
                Speaker speaker = Speaker.builder()
                        .name(speakerRequest.getName())
                        .title(speakerRequest.getTitle())
                        .bio(speakerRequest.getBio())
                        .imageUrl(speakerRequest.getImageUrl())
                        .event(savedEvent)
                        .build();
                savedEvent.getSpeakers().add(speaker);
            }
            savedEvent = eventRepository.save(savedEvent);
        }

        if (request.getTicketTypes() != null && !request.getTicketTypes().isEmpty()) {
            persistTicketTypes(savedEvent, request.getTicketTypes());
            savedEvent = syncEventFreeFromTiers(savedEvent);
        }

        if (request.getRecurrenceType() != null && request.getRecurrenceType() != RecurrenceType.NONE) {
            createRecurringEventInstances(savedEvent, request);
        }

        subscriptionService.incrementEventCount(organiser.getId());

        try {
            notificationService.notifyAdminsEventCreated(savedEvent);
        } catch (Exception e) {
            log.error("Failed to notify admins about new event: {}", e.getMessage());
        }

        return EventResponse.fromEntity(savedEvent);
    }

    private void createRecurringEventInstances(Event parentEvent, EventCreateRequest request) {
        List<LocalDateTime> occurrences = calculateOccurrences(request);
        long eventDuration = java.time.Duration.between(request.getStartTime(), request.getEndTime()).toMinutes();

        int index = 2;
        for (LocalDateTime startTime : occurrences) {
            LocalDateTime endTime = startTime.plusMinutes(eventDuration);
            LocalDateTime registrationDeadline = null;

            if (request.getRegistrationDeadline() != null) {
                long deadlineOffset = java.time.Duration.between(request.getStartTime(), request.getRegistrationDeadline()).toMinutes();
                registrationDeadline = startTime.plusMinutes(deadlineOffset);
            }

            Event childEvent = Event.builder()
                    .title(parentEvent.getTitle())
                    .description(parentEvent.getDescription())
                    .imageUrl(parentEvent.getImageUrl())
                    .startTime(startTime)
                    .endTime(endTime)
                    .registrationDeadline(registrationDeadline)
                    .venue(parentEvent.getVenue())
                    .address(parentEvent.getAddress())
                    .latitude(parentEvent.getLatitude())
                    .longitude(parentEvent.getLongitude())
                    .ticketPrice(parentEvent.getTicketPrice())
                    .isFree(parentEvent.isFree())
                    .capacity(parentEvent.getCapacity())
                    .visibility(parentEvent.getVisibility())
                    .requiresApproval(parentEvent.isRequiresApproval())
                    .status(EventStatus.DRAFT)
                    .organiser(parentEvent.getOrganiser())
                    .category(parentEvent.getCategory())
                    .city(parentEvent.getCity())
                    .recurrenceType(parentEvent.getRecurrenceType())
                    .parentEvent(parentEvent)
                    .occurrenceIndex(index)
                    .build();

            for (Speaker speaker : parentEvent.getSpeakers()) {
                Speaker childSpeaker = Speaker.builder()
                        .name(speaker.getName())
                        .title(speaker.getTitle())
                        .bio(speaker.getBio())
                        .imageUrl(speaker.getImageUrl())
                        .event(childEvent)
                        .build();
                childEvent.getSpeakers().add(childSpeaker);
            }

            eventRepository.save(childEvent);
            index++;
        }

        log.info("Created {} recurring event instances for parent event: {}", occurrences.size(), parentEvent.getId());
    }

    private List<LocalDateTime> calculateOccurrences(EventCreateRequest request) {
        List<LocalDateTime> occurrences = new ArrayList<>();
        LocalDateTime currentDate = request.getStartTime();
        int interval = request.getRecurrenceInterval() != null ? request.getRecurrenceInterval() : 1;
        int maxOccurrences = request.getRecurrenceCount() != null ? request.getRecurrenceCount() : 52;
        LocalDateTime endDate = request.getRecurrenceEndDate();

        maxOccurrences = Math.min(maxOccurrences, 52);

        int count = 0;
        while (count < maxOccurrences - 1) {
            LocalDateTime nextDate = calculateNextOccurrence(currentDate, request.getRecurrenceType(), interval, request.getRecurrenceDaysOfWeek());

            if (nextDate == null) break;
            if (endDate != null && nextDate.isAfter(endDate)) break;

            occurrences.add(nextDate);
            currentDate = nextDate;
            count++;
        }

        return occurrences;
    }

    private LocalDateTime calculateNextOccurrence(LocalDateTime current, RecurrenceType type, int interval, List<String> daysOfWeek) {
        switch (type) {
            case DAILY:
                return current.plusDays(interval);

            case WEEKLY:
                if (daysOfWeek != null && !daysOfWeek.isEmpty()) {
                    return findNextDayOfWeek(current, daysOfWeek, interval);
                }
                return current.plusWeeks(interval);

            case BIWEEKLY:
                return current.plusWeeks(2 * interval);

            case MONTHLY:
                return current.plusMonths(interval);

            default:
                return null;
        }
    }

    private LocalDateTime findNextDayOfWeek(LocalDateTime current, List<String> daysOfWeek, int weekInterval) {
        List<DayOfWeek> targetDays = daysOfWeek.stream()
                .map(this::parseDayOfWeek)
                .filter(d -> d != null)
                .sorted()
                .toList();

        if (targetDays.isEmpty()) {
            return current.plusWeeks(weekInterval);
        }

        DayOfWeek currentDay = current.getDayOfWeek();

        for (DayOfWeek targetDay : targetDays) {
            if (targetDay.getValue() > currentDay.getValue()) {
                return current.with(TemporalAdjusters.next(targetDay));
            }
        }

        DayOfWeek firstDay = targetDays.get(0);
        return current.plusWeeks(weekInterval).with(TemporalAdjusters.nextOrSame(firstDay));
    }

    private DayOfWeek parseDayOfWeek(String day) {
        return switch (day.toUpperCase()) {
            case "MON", "MONDAY" -> DayOfWeek.MONDAY;
            case "TUE", "TUESDAY" -> DayOfWeek.TUESDAY;
            case "WED", "WEDNESDAY" -> DayOfWeek.WEDNESDAY;
            case "THU", "THURSDAY" -> DayOfWeek.THURSDAY;
            case "FRI", "FRIDAY" -> DayOfWeek.FRIDAY;
            case "SAT", "SATURDAY" -> DayOfWeek.SATURDAY;
            case "SUN", "SUNDAY" -> DayOfWeek.SUNDAY;
            default -> null;
        };
    }

    @Transactional
    public EventResponse updateEvent(UUID eventId, User organiser, EventUpdateRequest request) {
        Event event = getEntityById(eventId);

        if (!event.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You do not have permission to edit this event");
        }

        if (event.getStatus() == EventStatus.COMPLETED || event.getStatus() == EventStatus.CANCELLED) {
            throw new BadRequestException("Cannot edit a completed or cancelled event");
        }

        boolean wasRejected = event.getStatus() == EventStatus.REJECTED;

        if (wasRejected) {
            event.setStatus(EventStatus.DRAFT);
            event.setRejectionReason(null);
        }

        RecurrenceType originalRecurrenceType = event.getRecurrenceType();
        boolean wasNotRecurring = (originalRecurrenceType == null || originalRecurrenceType == RecurrenceType.NONE)
                && event.getParentEvent() == null;

        // Track which attendee-visible fields actually changed to fire an update notification later
        java.util.List<String> changedFields = new java.util.ArrayList<>();
        String originalTitle = event.getTitle();
        java.time.LocalDateTime originalStart = event.getStartTime();
        java.time.LocalDateTime originalEnd = event.getEndTime();
        String originalVenue = event.getVenue();
        String originalAddress = event.getAddress();

        if (request.getTitle() != null) {
            if (!java.util.Objects.equals(originalTitle, request.getTitle())) changedFields.add("title");
            event.setTitle(request.getTitle());
        }
        if (request.getDescription() != null) event.setDescription(request.getDescription());
        if (request.getImageUrl() != null) event.setImageUrl(request.getImageUrl());
        if (request.getStartTime() != null) {
            if (!java.util.Objects.equals(originalStart, request.getStartTime())) changedFields.add("start time");
            event.setStartTime(request.getStartTime());
        }
        if (request.getEndTime() != null) {
            if (!java.util.Objects.equals(originalEnd, request.getEndTime())) changedFields.add("end time");
            event.setEndTime(request.getEndTime());
        }
        if (request.getRegistrationDeadline() != null) event.setRegistrationDeadline(request.getRegistrationDeadline());
        if (request.getVenue() != null) {
            if (!java.util.Objects.equals(originalVenue, request.getVenue())) changedFields.add("venue");
            event.setVenue(request.getVenue());
        }
        if (request.getAddress() != null) {
            if (!java.util.Objects.equals(originalAddress, request.getAddress())) changedFields.add("address");
            event.setAddress(request.getAddress());
        }
        if (request.getLatitude() != null) event.setLatitude(request.getLatitude());
        if (request.getLongitude() != null) event.setLongitude(request.getLongitude());
        if (request.getIsFree() != null && request.getIsFree()) {
            event.setTicketPrice(BigDecimal.ZERO);
        } else if (request.getTicketPrice() != null) {
            event.setTicketPrice(request.getTicketPrice());
        }
        if (request.getCapacity() != null) event.setCapacity(request.getCapacity());
        if (request.getVisibility() != null) event.setVisibility(request.getVisibility());
        if (request.getStatus() != null) event.setStatus(request.getStatus());
        if (request.getRequiresApproval() != null) event.setRequiresApproval(request.getRequiresApproval());
        if (request.getCityId() != null) event.setCity(cityService.getEntityById(request.getCityId()));
        if (request.getCategoryId() != null) event.setCategory(categoryService.getEntityById(request.getCategoryId()));

        if (request.getSpeakers() != null) {
            // Detach sessions from their speakers to avoid FK violation during speaker replacement
            for (EventSession session : event.getSessions()) {
                if (session.getSpeaker() != null) {
                    session.setSpeaker(null);
                }
            }
            event.getSpeakers().clear();
            for (SpeakerRequest speakerRequest : request.getSpeakers()) {
                Speaker speaker = Speaker.builder()
                        .name(speakerRequest.getName())
                        .title(speakerRequest.getTitle())
                        .bio(speakerRequest.getBio())
                        .imageUrl(speakerRequest.getImageUrl())
                        .event(event)
                        .build();
                event.getSpeakers().add(speaker);
            }
        }

        if (request.getTicketTypes() != null) {
            syncTicketTypes(event, request.getTicketTypes());
            event = syncEventFreeFromTiers(event);
        }

        if (request.getRecurrenceType() != null) {
            event.setRecurrenceType(request.getRecurrenceType());
        }
        if (request.getRecurrenceInterval() != null) {
            event.setRecurrenceInterval(request.getRecurrenceInterval());
        }
        if (request.getRecurrenceDaysOfWeek() != null) {
            String recurrenceDaysStr = String.join(",", request.getRecurrenceDaysOfWeek());
            event.setRecurrenceDaysOfWeek(recurrenceDaysStr);
        }
        if (request.getRecurrenceEndDate() != null) {
            event.setRecurrenceEndDate(request.getRecurrenceEndDate());
        }
        if (request.getRecurrenceCount() != null) {
            event.setRecurrenceCount(request.getRecurrenceCount());
        }

        if (Boolean.TRUE.equals(request.getUpdateSeries()) && event.getChildEvents() != null && !event.getChildEvents().isEmpty()) {
            updateChildEvents(event, request);
        }

        Event savedEvent = eventRepository.save(event);

        // Notify attendees if any user-visible field changed on a published event
        if (!changedFields.isEmpty()
                && savedEvent.getStatus() != EventStatus.DRAFT
                && savedEvent.getStatus() != EventStatus.CANCELLED) {
            try {
                notificationService.notifyAttendeesEventUpdated(savedEvent, changedFields);
            } catch (Exception ex) {
                log.warn("Failed to send update notification for event {}: {}", savedEvent.getId(), ex.getMessage());
            }
        }

        boolean isNowRecurring = request.getRecurrenceType() != null
                && request.getRecurrenceType() != RecurrenceType.NONE;

        if (wasNotRecurring && isNowRecurring) {
            createRecurringEventInstancesFromUpdate(savedEvent, request);
            savedEvent.setOccurrenceIndex(1);
            savedEvent = eventRepository.save(savedEvent);
            log.info("Changed event {} from non-recurring to recurring type: {}", savedEvent.getId(), request.getRecurrenceType());
        }

        if (wasRejected) {
            try {
                notificationService.notifyAdminEventResubmitted(savedEvent);
                log.info("Sent resubmit notification for event: {}", savedEvent.getId());
            } catch (Exception e) {
                log.error("Failed to send resubmit notification: {}", e.getMessage());
            }
        }

        return EventResponse.fromEntity(savedEvent);
    }

    private void createRecurringEventInstancesFromUpdate(Event parentEvent, EventUpdateRequest request) {
        List<LocalDateTime> occurrences = calculateOccurrencesFromUpdate(parentEvent, request);
        long eventDuration = java.time.Duration.between(parentEvent.getStartTime(), parentEvent.getEndTime()).toMinutes();

        int index = 2;
        for (LocalDateTime startTime : occurrences) {
            LocalDateTime endTime = startTime.plusMinutes(eventDuration);
            LocalDateTime registrationDeadline = null;

            if (parentEvent.getRegistrationDeadline() != null) {
                long deadlineOffset = java.time.Duration.between(parentEvent.getStartTime(), parentEvent.getRegistrationDeadline()).toMinutes();
                registrationDeadline = startTime.plusMinutes(deadlineOffset);
            }

            Event childEvent = Event.builder()
                    .title(parentEvent.getTitle())
                    .description(parentEvent.getDescription())
                    .imageUrl(parentEvent.getImageUrl())
                    .startTime(startTime)
                    .endTime(endTime)
                    .registrationDeadline(registrationDeadline)
                    .venue(parentEvent.getVenue())
                    .address(parentEvent.getAddress())
                    .latitude(parentEvent.getLatitude())
                    .longitude(parentEvent.getLongitude())
                    .ticketPrice(parentEvent.getTicketPrice())
                    .isFree(parentEvent.isFree())
                    .capacity(parentEvent.getCapacity())
                    .visibility(parentEvent.getVisibility())
                    .requiresApproval(parentEvent.isRequiresApproval())
                    .status(parentEvent.getStatus())
                    .organiser(parentEvent.getOrganiser())
                    .category(parentEvent.getCategory())
                    .city(parentEvent.getCity())
                    .recurrenceType(parentEvent.getRecurrenceType())
                    .parentEvent(parentEvent)
                    .occurrenceIndex(index)
                    .build();

            for (Speaker speaker : parentEvent.getSpeakers()) {
                Speaker childSpeaker = Speaker.builder()
                        .name(speaker.getName())
                        .title(speaker.getTitle())
                        .bio(speaker.getBio())
                        .imageUrl(speaker.getImageUrl())
                        .event(childEvent)
                        .build();
                childEvent.getSpeakers().add(childSpeaker);
            }

            eventRepository.save(childEvent);
            index++;
        }

        log.info("Created {} recurring event instances from update for parent event: {}", occurrences.size(), parentEvent.getId());
    }

    private List<LocalDateTime> calculateOccurrencesFromUpdate(Event parentEvent, EventUpdateRequest request) {
        List<LocalDateTime> occurrences = new ArrayList<>();
        LocalDateTime currentDate = parentEvent.getStartTime();
        int interval = request.getRecurrenceInterval() != null ? request.getRecurrenceInterval() : 1;
        int maxOccurrences = request.getRecurrenceCount() != null ? request.getRecurrenceCount() : 52;
        LocalDateTime endDate = request.getRecurrenceEndDate();

        maxOccurrences = Math.min(maxOccurrences, 52);

        int count = 0;
        while (count < maxOccurrences - 1) {
            LocalDateTime nextDate = calculateNextOccurrence(currentDate, request.getRecurrenceType(), interval, request.getRecurrenceDaysOfWeek());

            if (nextDate == null) break;
            if (endDate != null && nextDate.isAfter(endDate)) break;

            occurrences.add(nextDate);
            currentDate = nextDate;
            count++;
        }

        return occurrences;
    }

    private void updateChildEvents(Event parentEvent, EventUpdateRequest request) {
        for (Event childEvent : parentEvent.getChildEvents()) {
            if (request.getTitle() != null) childEvent.setTitle(request.getTitle());
            if (request.getDescription() != null) childEvent.setDescription(request.getDescription());
            if (request.getImageUrl() != null) childEvent.setImageUrl(request.getImageUrl());
            if (request.getVenue() != null) childEvent.setVenue(request.getVenue());
            if (request.getAddress() != null) childEvent.setAddress(request.getAddress());
            if (request.getLatitude() != null) childEvent.setLatitude(request.getLatitude());
            if (request.getLongitude() != null) childEvent.setLongitude(request.getLongitude());
            if (request.getIsFree() != null && request.getIsFree()) {
                childEvent.setTicketPrice(BigDecimal.ZERO);
            } else if (request.getTicketPrice() != null) {
                childEvent.setTicketPrice(request.getTicketPrice());
            }
            if (request.getCapacity() != null) childEvent.setCapacity(request.getCapacity());
            if (request.getVisibility() != null) childEvent.setVisibility(request.getVisibility());
            if (request.getRequiresApproval() != null) childEvent.setRequiresApproval(request.getRequiresApproval());
            if (request.getCityId() != null) childEvent.setCity(cityService.getEntityById(request.getCityId()));
            if (request.getCategoryId() != null) childEvent.setCategory(categoryService.getEntityById(request.getCategoryId()));

            if (request.getSpeakers() != null) {
                childEvent.getSpeakers().clear();
                for (SpeakerRequest speakerRequest : request.getSpeakers()) {
                    Speaker speaker = Speaker.builder()
                            .name(speakerRequest.getName())
                            .title(speakerRequest.getTitle())
                            .bio(speakerRequest.getBio())
                            .imageUrl(speakerRequest.getImageUrl())
                            .event(childEvent)
                            .build();
                    childEvent.getSpeakers().add(speaker);
                }
            }

            if (request.getRecurrenceType() != null) {
                childEvent.setRecurrenceType(request.getRecurrenceType());
            }

            eventRepository.save(childEvent);
        }
        log.info("Updated {} child events for parent event: {}", parentEvent.getChildEvents().size(), parentEvent.getId());
    }

    @Transactional
    public EventResponse publishEvent(UUID eventId, User organiser) {
        Event event = getEntityById(eventId);

        if (!event.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You do not have permission to publish this event");
        }

        event.setStatus(EventStatus.PUBLISHED);
        return EventResponse.fromEntity(eventRepository.save(event));
    }

    @Transactional
    public EventResponse cancelEvent(UUID eventId, User organiser) {
        return cancelEvent(eventId, organiser, null, false);
    }

    @Transactional
    public EventResponse cancelEvent(UUID eventId, User organiser, String reason, boolean cancelSeries) {
        Event event = getEntityById(eventId);

        if (!event.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You do not have permission to cancel this event");
        }

        if (event.getStatus() == EventStatus.CANCELLED) {
            throw new BadRequestException("This event is already cancelled");
        }
        if (event.getStatus() == EventStatus.COMPLETED) {
            throw new BadRequestException("Cannot cancel a completed event");
        }

        event.setStatus(EventStatus.CANCELLED);
        Event savedEvent = eventRepository.save(event);

        try {
            int notifiedCount = notificationService.notifyAttendeesEventCancelled(savedEvent, reason);
            log.info("Notified {} attendees about event cancellation: {}", notifiedCount, savedEvent.getId());
        } catch (Exception e) {
            log.error("Failed to notify attendees about event cancellation: {}", e.getMessage());
        }

        if (cancelSeries) {
            cancelRecurringSeries(event, reason);
        }

        return EventResponse.fromEntity(savedEvent);
    }

    private void cancelRecurringSeries(Event event, String reason) {
        Event parentEvent = event.getParentEvent() != null ? event.getParentEvent() : event;

        if (parentEvent.getStatus() != EventStatus.CANCELLED && !parentEvent.getId().equals(event.getId())) {
            parentEvent.setStatus(EventStatus.CANCELLED);
            eventRepository.save(parentEvent);
            try {
                notificationService.notifyAttendeesEventCancelled(parentEvent, reason);
            } catch (Exception e) {
                log.error("Failed to notify attendees for parent event: {}", e.getMessage());
            }
        }

        if (parentEvent.getChildEvents() != null) {
            for (Event childEvent : parentEvent.getChildEvents()) {
                if (childEvent.getStatus() != EventStatus.CANCELLED && !childEvent.getId().equals(event.getId())) {
                    childEvent.setStatus(EventStatus.CANCELLED);
                    eventRepository.save(childEvent);
                    try {
                        notificationService.notifyAttendeesEventCancelled(childEvent, reason);
                    } catch (Exception e) {
                        log.error("Failed to notify attendees for child event: {}", e.getMessage());
                    }
                }
            }
        }

        log.info("Cancelled recurring series for event: {}", event.getId());
    }

    @Transactional(readOnly = true)
    public PageResponse<EventResponse> getAllEventsForAdmin(String search, String status, Pageable pageable) {
        Page<Event> events;
        EventStatus eventStatus = null;

        if (status != null && !status.isEmpty()) {
            try {
                eventStatus = EventStatus.valueOf(status);
            } catch (IllegalArgumentException ignored) {}
        }

        if (search != null && !search.isEmpty() && eventStatus != null) {
            events = eventRepository.findByTitleContainingIgnoreCaseAndStatus(search, eventStatus, pageable);
        } else if (search != null && !search.isEmpty()) {
            events = eventRepository.findByTitleContainingIgnoreCase(search, pageable);
        } else if (eventStatus != null) {
            events = eventRepository.findByStatus(eventStatus, pageable);
        } else {
            events = eventRepository.findAll(pageable);
        }

        return PageResponse.from(events, EventResponse::fromEntity);
    }

    @Transactional(readOnly = true)
    public PageResponse<EventResponse> getPendingEventsForAdmin(Pageable pageable) {
        Page<Event> events = eventRepository.findByStatus(EventStatus.DRAFT, pageable);
        return PageResponse.from(events, EventResponse::fromEntity);
    }

    @Transactional
    public EventResponse approveEvent(UUID eventId) {
        Event event = eventRepository.findByIdWithRelationships(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        event.setStatus(EventStatus.PUBLISHED);
        Event savedEvent = eventRepository.save(event);

        notificationService.notifyOrganiserEventApproved(savedEvent);

        return EventResponse.fromEntity(savedEvent);
    }

    @Transactional
    public EventResponse rejectEvent(UUID eventId, String reason) {
        log.info("=== REJECT EVENT START ===");
        log.info("Event ID: {}", eventId);
        log.info("Reason: {}", reason);

        Event event = eventRepository.findByIdWithRelationships(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        log.info("Event found: {}", event.getTitle());

        event.setStatus(EventStatus.REJECTED);
        event.setRejectionReason(reason);
        Event savedEvent = eventRepository.save(event);

        log.info("Event saved with REJECTED status");

        try {
            notificationService.notifyOrganiserEventRejected(savedEvent, reason);
            log.info("Notification sent successfully");
        } catch (Exception e) {
            log.error("Failed to send rejection notification: {}", e.getMessage(), e);
        }

        log.info("Building response...");
        EventResponse response = EventResponse.fromEntity(savedEvent);
        log.info("=== REJECT EVENT END ===");
        return response;
    }

    @Transactional
    public EventResponse hideEvent(UUID eventId) {
        Event event = getEntityById(eventId);
        event.setStatus(EventStatus.HIDDEN);
        return EventResponse.fromEntity(eventRepository.save(event));
    }

    @Transactional
    public EventResponse unhideEvent(UUID eventId) {
        Event event = getEntityById(eventId);
        event.setStatus(EventStatus.PUBLISHED);
        return EventResponse.fromEntity(eventRepository.save(event));
    }

    @Transactional
    public void deleteEvent(UUID eventId) {
        deleteEvent(eventId, false);
    }

    @Transactional
    public void deleteEvent(UUID eventId, boolean deleteSeries) {
        Event event = getEntityById(eventId);

        if (deleteSeries) {
            deleteRecurringSeries(event);
        } else {
            eventRepository.deleteById(eventId);
        }
    }

    @Transactional
    public void deleteEventByOrganiser(UUID eventId, User organiser) {
        deleteEventByOrganiser(eventId, organiser, false);
    }

    @Transactional
    public void deleteEventByOrganiser(UUID eventId, User organiser, boolean deleteSeries) {
        Event event = getEntityById(eventId);

        if (!event.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You do not have permission to delete this event");
        }

        if (event.getStatus() == EventStatus.PUBLISHED) {
            throw new BadRequestException("Cannot delete a published event. Please cancel the event first.");
        }

        long activeRegistrations = countActiveRegistrations(event);
        if (activeRegistrations > 0 && event.getStatus() != EventStatus.CANCELLED) {
            throw new BadRequestException("Cannot delete event with " + activeRegistrations + " active registrations. Please cancel the event first to notify attendees.");
        }

        if (deleteSeries) {
            deleteRecurringSeries(event);
        } else {
            eventRepository.delete(event);
        }

        log.info("Event deleted by organiser: {}", eventId);
    }

    private long countActiveRegistrations(Event event) {
        try {
            return eventRepository.countActiveRegistrations(event.getId());
        } catch (Exception e) {
            log.warn("Failed to count active registrations: {}", e.getMessage());
            return 0;
        }
    }

    private void deleteRecurringSeries(Event event) {
        Event parentEvent = event.getParentEvent() != null ? event.getParentEvent() : event;

        if (parentEvent.getChildEvents() != null) {
            for (Event childEvent : new ArrayList<>(parentEvent.getChildEvents())) {
                if (childEvent.getStatus() == EventStatus.PUBLISHED) {
                    throw new BadRequestException("Cannot delete series: event '" + childEvent.getTitle() +
                            "' (occurrence " + childEvent.getOccurrenceIndex() + ") is published. Please cancel the series first.");
                }
                eventRepository.delete(childEvent);
            }
        }

        eventRepository.delete(parentEvent);
        log.info("Deleted recurring series for event: {}", parentEvent.getId());
    }

    @Transactional
    public void incrementApprovedCount(Event event) {
        event.setApprovedCount(event.getApprovedCount() + 1);
        eventRepository.save(event);
    }

    @Transactional
    public void decrementApprovedCount(Event event) {
        if (event.getApprovedCount() > 0) {
            event.setApprovedCount(event.getApprovedCount() - 1);
            eventRepository.save(event);
        }
    }

    @Transactional(readOnly = true)
    public long countByOrganiser(User organiser) {
        return eventRepository.countByOrganiser(organiser);
    }

    @Transactional(readOnly = true)
    public long countByOrganiserAndStatus(User organiser, EventStatus status) {
        return eventRepository.countByOrganiserAndStatus(organiser, status);
    }

    @Transactional(readOnly = true)
    public PageResponse<EventResponse> getEventsBySpeaker(String speakerName, Pageable pageable) {
        Page<Event> events = eventRepository.findEventsBySpeakerName(speakerName, pageable);
        return PageResponse.from(events, event -> enrichEventResponseWithBoostInfo(event));
    }

    private void persistTicketTypes(Event event, List<TicketTypeRequest> requests) {
        int order = 0;
        for (TicketTypeRequest req : requests) {
            validateTicketTypeAgainstEvent(req, event);
            TicketType tier = TicketType.builder()
                    .event(event)
                    .name(req.getName())
                    .description(req.getDescription())
                    .price(req.getPrice() != null ? req.getPrice() : BigDecimal.ZERO)
                    .quantity(req.getQuantity())
                    .soldCount(0)
                    .maxPerOrder(req.getMaxPerOrder() != null ? req.getMaxPerOrder() : 10)
                    .saleStartDate(req.getSaleStartDate())
                    .saleEndDate(req.getSaleEndDate())
                    .isVisible(req.getIsVisible() != null ? req.getIsVisible() : true)
                    .displayOrder(req.getDisplayOrder() != null ? req.getDisplayOrder() : order)
                    .build();
            ticketTypeRepository.save(tier);
            order++;
        }
    }

    private void syncTicketTypes(Event event, List<TicketTypeRequest> requests) {
        List<TicketType> existing = ticketTypeRepository.findByEventIdOrderByDisplayOrderAsc(event.getId());
        java.util.Map<UUID, TicketType> existingById = new java.util.HashMap<>();
        for (TicketType tt : existing) existingById.put(tt.getId(), tt);

        java.util.Set<UUID> keepIds = new java.util.HashSet<>();
        int order = 0;
        for (TicketTypeRequest req : requests) {
            validateTicketTypeAgainstEvent(req, event);
            if (req.getId() != null && existingById.containsKey(req.getId())) {
                TicketType tier = existingById.get(req.getId());
                if (req.getQuantity() != null && req.getQuantity() < tier.getSoldCount()) {
                    throw new BadRequestException("Ticket type '" + tier.getName() +
                            "': cannot reduce quantity below sold count (" + tier.getSoldCount() + ")");
                }
                tier.setName(req.getName());
                tier.setDescription(req.getDescription());
                tier.setPrice(req.getPrice() != null ? req.getPrice() : BigDecimal.ZERO);
                tier.setQuantity(req.getQuantity());
                tier.setMaxPerOrder(req.getMaxPerOrder() != null ? req.getMaxPerOrder() : tier.getMaxPerOrder());
                tier.setSaleStartDate(req.getSaleStartDate());
                tier.setSaleEndDate(req.getSaleEndDate());
                if (req.getIsVisible() != null) tier.setIsVisible(req.getIsVisible());
                tier.setDisplayOrder(req.getDisplayOrder() != null ? req.getDisplayOrder() : order);
                ticketTypeRepository.save(tier);
                keepIds.add(tier.getId());
            } else {
                TicketType tier = TicketType.builder()
                        .event(event)
                        .name(req.getName())
                        .description(req.getDescription())
                        .price(req.getPrice() != null ? req.getPrice() : BigDecimal.ZERO)
                        .quantity(req.getQuantity())
                        .soldCount(0)
                        .maxPerOrder(req.getMaxPerOrder() != null ? req.getMaxPerOrder() : 10)
                        .saleStartDate(req.getSaleStartDate())
                        .saleEndDate(req.getSaleEndDate())
                        .isVisible(req.getIsVisible() != null ? req.getIsVisible() : true)
                        .displayOrder(req.getDisplayOrder() != null ? req.getDisplayOrder() : order)
                        .build();
                TicketType saved = ticketTypeRepository.save(tier);
                keepIds.add(saved.getId());
            }
            order++;
        }

        for (TicketType tier : existing) {
            if (!keepIds.contains(tier.getId())) {
                if (tier.getSoldCount() != null && tier.getSoldCount() > 0) {
                    throw new BadRequestException("Cannot delete ticket type '" + tier.getName() +
                            "' with " + tier.getSoldCount() + " sold tickets. Hide it instead.");
                }
                ticketTypeRepository.delete(tier);
            }
        }
    }

    private void validateTicketTypeAgainstEvent(TicketTypeRequest req, Event event) {
        if (req.getSaleStartDate() != null && req.getSaleEndDate() != null
                && req.getSaleStartDate().isAfter(req.getSaleEndDate())) {
            throw new BadRequestException("Ticket '" + req.getName() + "': sale start must be before sale end");
        }
        if (req.getSaleEndDate() != null && event.getEndTime() != null
                && req.getSaleEndDate().isAfter(event.getEndTime())) {
            throw new BadRequestException("Ticket '" + req.getName() + "': sale end cannot be after event end time");
        }
    }

    private Event syncEventFreeFromTiers(Event event) {
        List<TicketType> tiers = ticketTypeRepository.findByEventIdOrderByDisplayOrderAsc(event.getId());
        if (tiers.isEmpty()) return event;
        boolean allFree = tiers.stream()
                .filter(t -> Boolean.TRUE.equals(t.getIsVisible()))
                .allMatch(t -> t.getPrice() == null || t.getPrice().compareTo(BigDecimal.ZERO) == 0);
        event.setFree(allFree);
        BigDecimal minPrice = tiers.stream()
                .filter(t -> Boolean.TRUE.equals(t.getIsVisible()))
                .map(TicketType::getPrice)
                .filter(java.util.Objects::nonNull)
                .min(BigDecimal::compareTo)
                .orElse(event.getTicketPrice() != null ? event.getTicketPrice() : BigDecimal.ZERO);
        event.setTicketPrice(minPrice);
        return eventRepository.save(event);
    }

    private void ensureOrganiserProfile(User user) {
        if (!organiserProfileRepository.existsByUser(user)) {
            String displayName = user.getFullName();
            if (displayName == null || displayName.isEmpty()) {
                displayName = user.getEmail() != null ? user.getEmail().split("@")[0] : "Organiser";
            }

            OrganiserProfile profile = OrganiserProfile.builder()
                    .user(user)
                    .displayName(displayName)
                    .bio(null)
                    .logoUrl(user.getAvatarUrl())
                    .website(null)
                    .contactEmail(user.getEmail())
                    .contactPhone(user.getPhone())
                    .build();

            organiserProfileRepository.save(profile);
            log.info("Auto-created OrganiserProfile for user: {} ({})", user.getId(), displayName);
        }
    }
}

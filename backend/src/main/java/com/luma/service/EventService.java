package com.luma.service;

import com.luma.dto.request.EventCreateRequest;
import com.luma.dto.request.EventUpdateRequest;
import com.luma.dto.request.SpeakerRequest;
import com.luma.dto.response.EventResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.Category;
import com.luma.entity.City;
import com.luma.entity.Event;
import com.luma.entity.Speaker;
import com.luma.entity.User;
import com.luma.entity.enums.EventStatus;
import com.luma.entity.enums.RecurrenceType;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.entity.OrganiserProfile;
import com.luma.repository.EventRepository;
import com.luma.repository.EventBoostRepository;
import com.luma.repository.OrganiserProfileRepository;
import com.luma.repository.ReviewRepository;
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
    private final CategoryService categoryService;
    private final CityService cityService;
    private final NotificationService notificationService;
    private final OrganiserProfileRepository organiserProfileRepository;
    private final ReviewRepository reviewRepository;
    private final OrganiserSubscriptionService subscriptionService;

    public Event getEntityById(UUID id) {
        return eventRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));
    }

    public Event getEntityByIdWithRelationships(UUID id) {
        Event event = eventRepository.findByIdWithBasicRelationships(id)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));
        eventRepository.findByIdWithSpeakers(id);
        eventRepository.findByIdWithRegistrationQuestions(id);
        return event;
    }

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

    public PageResponse<EventResponse> getUpcomingEvents(Pageable pageable) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime endDate = now.plusMonths(2);
        Page<Event> events = eventRepository.findUpcomingEventsWithBoostPriority(now, endDate, pageable);
        return PageResponse.from(events, event -> enrichEventResponseWithBoostInfo(event));
    }

    public PageResponse<EventResponse> getFeaturedEvents(Pageable pageable) {
        Page<Event> events = eventRepository.findFeaturedPublicEvents(pageable);
        return PageResponse.from(events, event -> enrichEventResponseWithBoostInfo(event));
    }

    public PageResponse<EventResponse> getEventsByCity(Long cityId, Pageable pageable) {
        City city = cityService.getEntityById(cityId);
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime endDate = now.plusMonths(2);
        Page<Event> events = eventRepository.findEventsByCityWithBoostPriority(city, now, endDate, pageable);
        return PageResponse.from(events, event -> enrichEventResponseWithBoostInfo(event));
    }

    public PageResponse<EventResponse> getEventsByCountry(String country, Pageable pageable) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime endDate = now.plusMonths(2);
        Page<Event> events = eventRepository.findUpcomingEventsByCountry(country, now, endDate, pageable);
        return PageResponse.from(events, event -> enrichEventResponseWithBoostInfo(event));
    }

    public PageResponse<EventResponse> getEventsByCategory(Long categoryId, Pageable pageable) {
        Category category = categoryService.getEntityById(categoryId);
        LocalDateTime now = LocalDateTime.now();
        Page<Event> events = eventRepository.findEventsByCategoryWithBoostPriority(category, now, pageable);
        return PageResponse.from(events, event -> enrichEventResponseWithBoostInfo(event));
    }

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

        return response;
    }

    public PageResponse<EventResponse> getEventsByOrganiser(User organiser, Pageable pageable) {
        Page<Event> events = eventRepository.findByOrganiser(organiser, pageable);
        return PageResponse.from(events, event -> enrichEventResponseWithBoostInfo(event));
    }

    public PageResponse<EventResponse> getEventsByOrganiserAndStatus(User organiser, EventStatus status, Pageable pageable) {
        Page<Event> events = eventRepository.findByOrganiserAndStatus(organiser, status, pageable);
        return PageResponse.from(events, event -> enrichEventResponseWithBoostInfo(event));
    }

    public PageResponse<EventResponse> getUpcomingEventsByOrganiserId(UUID organiserId, Pageable pageable) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime endDate = now.plusMonths(2);
        Page<Event> events = eventRepository.findUpcomingEventsByOrganiser(organiserId, now, endDate, pageable);
        return PageResponse.from(events, event -> enrichEventResponseWithBoostInfo(event));
    }

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

    @Transactional
    public EventResponse createEventForUser(User user, EventCreateRequest request) {
        LocalDateTime cutoffTime = LocalDateTime.now().minusMinutes(5);
        if (request.getStartTime().isBefore(cutoffTime)) {
            throw new BadRequestException("Start time must be in the future");
        }
        if (request.getEndTime().isBefore(request.getStartTime())) {
            throw new BadRequestException("End time must be after start time");
        }

        ensureOrganiserProfile(user);

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
                .organiser(user)
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

        if (request.getRecurrenceType() != null && request.getRecurrenceType() != RecurrenceType.NONE) {
            createRecurringEventInstances(savedEvent, request);
        }

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

        if (request.getTitle() != null) event.setTitle(request.getTitle());
        if (request.getDescription() != null) event.setDescription(request.getDescription());
        if (request.getImageUrl() != null) event.setImageUrl(request.getImageUrl());
        if (request.getStartTime() != null) event.setStartTime(request.getStartTime());
        if (request.getEndTime() != null) event.setEndTime(request.getEndTime());
        if (request.getRegistrationDeadline() != null) event.setRegistrationDeadline(request.getRegistrationDeadline());
        if (request.getVenue() != null) event.setVenue(request.getVenue());
        if (request.getAddress() != null) event.setAddress(request.getAddress());
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
    public void deleteEventByUser(UUID eventId, User user) {
        deleteEventByOrganiser(eventId, user);
    }

    @Transactional
    public EventResponse updateEventByUser(UUID eventId, User user, EventCreateRequest request) {
        Event event = getEntityById(eventId);

        if (!event.getOrganiser().getId().equals(user.getId())) {
            throw new BadRequestException("You do not have permission to update this event");
        }

        if (event.getStatus() == EventStatus.CANCELLED) {
            throw new BadRequestException("Cannot edit a cancelled event");
        }

        event.setTitle(request.getTitle());
        event.setDescription(request.getDescription());
        event.setImageUrl(request.getImageUrl());
        event.setStartTime(request.getStartTime());
        event.setEndTime(request.getEndTime());
        event.setRegistrationDeadline(request.getRegistrationDeadline());
        event.setVenue(request.getVenue());
        event.setAddress(request.getAddress());
        event.setLatitude(request.getLatitude());
        event.setLongitude(request.getLongitude());
        event.setTicketPrice(request.getTicketPrice() != null ? request.getTicketPrice() : BigDecimal.ZERO);
        event.setCapacity(request.getCapacity());
        event.setVisibility(request.getVisibility());
        event.setRequiresApproval(request.isRequiresApproval());

        if (request.getCategoryId() != null) {
            Category category = categoryService.getEntityById(request.getCategoryId());
            event.setCategory(category);
        }

        if (request.getCityId() != null) {
            City city = cityService.getEntityById(request.getCityId());
            event.setCity(city);
        }

        boolean wasRejected = event.getStatus() == EventStatus.REJECTED;
        if (wasRejected) {
            event.setStatus(EventStatus.DRAFT);
            event.setRejectionReason(null);
        }

        Event savedEvent = eventRepository.save(event);

        if (wasRejected) {
            try {
                notificationService.notifyAdminEventResubmitted(savedEvent);
            } catch (Exception e) {
                log.error("Failed to send resubmit notification: {}", e.getMessage(), e);
            }
        }

        return EventResponse.fromEntity(savedEvent);
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

    public long countByOrganiser(User organiser) {
        return eventRepository.countByOrganiser(organiser);
    }

    public long countByOrganiserAndStatus(User organiser, EventStatus status) {
        return eventRepository.countByOrganiserAndStatus(organiser, status);
    }

    public PageResponse<EventResponse> getEventsBySpeaker(String speakerName, Pageable pageable) {
        Page<Event> events = eventRepository.findEventsBySpeakerName(speakerName, pageable);
        return PageResponse.from(events, event -> enrichEventResponseWithBoostInfo(event));
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

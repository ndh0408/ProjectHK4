package com.luma.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.luma.dto.response.EventRecommendationResponse;
import com.luma.dto.response.EventResponse;
import com.luma.entity.Event;
import com.luma.entity.Registration;
import com.luma.entity.User;
import com.luma.entity.enums.EventStatus;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.repository.EventRepository;
import com.luma.repository.RegistrationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class EventRecommendationService {

    private final AIService aiService;
    private final EventRepository eventRepository;
    private final RegistrationRepository registrationRepository;
    private final ObjectMapper objectMapper;

    public EventRecommendationResponse getPersonalizedRecommendations(User user, int limit) {
        List<Registration> userRegistrations = registrationRepository.findByUserIdAndStatusIn(
                user.getId(),
                List.of(RegistrationStatus.APPROVED, RegistrationStatus.PENDING)
        );

        List<Event> userViewedEvents = userRegistrations.stream()
                .map(Registration::getEvent)
                .filter(Objects::nonNull)
                .limit(10)
                .collect(Collectors.toList());

        LocalDateTime now = LocalDateTime.now();
        LocalDateTime endDate = now.plusMonths(3);
        Page<Event> upcomingEvents = eventRepository.findUpcomingPublicEvents(now, endDate, PageRequest.of(0, 50));

        Set<UUID> registeredEventIds = userRegistrations.stream()
                .map(r -> r.getEvent().getId())
                .collect(Collectors.toSet());

        List<Event> candidateEvents = upcomingEvents.getContent().stream()
                .filter(e -> !registeredEventIds.contains(e.getId()))
                .collect(Collectors.toList());

        List<EventResponse> recommendedEvents;

        if (candidateEvents.isEmpty()) {
            recommendedEvents = new ArrayList<>();
        } else {
            try {
                String aiResponse = aiService.generateEventRecommendations(userViewedEvents, candidateEvents, limit);
                List<UUID> recommendedIds = parseEventIds(aiResponse);

                Map<UUID, Event> eventMap = candidateEvents.stream()
                        .collect(Collectors.toMap(Event::getId, e -> e));

                recommendedEvents = recommendedIds.stream()
                        .map(eventMap::get)
                        .filter(Objects::nonNull)
                        .map(this::toEventResponse)
                        .collect(Collectors.toList());
            } catch (Exception e) {
                log.error("AI recommendation failed, falling back to default", e);
                recommendedEvents = candidateEvents.stream()
                        .limit(limit)
                        .map(this::toEventResponse)
                        .collect(Collectors.toList());
            }
        }

        return EventRecommendationResponse.builder()
                .recommendedEvents(recommendedEvents)
                .recommendationType(userViewedEvents.isEmpty() ? "popular" : "personalized")
                .build();
    }

    public List<EventResponse> getSimilarEvents(UUID eventId, int limit) {
        Event sourceEvent = eventRepository.findById(eventId)
                .orElseThrow(() -> new RuntimeException("Event not found"));

        LocalDateTime now = LocalDateTime.now();
        LocalDateTime endDate = now.plusMonths(3);
        Page<Event> upcomingEvents = eventRepository.findUpcomingPublicEvents(now, endDate, PageRequest.of(0, 30));

        List<Event> candidateEvents = upcomingEvents.getContent().stream()
                .filter(e -> !e.getId().equals(eventId))
                .collect(Collectors.toList());

        if (candidateEvents.isEmpty()) {
            return new ArrayList<>();
        }

        try {
            String aiResponse = aiService.findSimilarEvents(sourceEvent, candidateEvents, limit);
            List<UUID> similarIds = parseEventIds(aiResponse);

            Map<UUID, Event> eventMap = candidateEvents.stream()
                    .collect(Collectors.toMap(Event::getId, e -> e));

            return similarIds.stream()
                    .map(eventMap::get)
                    .filter(Objects::nonNull)
                    .map(this::toEventResponse)
                    .collect(Collectors.toList());
        } catch (Exception e) {
            log.error("AI similar events failed, falling back to category match", e);
            return candidateEvents.stream()
                    .filter(event -> event.getCategory() != null &&
                            sourceEvent.getCategory() != null &&
                            event.getCategory().getId().equals(sourceEvent.getCategory().getId()))
                    .limit(limit)
                    .map(this::toEventResponse)
                    .collect(Collectors.toList());
        }
    }

    public List<EventResponse> getTrendingEvents(int limit) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime endDate = now.plusMonths(2);

        Page<Event> boostedEvents = eventRepository.findUpcomingEventsWithBoostPriority(
                now, endDate, PageRequest.of(0, limit * 2));

        List<Event> scoredEvents = boostedEvents.getContent().stream()
                .sorted((e1, e2) -> {
                    int score1 = calculateHotnessScore(e1);
                    int score2 = calculateHotnessScore(e2);
                    return Integer.compare(score2, score1);
                })
                .limit(limit)
                .collect(Collectors.toList());

        return scoredEvents.stream()
                .map(this::toEventResponse)
                .collect(Collectors.toList());
    }

    private int calculateHotnessScore(Event event) {
        int score = 0;

        long registrationCount = registrationRepository.countByEventAndStatus(event, RegistrationStatus.APPROVED);
        score += (int) (registrationCount * 10);

        if (event.getCapacity() != null && event.getCapacity() > 0) {
            double fillRate = (double) registrationCount / event.getCapacity();
            if (fillRate > 0.8) score += 50;
            else if (fillRate > 0.5) score += 30;
            else if (fillRate > 0.2) score += 10;
        }

        if (event.getStartTime() != null) {
            long daysUntilEvent = java.time.temporal.ChronoUnit.DAYS.between(LocalDateTime.now(), event.getStartTime());
            if (daysUntilEvent <= 7) score += 30;
            else if (daysUntilEvent <= 14) score += 20;
            else if (daysUntilEvent <= 30) score += 10;
        }

        if (event.getTicketPrice() == null || event.getTicketPrice().doubleValue() == 0) {
            score += 15;
        }

        return score;
    }

    private List<UUID> parseEventIds(String aiResponse) {
        try {
            String cleaned = aiResponse.trim();
            int start = cleaned.indexOf('[');
            int end = cleaned.lastIndexOf(']') + 1;
            if (start >= 0 && end > start) {
                cleaned = cleaned.substring(start, end);
            }

            List<String> ids = objectMapper.readValue(cleaned, new TypeReference<List<String>>() {});
            return ids.stream()
                    .map(UUID::fromString)
                    .collect(Collectors.toList());
        } catch (Exception e) {
            log.error("Failed to parse AI event IDs: {}", aiResponse, e);
            return new ArrayList<>();
        }
    }

    private EventResponse toEventResponse(Event event) {
        return EventResponse.builder()
                .id(event.getId())
                .title(event.getTitle())
                .description(event.getDescription())
                .imageUrl(event.getImageUrl())
                .startTime(event.getStartTime())
                .endTime(event.getEndTime())
                .venue(event.getVenue())
                .address(event.getAddress())
                .latitude(event.getLatitude())
                .longitude(event.getLongitude())
                .capacity(event.getCapacity())
                .ticketPrice(event.getTicketPrice())
                .status(event.getStatus())
                .visibility(event.getVisibility())
                .category(event.getCategory() != null ?
                        com.luma.dto.response.CategoryResponse.fromEntity(event.getCategory()) : null)
                .city(event.getCity() != null ?
                        com.luma.dto.response.CityResponse.fromEntity(event.getCity()) : null)
                .build();
    }
}

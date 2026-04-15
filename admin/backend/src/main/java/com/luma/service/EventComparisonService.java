package com.luma.service;

import com.luma.dto.response.EventComparisonResponse;
import com.luma.dto.response.EventComparisonResponse.ComparedEvent;
import com.luma.entity.Event;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.repository.EventRepository;
import com.luma.repository.RegistrationRepository;
import com.luma.repository.ReviewRepository;
import com.luma.exception.BadRequestException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class EventComparisonService {

    private final EventRepository eventRepository;
    private final RegistrationRepository registrationRepository;
    private final ReviewRepository reviewRepository;

    @Transactional(readOnly = true)
    public EventComparisonResponse compareEvents(List<UUID> eventIds) {
        if (eventIds == null || eventIds.size() < 2 || eventIds.size() > 4) {
            throw new BadRequestException("Please select 2 to 4 events to compare");
        }

        List<ComparedEvent> compared = new ArrayList<>();

        for (UUID eventId : eventIds) {
            Event event = eventRepository.findById(eventId)
                    .orElseThrow(() -> new BadRequestException("Event not found: " + eventId));

            long regCount = registrationRepository.countByEventAndStatusIn(
                    event, List.of(RegistrationStatus.APPROVED, RegistrationStatus.PENDING));
            Double avgRating = reviewRepository.getAverageRatingByEventId(eventId);
            long reviewCount = reviewRepository.countByEventId(eventId);
            double fillRate = event.getCapacity() > 0 ? (double) regCount / event.getCapacity() * 100 : 0;

            BigDecimal price = event.getTicketPrice() != null ? event.getTicketPrice() : BigDecimal.ZERO;

            compared.add(ComparedEvent.builder()
                    .id(event.getId())
                    .title(event.getTitle())
                    .imageUrl(event.getImageUrl())
                    .organiserName(event.getOrganiser().getFullName())
                    .startTime(event.getStartTime())
                    .endTime(event.getEndTime())
                    .venue(event.getVenue())
                    .address(event.getAddress())
                    .cityName(event.getCity() != null ? event.getCity().getName() : null)
                    .categoryName(event.getCategory() != null ? event.getCategory().getName() : null)
                    .ticketPrice(price)
                    .capacity(event.getCapacity())
                    .registrationCount((int) regCount)
                    .fillRate(fillRate)
                    .averageRating(avgRating)
                    .reviewCount(reviewCount)
                    .isFree(price.compareTo(BigDecimal.ZERO) == 0)
                    .status(event.getStatus().name())
                    .build());
        }

        return EventComparisonResponse.builder().events(compared).build();
    }
}

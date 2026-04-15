package com.luma.service;

import com.luma.dto.response.EventImageResponse;
import com.luma.entity.Event;
import com.luma.repository.EventRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class EventImageService {

    private final EventRepository eventRepository;

    public Page<EventImageResponse> getGalleryImages(Pageable pageable) {
        return eventRepository.findByImageUrlIsNotNull(pageable)
                .map(this::toEventImageResponse);
    }

    public Page<EventImageResponse> getGalleryImagesByCategory(Long categoryId, Pageable pageable) {
        return eventRepository.findByCategoryIdAndImageUrlIsNotNull(categoryId, pageable)
                .map(this::toEventImageResponse);
    }

    public EventImageResponse getEventImage(UUID eventId) {
        Event event = eventRepository.findById(eventId).orElse(null);
        if (event == null || event.getImageUrl() == null) {
            return null;
        }
        return toEventImageResponse(event);
    }

    private EventImageResponse toEventImageResponse(Event event) {
        return EventImageResponse.builder()
                .id(event.getId())
                .eventId(event.getId())
                .eventTitle(event.getTitle())
                .imageUrl(event.getImageUrl())
                .caption(event.getTitle())
                .displayOrder(0)
                .isCover(true)
                .uploadedByName(event.getOrganiser() != null ? event.getOrganiser().getFullName() : null)
                .createdAt(event.getCreatedAt())
                .build();
    }
}

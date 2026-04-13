package com.luma.service;

import com.luma.dto.request.TicketTypeRequest;
import com.luma.dto.response.TicketTypeResponse;
import com.luma.entity.Event;
import com.luma.entity.TicketType;
import com.luma.entity.User;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.EventRepository;
import com.luma.repository.TicketTypeRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class TicketTypeService {

    private final TicketTypeRepository ticketTypeRepository;
    private final EventRepository eventRepository;

    @Transactional(readOnly = true)
    public List<TicketTypeResponse> getTicketTypesByEventId(UUID eventId) {
        List<TicketType> ticketTypes = ticketTypeRepository.findByEventIdOrderByDisplayOrderAsc(eventId);
        return ticketTypes.stream()
                .map(TicketTypeResponse::fromEntity)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<TicketTypeResponse> getVisibleTicketTypesByEventId(UUID eventId) {
        List<TicketType> ticketTypes = ticketTypeRepository.findByEventIdAndIsVisibleTrueOrderByDisplayOrderAsc(eventId);
        return ticketTypes.stream()
                .map(TicketTypeResponse::fromEntity)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<TicketTypeResponse> getAvailableTicketTypesByEventId(UUID eventId) {
        List<TicketType> ticketTypes = ticketTypeRepository.findAvailableByEventId(eventId);
        return ticketTypes.stream()
                .map(TicketTypeResponse::fromEntity)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public TicketTypeResponse getTicketTypeById(UUID ticketTypeId) {
        TicketType ticketType = ticketTypeRepository.findById(ticketTypeId)
                .orElseThrow(() -> new ResourceNotFoundException("Ticket type not found"));
        return TicketTypeResponse.fromEntity(ticketType);
    }

    @Transactional(readOnly = true)
    public TicketType getEntityById(UUID ticketTypeId) {
        return ticketTypeRepository.findById(ticketTypeId)
                .orElseThrow(() -> new ResourceNotFoundException("Ticket type not found"));
    }

    @Transactional
    public TicketTypeResponse createTicketType(UUID eventId, TicketTypeRequest request, User organiser) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        validateOrganiserAccess(event, organiser);
        validateTicketTypeRequest(request, event);

        int displayOrder = request.getDisplayOrder() != null
                ? request.getDisplayOrder()
                : ticketTypeRepository.getMaxDisplayOrderByEventId(eventId) + 1;

        TicketType ticketType = TicketType.builder()
                .event(event)
                .name(request.getName())
                .description(request.getDescription())
                .price(request.getPrice())
                .quantity(request.getQuantity())
                .soldCount(0)
                .maxPerOrder(request.getMaxPerOrder() != null ? request.getMaxPerOrder() : 10)
                .saleStartDate(request.getSaleStartDate())
                .saleEndDate(request.getSaleEndDate())
                .isVisible(request.getIsVisible() != null ? request.getIsVisible() : true)
                .displayOrder(displayOrder)
                .build();

        ticketType = ticketTypeRepository.save(ticketType);
        log.info("Created ticket type {} for event {}", ticketType.getId(), eventId);

        updateEventFreeStatus(event);

        return TicketTypeResponse.fromEntity(ticketType);
    }

    @Transactional
    public TicketTypeResponse updateTicketType(UUID ticketTypeId, TicketTypeRequest request, User organiser) {
        TicketType ticketType = ticketTypeRepository.findById(ticketTypeId)
                .orElseThrow(() -> new ResourceNotFoundException("Ticket type not found"));

        validateOrganiserAccess(ticketType.getEvent(), organiser);

        if (request.getQuantity() < ticketType.getSoldCount()) {
            throw new BadRequestException("Cannot reduce quantity below sold count (" + ticketType.getSoldCount() + ")");
        }

        ticketType.setName(request.getName());
        ticketType.setDescription(request.getDescription());
        ticketType.setPrice(request.getPrice());
        ticketType.setQuantity(request.getQuantity());
        ticketType.setMaxPerOrder(request.getMaxPerOrder() != null ? request.getMaxPerOrder() : ticketType.getMaxPerOrder());
        ticketType.setSaleStartDate(request.getSaleStartDate());
        ticketType.setSaleEndDate(request.getSaleEndDate());

        if (request.getIsVisible() != null) {
            ticketType.setIsVisible(request.getIsVisible());
        }
        if (request.getDisplayOrder() != null) {
            ticketType.setDisplayOrder(request.getDisplayOrder());
        }

        ticketType = ticketTypeRepository.save(ticketType);
        log.info("Updated ticket type {}", ticketTypeId);

        updateEventFreeStatus(ticketType.getEvent());

        return TicketTypeResponse.fromEntity(ticketType);
    }

    @Transactional
    public void deleteTicketType(UUID ticketTypeId, User organiser) {
        TicketType ticketType = ticketTypeRepository.findById(ticketTypeId)
                .orElseThrow(() -> new ResourceNotFoundException("Ticket type not found"));

        validateOrganiserAccess(ticketType.getEvent(), organiser);

        if (ticketType.getSoldCount() > 0) {
            throw new BadRequestException("Cannot delete ticket type with sold tickets. Consider hiding it instead.");
        }

        Event event = ticketType.getEvent();
        ticketTypeRepository.delete(ticketType);
        log.info("Deleted ticket type {}", ticketTypeId);

        updateEventFreeStatus(event);
    }

    @Transactional
    public List<TicketTypeResponse> reorderTicketTypes(UUID eventId, List<UUID> ticketTypeIds, User organiser) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        validateOrganiserAccess(event, organiser);

        for (int i = 0; i < ticketTypeIds.size(); i++) {
            UUID ticketTypeId = ticketTypeIds.get(i);
            TicketType ticketType = ticketTypeRepository.findByIdAndEventId(ticketTypeId, eventId)
                    .orElseThrow(() -> new ResourceNotFoundException("Ticket type not found: " + ticketTypeId));
            ticketType.setDisplayOrder(i);
            ticketTypeRepository.save(ticketType);
        }

        return getTicketTypesByEventId(eventId);
    }

    @Transactional
    public TicketTypeResponse toggleVisibility(UUID ticketTypeId, User organiser) {
        TicketType ticketType = ticketTypeRepository.findById(ticketTypeId)
                .orElseThrow(() -> new ResourceNotFoundException("Ticket type not found"));

        validateOrganiserAccess(ticketType.getEvent(), organiser);

        ticketType.setIsVisible(!ticketType.getIsVisible());
        ticketType = ticketTypeRepository.save(ticketType);
        log.info("Toggled visibility for ticket type {} to {}", ticketTypeId, ticketType.getIsVisible());

        return TicketTypeResponse.fromEntity(ticketType);
    }

    @Transactional
    public boolean incrementSoldCount(UUID ticketTypeId, int quantity) {
        int updated = ticketTypeRepository.incrementSoldCount(ticketTypeId, quantity);
        if (updated == 0) {
            log.warn("Failed to increment sold count for ticket type {}. Not enough stock.", ticketTypeId);
            return false;
        }
        log.info("Incremented sold count for ticket type {} by {}", ticketTypeId, quantity);
        return true;
    }

    @Transactional
    public boolean decrementSoldCount(UUID ticketTypeId, int quantity) {
        int updated = ticketTypeRepository.decrementSoldCount(ticketTypeId, quantity);
        if (updated == 0) {
            log.warn("Failed to decrement sold count for ticket type {}", ticketTypeId);
            return false;
        }
        log.info("Decremented sold count for ticket type {} by {}", ticketTypeId, quantity);
        return true;
    }

    @Transactional(readOnly = true)
    public boolean canPurchase(UUID ticketTypeId, int quantity) {
        TicketType ticketType = ticketTypeRepository.findById(ticketTypeId)
                .orElseThrow(() -> new ResourceNotFoundException("Ticket type not found"));
        return ticketType.canPurchase(quantity);
    }

    private void validateOrganiserAccess(Event event, User organiser) {
        if (!event.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You are not the organiser of this event");
        }
    }

    private void validateTicketTypeRequest(TicketTypeRequest request, Event event) {
        if (request.getSaleStartDate() != null && request.getSaleEndDate() != null) {
            if (request.getSaleStartDate().isAfter(request.getSaleEndDate())) {
                throw new BadRequestException("Sale start date must be before sale end date");
            }
        }

        if (request.getSaleEndDate() != null && request.getSaleEndDate().isAfter(event.getEndTime())) {
            throw new BadRequestException("Sale end date cannot be after event end time");
        }
    }

    private void updateEventFreeStatus(Event event) {
        List<TicketType> ticketTypes = ticketTypeRepository.findByEventIdOrderByDisplayOrderAsc(event.getId());

        if (ticketTypes.isEmpty()) {
            return;
        }

        boolean allFree = ticketTypes.stream()
                .filter(TicketType::getIsVisible)
                .allMatch(tt -> tt.getPrice().compareTo(BigDecimal.ZERO) == 0);

        event.setFree(allFree);
        eventRepository.save(event);
    }

    @Transactional(readOnly = true)
    public TicketTypeStats getTicketTypeStats(UUID eventId) {
        int totalAvailable = ticketTypeRepository.getTotalAvailableByEventId(eventId);
        int totalSold = ticketTypeRepository.getTotalSoldByEventId(eventId);
        int ticketTypeCount = ticketTypeRepository.countByEventId(eventId);

        return new TicketTypeStats(totalAvailable, totalSold, ticketTypeCount);
    }

    public record TicketTypeStats(int totalAvailable, int totalSold, int ticketTypeCount) {}
}

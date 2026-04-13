package com.luma.service;

import com.luma.entity.*;
import com.luma.entity.enums.SeatStatus;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.RegistrationRepository;
import com.luma.repository.SeatRepository;
import com.luma.repository.SeatZoneRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
public class SeatMapService {

    private static final int LOCK_MINUTES = 5;

    private final SeatZoneRepository zoneRepository;
    private final SeatRepository seatRepository;
    private final RegistrationRepository registrationRepository;
    private final EventService eventService;

    @Transactional
    public Map<String, Object> createSeatMap(UUID eventId, List<Map<String, Object>> zones, User organiser) {
        Event event = eventService.getEntityById(eventId);
        if (!event.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("Only the event organiser can manage seat maps");
        }
        if (!zoneRepository.findByEventOrderByDisplayOrderAsc(event).isEmpty()) {
            throw new BadRequestException("Seat map already exists for this event. Delete existing one first.");
        }

        List<SeatZone> createdZones = new ArrayList<>();
        int totalSeats = 0;

        for (int i = 0; i < zones.size(); i++) {
            Map<String, Object> zoneData = zones.get(i);
            String name = (String) zoneData.get("name");
            String color = (String) zoneData.get("color");
            Number price = (Number) zoneData.get("price");
            int rows = ((Number) zoneData.getOrDefault("rows", 5)).intValue();
            int seatsPerRow = ((Number) zoneData.getOrDefault("seatsPerRow", 10)).intValue();

            SeatZone zone = SeatZone.builder()
                    .event(event)
                    .name(name)
                    .color(color)
                    .price(price != null ? new java.math.BigDecimal(price.toString()) : null)
                    .totalSeats(rows * seatsPerRow)
                    .availableSeats(rows * seatsPerRow)
                    .displayOrder(i)
                    .build();

            zone = zoneRepository.save(zone);

            for (int r = 0; r < rows; r++) {
                String rowLabel = String.valueOf((char) ('A' + r));
                for (int s = 1; s <= seatsPerRow; s++) {
                    Seat seat = Seat.builder()
                            .zone(zone)
                            .row(rowLabel)
                            .number(s)
                            .build();
                    seatRepository.save(seat);
                }
            }

            totalSeats += rows * seatsPerRow;
            createdZones.add(zone);
        }

        return Map.of("zones", createdZones.size(), "totalSeats", totalSeats);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getSeatMap(UUID eventId) {
        Event event = eventService.getEntityById(eventId);
        List<SeatZone> zones = zoneRepository.findByEventOrderByDisplayOrderAsc(event);

        List<Map<String, Object>> zoneData = new ArrayList<>();
        for (SeatZone zone : zones) {
            List<Seat> seats = seatRepository.findByZoneOrderByRowAscNumberAsc(zone);
            List<Map<String, Object>> seatData = seats.stream().map(s -> {
                Map<String, Object> map = new HashMap<>();
                map.put("id", s.getId());
                map.put("row", s.getRow());
                map.put("number", s.getNumber());
                map.put("label", s.getLabel());
                map.put("status", s.isAvailable() ? "AVAILABLE" : s.getStatus().name());
                return map;
            }).toList();

            Map<String, Object> z = new HashMap<>();
            z.put("id", zone.getId());
            z.put("name", zone.getName());
            z.put("color", zone.getColor());
            z.put("price", zone.getPrice());
            z.put("totalSeats", zone.getTotalSeats());
            z.put("availableSeats", seatData.stream().filter(s -> "AVAILABLE".equals(s.get("status"))).count());
            z.put("seats", seatData);
            zoneData.add(z);
        }

        return Map.of("eventId", eventId, "zones", zoneData);
    }

    @Transactional
    public Map<String, Object> lockSeats(List<UUID> seatIds, User user) {
        List<Seat> lockedSeats = new ArrayList<>();
        LocalDateTime lockUntil = LocalDateTime.now().plusMinutes(LOCK_MINUTES);

        for (UUID seatId : seatIds) {
            Seat seat = seatRepository.findByIdWithLock(seatId)
                    .orElseThrow(() -> new ResourceNotFoundException("Seat not found"));

            if (!seat.isAvailable()) {
                throw new BadRequestException("Seat " + seat.getLabel() + " is not available");
            }

            seat.setStatus(SeatStatus.LOCKED);
            seat.setReservedBy(user);
            seat.setLockedUntil(lockUntil);
            seatRepository.save(seat);
            lockedSeats.add(seat);
        }

        return Map.of(
                "lockedSeats", lockedSeats.size(),
                "expiresAt", lockUntil,
                "lockMinutes", LOCK_MINUTES
        );
    }

    @Transactional
    public void confirmSeats(List<UUID> seatIds, Registration registration) {
        for (UUID seatId : seatIds) {
            Seat seat = seatRepository.findByIdWithLock(seatId)
                    .orElseThrow(() -> new ResourceNotFoundException("Seat not found"));
            seat.setStatus(SeatStatus.SOLD);
            seat.setRegistration(registration);
            seat.setLockedUntil(null);
            seatRepository.save(seat);
        }
    }

    @Transactional(readOnly = true)
    public Registration getRegistrationForConfirm(UUID registrationId, User user) {
        Registration registration = registrationRepository.findById(registrationId)
                .orElseThrow(() -> new ResourceNotFoundException("Registration not found"));
        if (!registration.getUser().getId().equals(user.getId())) {
            throw new BadRequestException("You can only confirm seats for your own registration");
        }
        return registration;
    }

    public void releaseExpiredLocks() {
        int released = seatRepository.releaseExpiredLocks(LocalDateTime.now());
        if (released > 0) {
            log.info("Released {} expired seat locks", released);
        }
    }
}

package com.luma.service;

import com.luma.entity.*;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.EventSessionRepository;
import com.luma.repository.SessionRegistrationRepository;
import com.luma.repository.SpeakerRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
public class ScheduleBuilderService {

    private final EventSessionRepository sessionRepository;
    private final SessionRegistrationRepository sessionRegRepository;
    private final SpeakerRepository speakerRepository;
    private final EventService eventService;

    @Transactional
    public Map<String, Object> createSession(UUID eventId, Map<String, Object> data, User organiser) {
        Event event = eventService.getEntityById(eventId);
        if (!event.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("Only the organiser can manage sessions");
        }

        EventSession session = EventSession.builder()
                .event(event)
                .title((String) data.get("title"))
                .description((String) data.get("description"))
                .startTime(parseDateTime(data.get("startTime")))
                .endTime(parseDateTime(data.get("endTime")))
                .room((String) data.get("room"))
                .track((String) data.get("track"))
                .capacity(data.get("capacity") != null ? ((Number) data.get("capacity")).intValue() : 0)
                .displayOrder(data.get("displayOrder") != null ? ((Number) data.get("displayOrder")).intValue() : 0)
                .build();

        if (data.get("speakerId") != null) {
            Long speakerId = Long.valueOf(data.get("speakerId").toString());
            Speaker speaker = speakerRepository.findById(speakerId)
                    .orElseThrow(() -> new ResourceNotFoundException("Speaker not found"));
            session.setSpeaker(speaker);

            List<EventSession> conflicts = sessionRepository.findConflictingSpeakerSessions(
                    event, speaker.getId(), session.getStartTime(), session.getEndTime());
            if (!conflicts.isEmpty()) {
                throw new BadRequestException("Speaker has a conflicting session at this time");
            }
        }

        if (session.getRoom() != null) {
            UUID excludeId = session.getId() != null ? session.getId() : UUID.randomUUID();
            List<EventSession> roomConflicts = sessionRepository.findConflictingRoomSessions(
                    event, session.getRoom(), session.getStartTime(), session.getEndTime(), excludeId);
            if (!roomConflicts.isEmpty()) {
                throw new BadRequestException("Room '" + session.getRoom() + "' is already booked at this time");
            }
        }

        session = sessionRepository.save(session);
        return sessionToMap(session);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getSchedule(UUID eventId) {
        Event event = eventService.getEntityById(eventId);
        List<EventSession> sessions = sessionRepository.findByEventOrderByStartTimeAscDisplayOrderAsc(event);
        List<String> tracks = sessionRepository.findDistinctTracksByEvent(event);
        List<String> rooms = sessionRepository.findDistinctRoomsByEvent(event);

        List<Map<String, Object>> sessionList = sessions.stream().map(this::sessionToMap).toList();

        return Map.of(
                "eventId", eventId,
                "eventTitle", event.getTitle(),
                "sessions", sessionList,
                "tracks", tracks,
                "rooms", rooms
        );
    }

    @Transactional
    public void deleteSession(UUID sessionId, User organiser) {
        EventSession session = sessionRepository.findById(sessionId)
                .orElseThrow(() -> new ResourceNotFoundException("Session not found"));
        if (!session.getEvent().getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("Only the organiser can delete sessions");
        }
        sessionRepository.delete(session);
    }

    @Transactional
    public Map<String, Object> registerForSession(UUID sessionId, User user) {
        EventSession session = sessionRepository.findById(sessionId)
                .orElseThrow(() -> new ResourceNotFoundException("Session not found"));

        if (sessionRegRepository.existsBySessionAndUser(session, user)) {
            throw new BadRequestException("Already registered for this session");
        }

        if (session.getCapacity() > 0 && session.getRegisteredCount() >= session.getCapacity()) {
            throw new BadRequestException("Session is full");
        }

        SessionRegistration reg = SessionRegistration.builder()
                .session(session)
                .user(user)
                .build();
        sessionRegRepository.save(reg);

        session.setRegisteredCount(session.getRegisteredCount() + 1);
        sessionRepository.save(session);

        return Map.of("sessionId", sessionId, "registered", true);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> getMySchedule(UUID eventId, User user) {
        List<SessionRegistration> regs = sessionRegRepository.findByUserAndEventId(user, eventId);
        return regs.stream().map(r -> sessionToMap(r.getSession())).toList();
    }

    private LocalDateTime parseDateTime(Object value) {
        if (value == null) throw new BadRequestException("Date/time is required");
        if (value instanceof LocalDateTime ldt) return ldt;
        return LocalDateTime.parse(value.toString());
    }

    private Map<String, Object> sessionToMap(EventSession s) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", s.getId());
        map.put("title", s.getTitle());
        map.put("description", s.getDescription());
        map.put("startTime", s.getStartTime());
        map.put("endTime", s.getEndTime());
        map.put("room", s.getRoom());
        map.put("track", s.getTrack());
        map.put("speakerName", s.getSpeaker() != null ? s.getSpeaker().getName() : null);
        map.put("capacity", s.getCapacity());
        map.put("registeredCount", s.getRegisteredCount());
        map.put("displayOrder", s.getDisplayOrder());
        return map;
    }
}

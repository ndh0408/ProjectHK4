package com.luma.service;

import com.luma.dto.response.analytics.FunnelAnalyticsResponse;
import com.luma.dto.response.analytics.FunnelAnalyticsResponse.EventFunnel;
import com.luma.dto.response.analytics.FunnelAnalyticsResponse.FunnelStep;
import com.luma.entity.Event;
import com.luma.entity.User;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class FunnelAnalyticsService {

    private final EventViewRepository eventViewRepository;
    private final RegistrationRepository registrationRepository;
    private final ReviewRepository reviewRepository;
    private final EventRepository eventRepository;

    @Transactional
    public void trackEventView(Event event, User user, String sessionId) {
        com.luma.entity.EventView view = com.luma.entity.EventView.builder()
                .event(event)
                .user(user)
                .sessionId(sessionId)
                .build();
        eventViewRepository.save(view);
    }

    @Transactional(readOnly = true)
    public FunnelAnalyticsResponse getPlatformFunnel() {
        long totalViews = eventViewRepository.count();
        long totalRegistrations = registrationRepository.countAll();
        long totalApproved = registrationRepository.countByStatusGlobal(RegistrationStatus.APPROVED);
        long totalAttended = registrationRepository.countCheckedInGlobal();
        long totalReviewed = reviewRepository.count();

        return buildFunnelResponse(totalViews, totalRegistrations, totalApproved, totalAttended, totalReviewed, null);
    }

    @Transactional(readOnly = true)
    public FunnelAnalyticsResponse getOrganiserFunnel(UUID organiserId) {
        long totalViews = eventViewRepository.countByOrganiser(organiserId);
        long totalRegistrations = registrationRepository.countByEventOrganiserId(organiserId);
        long totalApproved = registrationRepository.countApprovedByOrganiserId(organiserId);
        long totalAttended = registrationRepository.countCheckedInByOrganiserId(organiserId);
        long totalReviewed = reviewRepository.countByOrganiserId(organiserId);

        List<Event> events = eventRepository.findByOrganiserIdOrderByStartTimeDesc(organiserId);
        List<EventFunnel> eventFunnels = new ArrayList<>();

        for (Event event : events) {
            long views = eventViewRepository.countByEvent(event);
            long regs = registrationRepository.countByEventAndStatusIn(
                    event, List.of(RegistrationStatus.PENDING, RegistrationStatus.APPROVED, RegistrationStatus.WAITING_LIST));
            long approved = registrationRepository.countByEventAndStatus(event, RegistrationStatus.APPROVED);
            long attended = registrationRepository.countCheckedInByEvent(event);
            long reviewed = reviewRepository.countByEventId(event.getId());

            if (views > 0 || regs > 0) {
                eventFunnels.add(EventFunnel.builder()
                        .eventId(event.getId())
                        .eventTitle(event.getTitle())
                        .views(views)
                        .registrations(regs)
                        .approved(approved)
                        .attended(attended)
                        .reviewed(reviewed)
                        .conversionRate(views > 0 ? (double) attended / views * 100 : 0)
                        .build());
            }
        }

        return buildFunnelResponse(totalViews, totalRegistrations, totalApproved, totalAttended, totalReviewed, eventFunnels);
    }

    @Transactional(readOnly = true)
    public FunnelAnalyticsResponse getEventFunnel(UUID eventId) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new com.luma.exception.ResourceNotFoundException("Event not found"));

        long views = eventViewRepository.countByEvent(event);
        long regs = registrationRepository.countByEventAndStatusIn(
                event, List.of(RegistrationStatus.PENDING, RegistrationStatus.APPROVED, RegistrationStatus.WAITING_LIST));
        long approved = registrationRepository.countByEventAndStatus(event, RegistrationStatus.APPROVED);
        long attended = registrationRepository.countCheckedInByEvent(event);
        long reviewed = reviewRepository.countByEventId(event.getId());

        EventFunnel eventFunnel = EventFunnel.builder()
                .eventId(event.getId())
                .eventTitle(event.getTitle())
                .views(views)
                .registrations(regs)
                .approved(approved)
                .attended(attended)
                .reviewed(reviewed)
                .conversionRate(views > 0 ? (double) attended / views * 100 : 0)
                .build();

        return buildFunnelResponse(views, regs, approved, attended, reviewed, List.of(eventFunnel));
    }

    private FunnelAnalyticsResponse buildFunnelResponse(long views, long registrations, long approved, long attended, long reviewed, List<EventFunnel> eventFunnels) {
        double viewToReg = views > 0 ? (double) registrations / views * 100 : 0;
        double regToApproved = registrations > 0 ? (double) approved / registrations * 100 : 0;
        double approvedToAttended = approved > 0 ? (double) attended / approved * 100 : 0;
        double attendedToReviewed = attended > 0 ? (double) reviewed / attended * 100 : 0;
        double overallConversion = views > 0 ? (double) attended / views * 100 : 0;

        List<FunnelStep> steps = List.of(
                FunnelStep.builder().name("Views").count(views).percentage(100).dropOffRate(0).build(),
                FunnelStep.builder().name("Registrations").count(registrations).percentage(viewToReg).dropOffRate(100 - viewToReg).build(),
                FunnelStep.builder().name("Approved").count(approved).percentage(regToApproved).dropOffRate(100 - regToApproved).build(),
                FunnelStep.builder().name("Attended").count(attended).percentage(approvedToAttended).dropOffRate(100 - approvedToAttended).build(),
                FunnelStep.builder().name("Reviewed").count(reviewed).percentage(attendedToReviewed).dropOffRate(100 - attendedToReviewed).build()
        );

        return FunnelAnalyticsResponse.builder()
                .totalViews(views)
                .totalRegistrations(registrations)
                .totalApproved(approved)
                .totalAttended(attended)
                .totalReviewed(reviewed)
                .viewToRegistrationRate(viewToReg)
                .registrationToApprovedRate(regToApproved)
                .approvedToAttendedRate(approvedToAttended)
                .attendedToReviewedRate(attendedToReviewed)
                .overallConversionRate(overallConversion)
                .steps(steps)
                .eventFunnels(eventFunnels)
                .build();
    }
}

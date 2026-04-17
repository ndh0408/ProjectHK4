package com.luma.dto.response;

import com.luma.entity.Event;
import com.luma.entity.enums.EventStatus;
import com.luma.entity.enums.EventVisibility;
import com.luma.entity.enums.RecurrenceType;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EventResponse {

    private UUID id;
    private String title;
    private String description;
    private String imageUrl;
    private LocalDateTime startTime;
    private LocalDateTime endTime;
    private LocalDateTime registrationDeadline;
    private String venue;
    private String address;
    private Double latitude;
    private Double longitude;
    private boolean isFree;
    private BigDecimal ticketPrice;
    private Integer capacity;
    private int approvedCount;
    private int currentRegistrations;
    private EventStatus status;
    private EventVisibility visibility;
    private boolean requiresApproval;
    private String rejectionReason;
    private LocalDateTime createdAt;

    private OrganiserResponse organiser;
    private CategoryResponse category;
    private CityResponse city;
    private List<SpeakerResponse> speakers;

    private boolean isFull;
    private boolean isAlmostFull;
    private int remainingSpots;
    private String availabilityStatus;
    private boolean hasRegistrationQuestions;
    private int registrationQuestionsCount;

    private Double averageRating;
    private int reviewCount;

    private RecurrenceType recurrenceType;
    private Integer recurrenceInterval;
    private List<String> recurrenceDaysOfWeek;
    private LocalDateTime recurrenceEndDate;
    private Integer recurrenceCount;
    private UUID parentEventId;
    private Integer occurrenceIndex;
    private int totalOccurrences;
    @JsonProperty("isRecurring")
    private boolean isRecurring;

    @JsonProperty("isBoosted")
    private Boolean isBoosted;
    private String boostPackage;
    private String boostBadge;

    private boolean hasSeatMap;
    private boolean hasSchedule;

    private List<TicketTypeResponse> ticketTypes;
    private boolean hasTicketTypes;

    public static EventResponse fromEntity(Event event) {
        EventResponse response = EventResponse.builder()
                .id(event.getId())
                .title(event.getTitle())
                .description(event.getDescription())
                .imageUrl(event.getImageUrl())
                .startTime(event.getStartTime())
                .endTime(event.getEndTime())
                .registrationDeadline(event.getRegistrationDeadline())
                .venue(event.getVenue())
                .address(event.getAddress())
                .latitude(event.getLatitude())
                .longitude(event.getLongitude())
                .isFree(event.isFree())
                .ticketPrice(event.getTicketPrice())
                .capacity(event.getCapacity())
                .approvedCount(event.getApprovedCount())
                .currentRegistrations(event.getApprovedCount())
                .status(event.getStatus())
                .visibility(event.getVisibility())
                .requiresApproval(event.isRequiresApproval())
                .rejectionReason(event.getRejectionReason())
                .createdAt(event.getCreatedAt())
                .isFull(event.isFull())
                .isAlmostFull(event.isAlmostFull())
                .remainingSpots(event.getRemainingSpots())
                .build();

        if (event.isFull()) {
            response.setAvailabilityStatus("WAITING_LIST");
        } else if (event.isAlmostFull()) {
            response.setAvailabilityStatus("ALMOST_FULL");
        } else {
            response.setAvailabilityStatus("AVAILABLE");
        }

        if (event.getOrganiser() != null) {
            response.setOrganiser(OrganiserResponse.builder()
                    .id(event.getOrganiser().getId())
                    .fullName(event.getOrganiser().getFullName())
                    .avatarUrl(event.getOrganiser().getAvatarUrl())
                    .build());
        }

        if (event.getCategory() != null) {
            response.setCategory(CategoryResponse.fromEntity(event.getCategory()));
        }

        if (event.getCity() != null) {
            response.setCity(CityResponse.fromEntity(event.getCity()));
        }

        try {
            if (event.getSpeakers() != null && !event.getSpeakers().isEmpty()) {
                response.setSpeakers(event.getSpeakers().stream()
                        .map(SpeakerResponse::fromEntity)
                        .toList());
            } else {
                response.setSpeakers(new ArrayList<>());
            }
        } catch (Exception e) {
            response.setSpeakers(new ArrayList<>());
        }

        try {
            if (event.getRegistrationQuestions() != null) {
                int questionsCount = event.getRegistrationQuestions().size();
                response.setHasRegistrationQuestions(questionsCount > 0);
                response.setRegistrationQuestionsCount(questionsCount);
            } else {
                response.setHasRegistrationQuestions(false);
                response.setRegistrationQuestionsCount(0);
            }
        } catch (Exception e) {
            response.setHasRegistrationQuestions(false);
            response.setRegistrationQuestionsCount(0);
        }

        response.setRecurrenceType(event.getRecurrenceType());
        response.setRecurrenceInterval(event.getRecurrenceInterval());
        if (event.getRecurrenceDaysOfWeek() != null && !event.getRecurrenceDaysOfWeek().isEmpty()) {
            response.setRecurrenceDaysOfWeek(List.of(event.getRecurrenceDaysOfWeek().split(",")));
        }
        response.setRecurrenceEndDate(event.getRecurrenceEndDate());
        response.setRecurrenceCount(event.getRecurrenceCount());
        response.setOccurrenceIndex(event.getOccurrenceIndex());
        response.setRecurring(event.getRecurrenceType() != null && event.getRecurrenceType() != RecurrenceType.NONE);

        if (event.getParentEvent() != null) {
            response.setParentEventId(event.getParentEvent().getId());
        }

        try {
            if (event.getChildEvents() != null) {
                response.setTotalOccurrences(event.getChildEvents().size() + 1);
            } else {
                response.setTotalOccurrences(1);
            }
        } catch (Exception e) {
            response.setTotalOccurrences(1);
        }

        try {
            if (event.getTicketTypes() != null && !event.getTicketTypes().isEmpty()) {
                response.setTicketTypes(event.getTicketTypes().stream()
                        .map(TicketTypeResponse::fromEntity)
                        .toList());
                response.setHasTicketTypes(true);
            } else {
                response.setTicketTypes(new ArrayList<>());
                response.setHasTicketTypes(false);
            }
        } catch (Exception e) {
            response.setTicketTypes(new ArrayList<>());
            response.setHasTicketTypes(false);
        }

        return response;
    }
}

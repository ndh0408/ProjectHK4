package com.luma.dto.request;

import com.luma.entity.enums.EventVisibility;
import com.luma.entity.enums.RecurrenceType;
import com.luma.validation.ValidEventTime;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Data
@ValidEventTime
public class EventCreateRequest {

    @NotBlank(message = "Event title is required")
    private String title;

    private String description;

    private String imageUrl;

    @NotNull(message = "Start time is required")
    private LocalDateTime startTime;

    @NotNull(message = "End time is required")
    private LocalDateTime endTime;

    private LocalDateTime registrationDeadline;

    private String venue;

    private String address;

    private Double latitude;

    private Double longitude;

    private Long cityId;

    private Long categoryId;

    private boolean isFree = true;

    private BigDecimal ticketPrice;

    private Integer capacity;

    private EventVisibility visibility = EventVisibility.PUBLIC;

    private boolean requiresApproval = false;

    @Valid
    private List<SpeakerRequest> speakers = new ArrayList<>();

    private RecurrenceType recurrenceType = RecurrenceType.NONE;

    @Min(value = 1, message = "Recurrence interval must be at least 1")
    private Integer recurrenceInterval = 1;

    private List<String> recurrenceDaysOfWeek;

    private LocalDateTime recurrenceEndDate;

    @Min(value = 1, message = "Recurrence count must be at least 1")
    @Max(value = 52, message = "Recurrence count cannot exceed 52")
    private Integer recurrenceCount;
}

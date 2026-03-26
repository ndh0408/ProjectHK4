package com.luma.dto.request;

import com.luma.entity.enums.EventStatus;
import com.luma.entity.enums.EventVisibility;
import com.luma.entity.enums.RecurrenceType;
import com.luma.validation.ValidEventTime;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Data
@ValidEventTime
public class EventUpdateRequest {
    
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
    
    private Long cityId;
    
    private Long categoryId;
    
    private Boolean isFree;
    
    private BigDecimal ticketPrice;
    
    private Integer capacity;
    
    private EventVisibility visibility;
    
    private EventStatus status;
    
    private Boolean requiresApproval;

    @Valid
    private List<SpeakerRequest> speakers;

    // Recurring event fields
    private RecurrenceType recurrenceType;

    @Min(value = 1, message = "Recurrence interval must be at least 1")
    private Integer recurrenceInterval;

    private List<String> recurrenceDaysOfWeek;

    private LocalDateTime recurrenceEndDate;

    @Min(value = 1, message = "Recurrence count must be at least 1")
    @Max(value = 52, message = "Recurrence count cannot exceed 52")
    private Integer recurrenceCount;

    // Cập nhật toàn bộ series hay chỉ event này
    private Boolean updateSeries = false;
}

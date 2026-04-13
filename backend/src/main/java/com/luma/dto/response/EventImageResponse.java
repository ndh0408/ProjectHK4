package com.luma.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EventImageResponse {

    private UUID id;
    private UUID eventId;
    private String eventTitle;
    private String imageUrl;
    private String caption;
    private int displayOrder;
    private boolean isCover;
    private String uploadedByName;
    private LocalDateTime createdAt;
}
